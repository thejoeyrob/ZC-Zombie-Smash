/* Guest leaderboard client. No sign-in and no privileged key in the app. */
(() => {
  'use strict';
  const endpoint = 'https://xdsrnnkuxfaycnlngjbq.supabase.co/rest/v1/rpc/';
  const key = 'sb_publishable_AicVoQAwV-KnlOs1Fc2RuQ_T81In0MC';
  const read = (k, f) => {
      try {
        return JSON.parse(localStorage.getItem(k)) ?? f;
      } catch {
        return f;
      }
    },
    write = (k, v) => {
      try {
        localStorage.setItem(k, JSON.stringify(v));
      } catch {}
    };
  // Leaderboard names are public, so block clearly offensive ones before they are ever sent.
  const STRONG_WORDS = ['fuck', 'shit', 'bitch', 'whore', 'nigg', 'fagg', 'nazi', 'hitler'];
  const WHOLE_WORDS = [
    'dick',
    'cock',
    'pussy',
    'ass',
    'tits',
    'porn',
    'sex',
    'cum',
    'cunt',
    'rape',
    'rapist',
    'slut',
  ];
  const LEET = { 0: 'o', 1: 'i', 3: 'e', 4: 'a', 5: 's', 7: 't', 8: 'b', '@': 'a', $: 's' };
  const squash = (word) =>
    word
      .toLowerCase()
      .replace(/[013457 8@$]/g, (c) => LEET[c] ?? '')
      .replace(/[^a-z]/g, '')
      .replace(/(.)\1+/g, '$1');
  const isObjectionable = (name) => {
    const words = name
      .split(/[ _.-]+/)
      .filter(Boolean)
      .map(squash);
    const joined = squash(name);
    return (
      STRONG_WORDS.some((bad) => joined.includes(squash(bad))) ||
      words.some((word) => WHOLE_WORDS.includes(word))
    );
  };

  // One-time fresh start (7.33): earlier scores, cached boards and queued uploads are cleared on this device.
  try {
    if (localStorage.getItem('zs7-fresh-board') !== '1') {
      for (const k of ['zs7-bests', 'zs7-records', 'zs7-board', 'zs7-pending']) localStorage.removeItem(k);
      localStorage.setItem('zs7-fresh-board', '1');
    }
  } catch {}

  class Scores {
    constructor() {
      this.device = read('zs7-device', null);
      if (!/^[a-f0-9]{64}$/.test(this.device || '')) {
        this.device = Array.from(crypto.getRandomValues(new Uint8Array(32)), (b) =>
          b.toString(16).padStart(2, '0'),
        ).join('');
        write('zs7-device', this.device);
      }
      const best=read('zs7-bests', {});
      this.best=Object.assign(Object.create(null),best && typeof best==='object' && !Array.isArray(best)?best:{});
      this.records=read('zs7-records',[]);
      if(!Array.isArray(this.records)) this.records=[];
      this.pending = read('zs7-pending', []);
      if(!Array.isArray(this.pending)) this.pending=[];
      this.flushing = false;
      this.rejected = new Set();
      this.lastError = '';
      addEventListener('online', () => this.flush());
      document.addEventListener('visibilitychange',()=>{if(!document.hidden)this.flush();});
    }
    validName(name) {
      return (
        /^[\p{L}\p{N} _.-]{2,24}$/u.test(name.trim()) &&
        /[\p{L}\p{N}]/u.test(name) &&
        !isObjectionable(name)
      );
    }
    // A short reason for the player when the online board cannot be reached.
    describe(error) {
      const status = error?.status ? 'HTTP ' + error.status + ' ' : '';
      return (status + String(error?.message || 'network error')).slice(0, 80);
    }
    async rpc(name, body = {}) {
      const controller = new AbortController();
      let timer;
      // The timeout is a race as well as an abort: the iPhone app's native HTTP layer ignores abort signals.
      const timeout = new Promise((_, reject) => {
        timer = setTimeout(() => {
          controller.abort();
          reject(Error('timed out'));
        }, 8000);
      });
      try {
        return await Promise.race([
          (async () => {
            const r = await fetch(endpoint + name, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json', apikey: key },
              body: JSON.stringify(body),
              signal: controller.signal,
            });
            const value = await r.json();
            if (!r.ok) {
              const error = Error(value.message || 'Board unavailable');
              error.status = r.status;
              throw error;
            }
            return value;
          })(),
          timeout,
        ]);
      } finally {
        clearTimeout(timer);
      }
    }
    async begin(name) {
      try {
        this.lastError = '';
        return await this.rpc('zs7_begin_run', { p_device: this.device, p_name: name.trim() });
      } catch (error) {
        this.lastError = this.describe(error);
        return null;
      }
    }
    getBest(name) {
      const n=Number(this.best[String(name).trim().toLowerCase()]);
      return Number.isFinite(n)?Math.max(0,n):0;
    }
    recordLocal(run) {
      if(run.practice || !run.name || !Number.isFinite(run.score) || run.score<0) return;
      const name=run.name.trim(), key=name.toLowerCase();
      this.best[key]=Math.max(this.getBest(name),Math.floor(run.score));
      write('zs7-bests',this.best);
      const record={id:run.id||run.ticket||`${key}:${run.score}:${run.seconds}`,name,score:Math.floor(run.score),savedAt:Date.now()};
      this.records=this.records.filter(r=>r.id!==record.id);this.records.push(record);this.records=this.records.slice(-100);
      write('zs7-records',this.records);
    }
    localBoard() {
      return Object.entries(this.best).filter(([,v])=>Number.isFinite(Number(v))&&Number(v)>0).map(([key,score])=>({name:this.records.find(r=>r.name?.toLowerCase()===key)?.name||key,score:Number(score)})).sort((a,b)=>b.score-a.score);
    }
    async finish(run) {
      if (run.practice) return { status: 'practice' };
      this.recordLocal(run);
      if (!run.ticket) return { status: 'local' };
      const entry = {
        p_device: this.device,
        p_ticket: run.ticket,
        p_score: run.score,
        p_kills: run.kills,
        p_seconds: Math.floor(run.seconds),
        p_wave: run.wave,
        p_practice: false,
      };
      if (!this.pending.some((p) => p.p_ticket === entry.p_ticket)) this.pending.push(entry);
      write('zs7-pending', this.pending);
      await this.flush();
      return {
        status: this.pending.some((p) => p.p_ticket === entry.p_ticket)
          ? 'pending'
          : this.rejected.has(entry.p_ticket)
            ? 'rejected'
            : 'online',
      };
    }
    flush() {
      if(this.flushPromise) return this.flushPromise;
      if(!this.pending.length) return Promise.resolve();
      this.flushPromise=this.drain().finally(()=>{this.flushPromise=null;});
      return this.flushPromise;
    }
    async drain() {
      this.flushing = true;
      try {
        while (this.pending.length) {
          const run=this.pending[0];
          try {
            const accepted = await this.rpc('zs7_finish_run', run);
            if (accepted !== true) {
              this.rejected.add(run.p_ticket);
              this.lastError = 'run not accepted';
            }
          } catch (error) {
            this.lastError = this.describe(error);
            if (![400, 422].includes(error.status)) break;
            this.rejected.add(run.p_ticket);
          }
          this.pending = this.pending.filter((p) => p.p_ticket !== run.p_ticket);
          write('zs7-pending', this.pending);
        }
      } finally {
        this.flushing = false;
      }
    }

    async board() {
      try {
        const rows = await this.rpc('zs7_leaderboard');
        if(!Array.isArray(rows)) throw Error('Invalid board response');
        write('zs7-board', rows);
        this.lastError = '';
        return { rows, online: true };
      } catch (error) {
        const reason = this.describe(error);
        this.lastError = reason;
        const rows = read('zs7-board', null) || [];
        return { rows, online: false, error: reason };
      }
    }
  }
  window.ZSScores = Scores;
})();
