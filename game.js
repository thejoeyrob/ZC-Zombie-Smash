(() => {
  'use strict';
  // The packaged iPhone app loads from capacitor://; on the web we keep the install tool.
  const nativeApp = location.protocol === 'capacitor:' || !!window.Capacitor?.isNativePlatform?.();
  const newId = () =>
    crypto.randomUUID?.() ??
    '10000000-1000-4000-8000-100000000000'.replace(/[018]/g, (c) =>
      (c ^ (crypto.getRandomValues(new Uint8Array(1))[0] & (15 >> (c / 4)))).toString(16),
    );
  const $ = (id) => document.getElementById(id),
    esc = (s) =>
      String(s ?? '').replace(
        /[&<>"']/g,
        (c) =>
          ({
            '&': '&amp;',
            '<': '&lt;',
            '>': '&gt;',
            '"': '&quot;',
            "'": '&#39;',
          })[c],
      );
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
  const { BOSSES, SKINS, MAPS } = ZSData,
    audio = new ZSAudio(),
    haptics = new ZSHaptics(),
    scores = new ZSScores(),
    renderer = new ZSRenderer($('gameCanvas'));
  const APP_VER =
    (document.querySelector('script[src*="game.js"]')?.src.match(/[?&]v=([\d.]+)/) || [])[1] || '';
  // Finished scene clips and extra console skins are listed by scripts/sync-art.mjs.
  // A scene with no listed clip, or a clip that fails to load, uses the built-in scene.
  let sceneClips = {};
  let soundPreview = 0;
  const failedClips = new Set();
  fetch('./scene-clips.json')
    .then((r) => r.json())
    .then((j) => {
      sceneClips = j.clips || {};
    })
    .catch(() => {});
  // Each film's panel entry times (seconds). FIRE jumps to the next panel instead of skipping the whole scene.
  let sceneBeats = {};
  fetch('./scene-beats.json')
    .then((r) => r.json())
    .then((j) => {
      sceneBeats = j.beats || {};
    })
    .catch(() => {});
  // Seek a playing film to its next panel; false when every panel has already been shown.
  function beatNext(video, key) {
    const list = sceneBeats[key];
    if (!video || !list || !Number.isFinite(video.currentTime)) return false;
    const next = list.find((t) => t > video.currentTime + 0.25);
    if (next === undefined) return false;
    video.currentTime = next;
    video.play?.()?.catch?.(() => {});
    return true;
  }
  function sceneAdvance() {
    const v = document.querySelector('#cinematic video.scene-clip');
    if (v && beatNext(v, v.dataset.key)) return;
    // Both close-ups are showing: the picture splits apart straight into the game.
    if (v && game.scene) {
      v._endScene?.();
      return;
    }
    game.advanceScene();
  }
  // The last frame is copied onto two canvases (a diagonal cut) that slide off the screen, so the game appears
  // underneath. Nothing but two stills moves, and the video itself is released at once.
  function splitAway(box, done) {
    if (box.classList.contains('splitting')) return;
    const v = box.querySelector('video.scene-clip');
    if (!v || !v.videoWidth || matchMedia('(prefers-reduced-motion:reduce)').matches) {
      done();
      return;
    }
    box.classList.add('splitting');
    box.closest('.screen')?.classList.add('clip-split');
    const wrap = document.createElement('div');
    wrap.className = 'split-halves';
    for (const [name, clip] of [
      ['top', 'polygon(0 0, 100% 0, 100% 57%, 0 43%)'],
      ['bottom', 'polygon(0 43%, 100% 57%, 100% 100%, 0 100%)'],
    ]) {
      const cv = document.createElement('canvas');
      cv.width = v.videoWidth;
      cv.height = v.videoHeight;
      cv.getContext('2d').drawImage(v, 0, 0);
      cv.className = 'split-' + name;
      cv.style.clipPath = clip;
      wrap.appendChild(cv);
    }
    box.appendChild(wrap);
    v.pause();
    setTimeout(() => {
      wrap.remove();
      box.classList.remove('splitting');
      box.closest('.screen')?.classList.remove('clip-split');
      done();
    }, 430);
  }
  let pendingReload = false;
  function reloadWhenSafe() {
    if (!pendingReload || (typeof game !== 'undefined' && game.active && !paused)) return;
    pendingReload = false;
    location.reload();
  }
  // BOT_ before a player name switches on cheat mode: it is never shown, it dispenses the secret skins
  // and it opens the CHEATS menu, where every cheat has a code made of joystick flicks and button taps.
  // Case sensitive: BOT_ exactly.
  const BOT_PREFIX = /^BOT_/;
  const parseName = (raw) => {
    raw = String(raw ?? '').trim();
    const isBot = BOT_PREFIX.test(raw);
    return {
      bot: isBot,
      name: isBot ? raw.replace(BOT_PREFIX, '').trim() : raw,
    };
  };
  const unlockedSkins = () => new Set(read('zs7-unlocked', []));
  const beatenBosses = () => new Set(read('zs7-beaten', []));
  // Character skins unlock when their boss is beaten; secret custom skins unlock through BOT mode.
  const skinLocked = (skin) =>
    skin.boss
      ? !beatenBosses().has(skin.boss) && !unlockedSkins().has(skin.id)
      : !!skin.secret && !unlockedSkins().has(skin.id);
  const lockText = (skin) => {
    const boss = BOSSES.find((b) => b.id === skin.boss);
    return boss
      ? `${skin.name} skin needs to be unlocked. Beat ${boss.name} first.`
      : `${skin.name} skin needs to be unlocked. It is a secret finish.`;
  };
  function unlockSecretSkins() {
    const have = unlockedSkins();
    let added = 0;
    for (const s of SKINS)
      if ((s.secret || s.boss) && !have.has(s.id)) {
        have.add(s.id);
        added++;
      }
    write('zs7-unlocked', [...have]);
    return added;
  }
  let bot = false,
    pendingBot = false,
    cheatBuf = '',
    cheatLast = 0,
    stickDir = 0;
  let ready = false,
    paused = true,
    landscape = false,
    run = null,
    pendingName = '',
    sceneKey = '',
    panel = '',
    lastTime = 0,
    accumulator = 0,
    saveClock = 0,
    toastTimer,
    installPrompt,
    lastFit = '',
    fitDirty = true; // the layout is measured when the window changes, not on every frame
  let storyStep = 0,
    storyTimer = null,
    storyVideo = null,
    storyReplay = false;
  let stickOrigin = null,
    touchAxis = 0,
    touchFire = false,
    stickId = null,
    fireId = null,
    keys = new Set(),
    padGrenade = false;
  const game = new ZSEngine.Game({ onEvent: event });
  function toast(message) {
    $('toast').textContent = message;
    $('toast').hidden = false;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => ($('toast').hidden = true), 3100);
  }
  function clearInput() {
    flickUntil = 0;
    stickOrigin = null;
    touchAxis = 0;
    touchFire = false;
    stickId = null;
    fireId = null;
    keys.clear();
    stickDir = 0;
    game.resetInput();
    $('stickKnob').style.transform = 'translateX(0)';
    $('joystick').style.setProperty('--lean', '0deg');
    $('fireButton').classList.remove('pressed');
    $('joystick').setAttribute('aria-valuenow', '0');
    stickLamp(0);
  }
  let pendingSave = null;
  function queueSave() {
    if (pendingSave !== null) return;
    const callback = () => { pendingSave = null; save(); };
    pendingSave = window.requestIdleCallback
      ? window.requestIdleCallback(callback, {timeout: 1200}) : setTimeout(callback, 0);
  }
  function save() {
    if (pendingSave !== null) {
      if (window.requestIdleCallback) window.cancelIdleCallback(pendingSave);
      else clearTimeout(pendingSave);
      pendingSave = null;
    }
    if (run && game.active && !game.over)
      write('zs7-run', {
        engine: game.snapshot(),
        run: { id: run.id, name: run.name, ticket: run.ticket, bot, cheated: !!run.cheated },
      });
    else if (game.over)
      try {
        localStorage.removeItem('zs7-run');
      } catch {}
  }
  function pause(immediate = false) {
    paused = true;
    clearInput();
    audio.pause(immediate);
    $('cinematic').querySelector('video')?.pause();
    save();
    reloadWhenSafe();
  }
  // The music for a boss fight: Disco Man has his own theme, every other boss uses the boss music.
  const bossTrack = (id) => (id === 'discoman' ? 'disco' : 'boss');
  function resume() {
    if (!game.active || game.over || landscape) return;
    paused = false;
    accumulator = 0;
    lastTime = performance.now();
    audio.resume();
    audio.playMusic(
      game.scene?.kind === 'arrival' ? 'entrance' : game.boss ? bossTrack(game.boss.bossId) : 'main',
    );
  }
  function closePanel() {
    soundPreview++;
    endPreview();
    // The menu was opened during the story: carry on with the clip that was playing.
    if (storyActive && panel !== 'story') {
      panel = '';
      showStory(pendingName, storyStep);
      return;
    }
    const wasMenu = panel === 'menu';
    panel = '';
    $('overlay').hidden = true;
    clearInput();
    if (game.active && !game.over) {
      if (!awaitStart) resume();
      if (wasMenu && !awaitStart && performance.now() - menuOpenedAt < 6000) armCheats();
    } else showStart();
    $('menuButton').focus({ preventScroll: true });
  }
  function showPanel(kind, title, html, { closable = true, start = false } = {}) {
    soundPreview++;
    if (kind !== 'skins') endPreview();
    clearTimeout(storyTimer);
    pause();
    panel = kind;
    const box = $('overlay');
    box.classList.remove('story-mode');
    box.hidden = false;
    box.innerHTML =
      (title
        ? `<div class="panel-head"><h2>${esc(title)}</h2>${closable ? '<button data-action="close" aria-label="Close panel">×</button>' : ''}</div>`
        : '') + `<div class="panel-content ${start ? 'start-panel' : ''}">${html}</div>`;
  }
  function showStart() {
    storyActive = false;
    $('fireButton')?.classList.remove('story-hint');
    awaitStart = false;
    $('startPrompt').hidden = true;
    const hi = Object.entries(scores.best || {}).sort((a, b) => b[1] - a[1])[0] || ['', 0],
      beaten = beatenBosses();
    showPanel(
      'start',
      '',
`<div class="title-screen"><div class="title-art" aria-hidden="true"></div><div class="title-ui"><div class="title-top"><div class="title-hi"><span>HI <b>${Number(hi[1]).toLocaleString()}</b></span></div><h1 class="title-logo" aria-label="Zombie Smash"><span class="tl-1" aria-hidden="true">${[...'ZOMBIE'].map((ch, i) => `<i class="l" style="--i:${i}">${ch}</i>`).join('')}</span><span class="tl-2" aria-hidden="true">${[...'SMASH'].map((ch, i) => `<i class="l" style="--i:${i + 6}">${ch}</i>`).join('')}</span></h1><div class="title-tag">HOLD THE LINE</div></div><div class="title-bottom"><button class="press-fire" data-action="player" aria-label="Press fire to start the game"><b class="press-start">PRESS FIRE</b><small>TO START GAME</small></button><div class="title-bosses" aria-label="Bosses defeated">${BOSSES.map((b) => `<span class="tb ${beaten.has(b.id) ? 'down' : ''}" style="--c:${b.accent}"><img src="./${b.sprites[0]}" alt="${esc(b.name)}"></span>`).join('')}</div><div class="title-count">${beaten.size} OF ${BOSSES.length} BOSSES DOWN</div><div class="loading-line" id="loadingLine">${ready ? '' : 'Loading game artwork…'}</div></div></div></div>`,
      { start: true, closable: false },
    );
    $('fireButton').classList.add('story-hint');
  }
  // Player entry: its own screen. A name that was already entered is shown locked, with CHANGE to edit it;
  // without one the box is open and CHANGE is greyed out. CONTINUE appears only when a run was left half played.
  function showPlayer() {
    $('fireButton')?.classList.remove('story-hint');
    const raw = String(read('zs7-name', '') || ''),
      named = !!raw && scores.validName(parseName(raw).name),
      saved = read('zs7-run', null),
      half = !!(saved?.engine?.active && saved?.run?.name);
    showPanel(
      'player',
      '',
      `<div class="player-screen"><div class="pl-title">ZOMBIE SMASH</div><div class="pl-sub">PLAYER REGISTRATION</div><form id="playerForm" autocomplete="off"><label class="pl-label" for="username">&gt; ENTER PLAYER NAME</label><input name="username" id="username" value="${esc(named ? raw : '')}" maxlength="24" minlength="2" autocomplete="off" autocorrect="off" autocapitalize="none" spellcheck="false" placeholder="NAME_" required ${named ? 'readonly' : ''}><button type="button" class="pl-btn" id="nameChange" data-action="name-change" ${named ? '' : 'disabled'}>CHANGE</button><div class="pl-rule"></div><button type="submit" class="pl-btn pl-main" id="newGameBtn" ${ready ? '' : 'disabled'}>NEW GAME</button>${half ? `<button type="button" class="pl-btn pl-main" data-action="continue">CONTINUE · WAVE ${Number(saved.engine.wave) || 1}</button>` : ''}</form><button type="button" class="pl-back" data-action="home">&lt; BACK</button></div>`,
      { start: true, closable: false },
    );
  }
  // Retro attract mode: a low-resolution canvas scaled up with hard pixels. Joey shoots zombies down a street under a red moon.
  let titleBounds = null;
  function menu() {
    if (panel === 'menu') {
      closePanel();
      return;
    }
    menuOpenedAt = performance.now();
    showPanel(
      'menu',
      'GAME MENU',
      `${game.active ? '<button class="primary-action" data-action="close">RESUME GAME</button>' : '<button class="primary-action" data-action="home">PLAY ZOMBIE SMASH</button>'}<button class="menu-action" data-action="skins">CONSOLE SKINS <small>${SKINS.filter((x) => !skinLocked(x)).length} of ${SKINS.length} unlocked →</small></button>${coffeeOn() ? `<button class="menu-action" data-action="coffee">BUY ME A COFFEE <small>Support the developer →</small></button>` : ''}<button class="menu-action" data-action="board">HIGH SCORES <small>The leaderboard →</small></button><button class="menu-action" data-action="sound">MUSIC & SOUND <small>Set your mix →</small></button><button class="menu-action" data-action="story">THE STORY <small>Replay the comic →</small></button><button class="menu-action" data-action="help">HOW TO PLAY <small>Controls & boosts →</small></button><button class="menu-action" data-action="privacy">PRIVACY POLICY <small>How leaderboard data is used →</small></button>${nativeApp ? '' : '<button class="menu-action" data-action="install">INSTALL GAME <small>Play from Home Screen →</small></button>'}${game.active ? '<button class="menu-action" data-action="restart">NEW GAME <small>Start over as the same player →</small></button><button class="menu-action" data-action="home">HOME SCREEN <small>Back to the title →</small></button>' : ''}${bot ? '<button class="menu-action cheat-entry" data-action="cheats">CHEATS <small>BOT mode · codes →</small></button>' : ''}<p class="menu-note">${run ? 'Playing as ' + esc(run.name) : 'Zombie Smash'} · v${APP_VER}<br>Portrait arcade · Joey Rob vs Dr Mantis</p>`,
    );
  }
  // A thank-you screen shown after PRESS START, before the story. Web version only: a Buy Me a Coffee link.
  // The iPhone app has no tip jar and no in-app purchases.
  const COFFEE_URL = 'https://buymeacoffee.com/JoeyRob';
  // Web only: the iPhone app has no tip jar, so coffeeOn() is false there.
  const coffeeOn = () => !nativeApp;
  let coffeeNext = null;
  function showCoffee(next, fromMenu = false, skipLabel = '') {
    coffeeNext = next;
    const beans = Array.from(
      { length: 14 },
      (_, i) =>
        `<i class="bean" style="--x:${Math.round(Math.random() * 100)}%;--d:${(Math.random() * 6).toFixed(2)}s;--t:${(5 + Math.random() * 5).toFixed(2)}s;--s:${(0.7 + Math.random() * 0.7).toFixed(2)}"></i>`,
    ).join('');
    showPanel(
      'coffee',
      '',
      `<div class="coffee-screen"><div class="coffee-beans" aria-hidden="true">${beans}</div><div class="coffee-ui"><div class="coffee-kicker">ENJOYING THE FIGHT?</div><h2 class="coffee-title"><span>FUEL</span><span>THE DEV</span></h2><div class="coffee-art" aria-hidden="true"><img class="coffee-joey" src="./player-victory.webp" alt=""><img class="coffee-sloth" src="./boss-caffeinatedsloth-stage1.webp" alt=""><svg class="coffee-cup" viewBox="0 0 120 120"><g class="steam"><path d="M38 34c-8-8 8-14 0-24M60 34c-8-8 8-14 0-24M82 34c-8-8 8-14 0-24" fill="none" stroke="#fff" stroke-opacity=".7" stroke-width="4" stroke-linecap="round"/></g><path d="M22 42h76l-8 56a10 10 0 0 1-10 8H40a10 10 0 0 1-10-8z" fill="#fff6dc" stroke="#2a160a" stroke-width="5" stroke-linejoin="round"/><path d="M98 52h8a12 12 0 0 1 0 28h-12" fill="none" stroke="#2a160a" stroke-width="5" stroke-linecap="round"/><path d="M26 50h68l-2 14H28z" fill="#6b3a1a"/><path d="M44 64v14c0 5 8 5 8 0V64M70 64v22c0 6 9 6 9 0V64" fill="#7dff2a" stroke="#2a8a10" stroke-width="2"/><text x="60" y="95" text-anchor="middle" font-family="Barlow,sans-serif" font-weight="900" font-size="20" fill="#2a160a">ZS</text></svg></div><p class="coffee-copy">Zombie Smash is <b>free</b>. No ads. No login. If you're having fun, you can help the next boss get built.</p><a class="bmc" href="${COFFEE_URL}" target="_blank" rel="noopener noreferrer"><span class="bmc-cup">☕</span> BUY JOEY A COFFEE</a><button class="coffee-skip" data-action="coffee-skip">${fromMenu ? 'BACK TO MENU' : skipLabel || 'NOT NOW · ON TO THE STORY ▶'}</button></div></div>`,
      { start: true, closable: false },
    );
  }
  function start(raw, skipIntro = false) {
    storyReplay = false;
    audio.unlock();
    raw = String(raw ?? '').trim();
    const { bot: isBot, name } = parseName(raw);
    if (!scores.validName(name)) {
      toast('Use 2–24 letters, numbers, spaces, dots, dashes or underscores. Keep it friendly.');
      return;
    }
    write('zs7-name', raw);
    pendingName = name;
    pendingBot = isBot;
    if (!skipIntro) {
      if (coffeeOn()) showCoffee(() => showStory(name, 0));
      else showStory(name, 0);
      return;
    }
    // Every run starts with the coffee screen (web version only), then plays.
    if (coffeeOn()) showCoffee(() => beginRun(name), false, 'NOT NOW · PLAY ▶');
    else beginRun(name);
  }
  // The intro is three animated clips (burned-in captions) that fill the gameplay screen.
  // FIRE skips exactly one clip per press, and each clip moves on by itself when it ends.
  let storyActive = false,
    storyPreload = null,
    storyWatchdog = null,
    storyLoadToken = 0;
  function showStory(name, index = 0) {
    const token = ++storyLoadToken;
    clearInterval(storyWatchdog);
    if (storyPreload) { storyPreload.removeAttribute('src'); storyPreload.load?.(); storyPreload = null; }
    pendingName = name;
    storyStep = index;
    storyActive = true;
    if (panel !== 'story' || !$('storyVideo')) {
      showPanel(
        'story',
        '',
        '<div class="story-full"><video id="storyVideo" muted playsinline webkit-playsinline preload="auto" disablepictureinpicture aria-label="The story so far"></video></div>',
        { closable: false },
      );
      $('overlay').classList.add('story-mode');
      $('fireButton').classList.add('story-hint');
      audio.resume();
      audio.playMusic('story');
    }
    const playVideo = () => {
      const v = $('storyVideo');
      storyVideo = v;
      v.onended = () => {
        if (token === storyLoadToken && storyActive && panel === 'story') storyNext();
      };
      // If a clip cannot load, move on instead of leaving a black screen.
      v.onerror = () => {
        setTimeout(() => {
          if (token === storyLoadToken && storyActive && panel === 'story' && storyVideo === v) storyNext();
        }, 400);
      };
      let lastProgress = performance.now(), lastPosition = -1;
      storyWatchdog = setInterval(() => {
        if (token !== storyLoadToken || !storyActive || panel !== 'story') return;
        const now = performance.now();
        if (document.hidden || v.currentTime > lastPosition + 0.01) { lastProgress = now; lastPosition = v.currentTime; }
        else if (now - lastProgress > 12000) storyNext();
      }, 1000);
      v.src = `./story-${index + 1}.mp4`;
      v.currentTime = 0;
      v.play().catch(() => {});
      audio.sfx('whoosh', 0.7);
      if (index < 2) {
        storyPreload = document.createElement('video');
        storyPreload.preload = 'auto';
        storyPreload.muted = true;
        storyPreload.src = `./story-${index + 2}.mp4`;
      }
    };
    playVideo();
  }
  // A FIRE press brings in the next close-up panel first; once both are shown it moves to the next part of the story.
  function storySkip() {
    if (storyActive && beatNext(storyVideo, 'story-' + (storyStep + 1))) {
      haptics.impact('LIGHT', 'ui', 0, true);
      return;
    }
    storyNext();
  }
  function storyNext() {
    if (!storyActive) return;
    haptics.impact('LIGHT', 'ui', 0, true);
    if (storyStep < 2) showStory(pendingName, storyStep + 1);
    else storyEnd();
  }
  function storyEnd() {
    ++storyLoadToken;
    clearInterval(storyWatchdog);
    storyActive = false;
    $('fireButton').classList.remove('story-hint');
    const v = $('storyVideo');
    if (v) {
      v.onended = null;
      v.onerror = null;
      v.pause();
      v.removeAttribute('src');
      v.load?.();
    }
    storyVideo = null;
    if (storyPreload) {
      storyPreload.removeAttribute('src');
      storyPreload.load?.();
      storyPreload = null;
    }
    $('overlay').classList.remove('story-mode');
    $('overlay').innerHTML = '';
    if (storyReplay) {
      storyReplay = false;
      closePanel();
    } else beginRun(pendingName || parseName(read('zs7-name', 'Player')).name || 'Player');
  }
  // After the intro (and before every run) the game waits: any button starts it, and that press does nothing else.
  let awaitStart = false,
    padHeld = false;
  function armStart() {
    awaitStart = true;
    paused = true;
    clearInput();
    $('startPrompt').hidden = false;
    audio.pause();
  }
  function startNow() {
    if (!awaitStart || panel) return false;
    awaitStart = false;
    $('startPrompt').hidden = true;
    haptics.impact('MEDIUM', 'ui', 0, true);
    resume();
    return true;
  }
  // Gamepads are only polled once one has announced itself.
  let padOn = false;
  addEventListener('gamepadconnected', () => (padOn = true));
  function padWatch() {
    try {
      const pad = padOn ? Array.from(navigator.getGamepads?.() || []).find(Boolean) : null,
        any = !!pad && pad.buttons.some((b) => b.pressed);
      if (any && !padHeld) {
        if (storyActive) {
          if (pad.buttons[0]?.pressed || pad.buttons[7]?.pressed) storySkip();
        } else if (awaitStart) startNow();
        else if (panel === 'start' && (pad.buttons[0]?.pressed || pad.buttons[7]?.pressed)) showPlayer();
      }
      padHeld = any;
    } catch {}
  }

  function beginRun(name) {
    clearTimeout(storyTimer);
    write('zs7-story-seen', true);
    bot = pendingBot;
    run = { id: newId(), name, ticket: null, submitted: false, bot };
    if (bot) unlockSecretSkins();
    const thisRun = run;
    thisRun.ticketPromise = scores.begin(name).then((ticket) => {
      thisRun.ticket = ticket;
      if (run === thisRun) save();
      return ticket;
    });
    game.reset();
    $('overlay').hidden = true;
    panel = '';
    sceneKey = '';
    game.start();
    save();
    armStart();
  }
  let previewing = '';
  function paintSkin(skin) {
    document.body.dataset.releaseSkin = skin.id;
    document.body.classList.toggle('deck3d', !!skin.deck3d);
    for (const [k, v] of Object.entries({
      '--skin-art': `url('./${skin.file}')`,
      '--accent': skin.accent,
      '--bleed': skin.bleed,
      '--fire': skin.fire || '#ef3042',
      '--grenade': skin.grenade || '#159de8',
      '--stick': skin.stick || '#d8a34e',
    }))
      document.body.style.setProperty(k, v);
    document.querySelector('.shell-art').innerHTML = ZSConsole.markup(skin);
    window.ZSLedBar?.wake();
  }
  function applySkin(id) {
    // An extra skin is still loading at start-up, so the saved choice is only overwritten by a real match.
    const wanted = SKINS.find((s) => s.id === id && !skinLocked(s)),
      skin = wanted || SKINS.find((s) => !skinLocked(s)) || SKINS[0];
    previewing = '';
    paintSkin(skin);
    if (wanted) write('zs7-skin', skin.id);
  }
  // A locked skin can be tried on the console while the skins menu is open. Leaving the menu puts the
  // chosen skin back and says what unlocks it.
  function previewSkin(id) {
    const skin = SKINS.find((x) => x.id === id);
    if (!skin) return;
    previewing = skin.id;
    paintSkin(skin);
  }
  function endPreview() {
    if (!previewing) return;
    const skin = SKINS.find((x) => x.id === previewing);
    previewing = '';
    const saved = SKINS.find((x) => x.id === read('zs7-skin', 'retro-handheld') && !skinLocked(x));
    paintSkin(saved || SKINS[0]);
    if (skin) toast(lockText(skin));
  }
  function skins(group) {
    const current = read('zs7-skin', 'retro-handheld'),
      open = SKINS.filter((x) => !skinLocked(x)).length,
      tile = (s) => {
        const locked = skinLocked(s),
          boss = BOSSES.find((b) => b.id === s.boss),
          badge = locked ? (boss ? 'BEAT ' + boss.name.split(' ')[0] : 'SECRET') : '';
        return `<button class="skin-choice ${current === s.id && !locked ? 'selected' : ''} ${locked ? 'locked' : ''} ${previewing === s.id ? 'previewing' : ''}" ${locked ? `data-preview="${s.id}"` : `data-skin="${s.id}" aria-pressed="${current === s.id}"`}><span class="skin-thumbnail" aria-hidden="true"><span class="skin-miniature" style="--accent:${s.accent};--stick:${s.stick};--fire:${s.fire};--grenade:${s.grenade}">${ZSConsole.markup(s)}<i class="preview-screen"></i><i class="preview-stick"></i><i class="preview-fire"></i><i class="preview-grenade"></i></span></span><b>${s.name}</b>${locked ? `<small>🔒 ${badge}</small>` : ''}</button>`;
      },
      grid = (list) => `<div class="skin-options">${list.map(tile).join('')}</div>`,
      characters = SKINS.filter((x) => x.group === 'character'),
      customs = SKINS.filter((x) => x.group !== 'character'),
      count = (list) => `${list.filter((x) => !skinLocked(x)).length} of ${list.length}`;
    if (!group)
      return showPanel(
        'skins',
        'CHOOSE YOUR CONSOLE',
        `<p class="menu-note">${open} of ${SKINS.length} unlocked. Tap a locked skin to try it on; it goes back when you close the menu. Character skins unlock as you beat each boss.</p><button class="skin-group-card" data-action="skins-char"><b>SPECIAL CHARACTER SKINS</b><span>${count(characters)} unlocked</span><i aria-hidden="true">›</i></button><button class="skin-group-card" data-action="skins-custom"><b>CUSTOM SKINS</b><span>${count(customs)} unlocked</span><i aria-hidden="true">›</i></button><button class="secondary-action" data-action="menu">‹ BACK TO MENU</button>`,
      );
    const list = group === 'char' ? characters : customs;
    showPanel(
      'skins',
      group === 'char' ? 'CHARACTER SKINS' : 'CUSTOM SKINS',
      `<button class="back-link" data-action="skins">‹ BACK</button><p class="menu-note">${count(list)} unlocked. Same arena, same controls, same aim — whichever finish you pick.</p>${grid(list)}<button class="secondary-action" data-action="skins">‹ BACK TO SKIN TYPES</button>`
    );
  }
  async function board() {
    const local = () => '';
    showPanel('board', 'HIGH SCORES', local()+'<p class="menu-note">Connecting to the global board…</p><button class="secondary-action" data-action="menu">BACK TO MENU</button>');
    const result = await scores.board();
    if (panel !== 'board') return;
    const rows = Array.isArray(result.rows) ? result.rows : [],
      nameOf = (r) => String(r.username || r.name || r.gamertag || ''),
      isCheat = (r) => nameOf(r).toLowerCase().endsWith(CHEAT_MARK),
      plain = (n) => (n.toLowerCase().endsWith(CHEAT_MARK) ? n.slice(0, -CHEAT_MARK.length) : n),
      scoreOf = (r) => Number(r.score || r.high_score || 0),
      me = (run?.name || parseName(read('zs7-name', '')).name).trim(),
      mine = me ? scores.getBest(me) : 0,
      listed = rows.some(
        (r) => plain(nameOf(r)).toLowerCase() === me.toLowerCase() && scoreOf(r) >= mine,
      ),
      youRow =
        mine > 0 && !listed
          ? `<div class="board-row you"><b class="rank">YOU</b><span>${esc(me)}<small>YOUR BEST · NOT ON THE BOARD</small></span><b class="points">${mine.toLocaleString()}</b></div>`
          : '';
    $('overlay').querySelector('.panel-content').innerHTML =
      local() + `<h3 class="skin-group">LEADERBOARD · ALL PLAYERS</h3><p class="menu-note">${result.online ? 'Online leaderboard' : 'Saved leaderboard · offline'}${result.online ? '' : `<br>Could not reach the online board${result.error ? ' (' + esc(result.error) + ')' : ''}.`}<br>A fresh leaderboard: finish a run to claim the top spot.</p>${rows.length ? '' : '<p class="menu-note">No scores yet.</p>'}${rows.map((r, i) => `<div class="board-row ${isCheat(r) ? 'cheat' : ''}"><b class="rank">${i + 1}</b><span>${esc(plain(nameOf(r)))}${isCheat(r) ? '<i class="cheat-mark" title="A cheat code was used">✦</i>' : ''}${r.legacy ? '<small>ORIGINAL RECORD</small>' : ''}</span><b class="points">${scoreOf(r).toLocaleString()}</b></div>`).join('')}${youRow}${result.online ? '' : '<button class="secondary-action" data-action="board">TRY AGAIN</button>'}<button class="secondary-action" data-action="menu">BACK TO MENU</button>`;
  }
  function sound() {
    showPanel(
      'sound',
      'MUSIC & SOUND',
      `<p class="menu-note">Set your music and effects mix. Sound may play even with the iPhone silent switch on.</p><label class="setting">MUSIC <input aria-label="Music volume" data-volume="music" type="range" min="0" max="100" value="${audio.settings.music * 100}"></label><label class="setting">EFFECTS <input aria-label="Effects volume" data-volume="effects" type="range" min="0" max="100" value="${audio.settings.effects * 100}"></label><label class="setting">HAPTICS <input type="checkbox" data-haptics ${haptics.on ? 'checked' : ''}></label><button class="secondary-action" data-action="preview-sound">PREVIEW MIX</button><button class="secondary-action" data-action="fix-sound">NO SOUND? RESET AUDIO</button><button class="secondary-action" data-action="menu">BACK TO MENU</button>`,
    );
  }
  function help() {
    showPanel(
      'help',
      'HOLD THE LINE',
      `<p class="menu-note"><strong>MOVE</strong> — slide the left joystick sideways. Joey stays on his defence line.<br><br><strong>FIRE</strong> — hold the red button. Drag and fire together.<br><br><strong>GRENADE</strong> — tap the blue centre button. The grenade travels straight up Joey's current lane — there is no auto-aim. Line yourself up first.<br><br><strong>BOOST</strong> — chain kills within 7 seconds: 10 kills = ×2, 20 = ×4, 30 = ×10. Taking damage or letting a zombie into camp breaks the chain.<br><br><strong>WATCH THE HORDE</strong> — runners warn before charging, toxic zombies fire slime, Fuse tanks can chain-react, and Bulwark shields open between pulses. DMR rounds and grenades punch through shields.<br><br><strong>BARRELS</strong> — shoot the red hazard barrels. Their blast radius is 20% of the arena width and can chain into nearby barrels. Debo’s thrown barrels land inside a wide marked ring: move clear of the whole ring, or shoot them early near him.<br><br><strong>PICKUPS</strong> — drops are deliberately rarer. Walk into a drop or shoot it to collect it; drops stay about 15 seconds, even through boss scenes. A gold heart adds a bonus life, up to 10. Special guns are stored in the four HUD slots; tap the stored weapon you want, even while moving. You can hold one ammo run of each gun type.<br><br><strong>ARENA TARGETS</strong> — shoot all three numbered floor lights to trigger the arena boost. They recharge after 12 seconds. Zombies emerge from marked floor entrances and fan out into the arena.<br><br><strong>BOSSES</strong> — a new boss arrives every second wave. Watch the warning before each attack. Defeat Mantis to reach infinite survival.<br><br><strong>STORY SCENES</strong> — tap FIRE to bring in the next panel; tap again to move on.<br><br>MENU — the button under the grenade pauses the game and opens the menu.<br><br>Keyboard: ← → or A / D · Space = fire · G = grenade · P = pause.<br>Gamepad: left stick · A / right trigger = fire · B = grenade.</p><button class="secondary-action" data-action="menu">BACK TO MENU</button>`,
    );
  }
  // The privacy policy is bundled with the app and shown inside it (no browser needed); the web copy is the fallback.
  async function privacyPanel() {
    let body = '';
    try {
      const html = await (await fetch('./privacy.html')).text();
      body = new DOMParser().parseFromString(html, 'text/html').querySelector('main')?.innerHTML || '';
    } catch {}
    if (!body) body = '<p>The privacy policy is available at <a href="https://zc2.quest/privacy.html" target="_blank" rel="noopener">zc2.quest/privacy.html</a>.</p>';
    showPanel(
      'privacy',
      'PRIVACY POLICY',
      `<div class="menu-note privacy-text" style="text-align:left">${body}</div><button class="secondary-action" data-action="menu">BACK TO MENU</button>`,
    );
  }
  function install() {
    const installed = matchMedia('(display-mode:standalone)').matches || navigator.standalone;
    showPanel(
      'install',
      'TAKE THE HORDE WITH YOU',
      `<img class="start-art" src="./game-banner.webp" alt="Zombie Smash game advertisement"><h3 style="font:900 26px Barlow;color:#ffdc8b;margin:12px 0">SEVEN BOSSES. ONE LAST STAND.</h3><p class="menu-note">Big boss reveals. Explosive weapons. Your next high score.<br>Launch straight from your Home Screen, and play offline once the game has finished downloading.</p>${installed ? '<p class="menu-note">✓ You’re already playing the installed game.</p>' : installPrompt ? '<button class="primary-action" data-action="install-now">INSTALL ZOMBIE SMASH</button>' : '<p class="menu-note"><strong>iPhone / iPad</strong><br>Open this game in Safari. Tap Share, then “Add to Home Screen”.<br><br><strong>Android</strong><br>Open your browser menu and choose “Install app” or “Add to Home screen”.</p>'}<p class="menu-note" id="offlineStatus">${read('zs7-offline-ready', false) ? 'Game download complete · offline play ready.' : 'Keep the game open while its artwork and music download.'}</p><button class="secondary-action" data-action="menu">BACK TO MENU</button>`,
    );
  }
  // Cheat codes. Tokens: L / R = joystick pushed fully left / right (release between), F = FIRE tap, G = GRENADE tap.
  // Codes only work in BOT mode, while playing, with about two seconds at most between taps.
  const CHEATS = [
    {
      id: 'invincible',
      name: 'INVINCIBLE',
      info: 'Nothing can hurt Joey.',
      seq: 'LLRRFF',
      state: () => game.invincible,
      run: () => (game.invincible = !game.invincible),
    },
    {
      id: 'ammo',
      name: 'UNLIMITED AMMO',
      info: 'Every gun, no reloading.',
      seq: 'FFGGLR',
      state: () => game.infiniteAmmo,
      run: () => (game.infiniteAmmo = !game.infiniteAmmo),
    },
    {
      id: 'hearts',
      name: '10 HEARTS',
      info: '5 red + 5 gold hearts.',
      seq: 'RRLLGF',
      state: () => (game.maxLives || 5) > 5,
      run: () => game.setTenHearts((game.maxLives || 5) <= 5),
    },
    {
      id: 'grenades',
      name: 'REFILL GRENADES',
      info: 'Back to 9 grenades.',
      seq: 'GGGLL',
      run: () => (game.player.grenades = 9),
    },
    {
      id: 'guns',
      name: 'ALL SPECIAL GUNS',
      info: 'SMG, scatter, DMR and pulse stored with full ammo.',
      seq: 'FGFGLR',
      run: () => {
        for (const g of ['smg', 'shotgun', 'dmr', 'burst'])
          if (game.player.gun !== g) game.player.inventory[g] = ZSEngine.GUNS[g].ammo;
      },
    },
    {
      id: 'boss',
      name: 'JUMP TO NEXT BOSS',
      info: 'Starts the next boss you have not beaten.',
      seq: 'LRLRGG',
      run: () => {
        const next = BOSSES.find((b) => !game.bossesDown.includes(b.id));
        if (next) {
          game.skipBoss(next.id, 1);
          sceneKey = '';
        }
      },
    },
  ];
  const glyph = { L: '◀', R: '▶', F: 'FIRE', G: 'NADE' };
  // A run that used a cheat code outside BOT mode still counts on the board, but is marked: it is entered
  // under the player's name plus a short tag, which the board shows as a coloured name with a star.
  const CHEAT_MARK = '.cht';
  function markCheated() {
    if (!run || run.cheated) return;
    const r = run;
    r.cheated = true;
    const flagged = r.name.slice(0, 24 - CHEAT_MARK.length).trim() + CHEAT_MARK;
    r.ticket = null;
    r.ticketPromise = scores.begin(flagged).then((ticket) => {
      r.ticket = ticket;
      if (run === r) save();
      return ticket;
    });
  }
  // Codes only work for 10 seconds after the arming gesture: open the MENU and close it again (press MENU twice,
  // or open it and tap RESUME) within 6 seconds. Normal play can never trigger a cheat by accident.
  let cheatArmedUntil = 0,
    menuOpenedAt = 0;
  function armCheats() {
    cheatArmedUntil = performance.now() + 10000;
    cheatBuf = '';
  }
  function feedToken(token) {
    if (paused || !game.active || game.over) return;
    if (performance.now() > cheatArmedUntil) return;
    const now = performance.now();
    if (now - cheatLast > 2200) cheatBuf = '';
    cheatLast = now;
    cheatBuf = (cheatBuf + token).slice(-8);
    const hit = CHEATS.find((c) => cheatBuf.endsWith(c.seq));
    if (!hit) return;
    cheatBuf = '';
    cheatArmedUntil = 0; // each cheat needs a fresh arming
    const wasPractice = game.practice;
    if (!bot) markCheated();
    hit.run();
    // Some cheats flag the engine as practice-only; outside BOT mode the run still counts (it is marked instead).
    game.practice = bot ? true : wasPractice;
    save();
    audio.sfx('boost');
    haptics.notify('SUCCESS', 'cheat', 0);
  }
  function trackStick(axis) {
    const dir = axis < -0.6 ? -1 : axis > 0.6 ? 1 : Math.abs(axis) < 0.25 ? 0 : stickDir;
    if (dir !== stickDir) {
      stickDir = dir;
      if (dir) feedToken(dir < 0 ? 'L' : 'R');
    }
  }
  function cheatsPanel() {
    showPanel(
      'cheats',
      'CHEATS',
      `<p class="menu-note"><strong>HOW TO USE A CHEAT</strong><br>1. While playing, press MENU, then press MENU again (or tap RESUME) within 6 seconds. Nothing is shown: cheats are now armed.<br>2. Within 10 seconds enter the code on the console: push the joystick fully ◀ or ▶ (let go between pushes) and tap FIRE or the grenade button, each tap within about 2 seconds.<br>3. Each cheat needs a fresh arming. Any cheat makes the run practice-only in BOT mode; outside BOT mode the score counts but is marked ✦ on the board.</p>${CHEATS.map(
        (c) =>
          `<div class="cheat-row"><div class="cheat-top"><b>${c.name}</b></div><small>${c.info}</small><div class="cheat-code">${[...c.seq].map((t) => `<i class="code-chip ${t}">${glyph[t]}</i>`).join('')}</div></div>`,
      ).join('')}<p class="menu-note"><strong>FRAME LOG</strong> (per second: fps, longest gap ms, script ms avg/max per frame)<br>${prof.lines.length ? prof.lines.slice(-20).map(esc).join('<br>') : 'none yet'}</p><p class="menu-note"><strong>SLOW FRAMES</strong> (over 70 ms)<br>${slowFrames.length ? slowFrames.slice(-12).map(esc).join('<br>') : 'none yet'}</p><button class="secondary-action" data-action="menu">BACK TO MENU</button>`,
    );
  }
  const slowFrames = [];
  // BOT_ testers only: where each second of play went (milliseconds of script work per frame against the gap between frames).
  const prof = (() => {
    const lines = [], acc = { n: 0, gap: 0, maxGap: 0, step: [0, 0], draw: [0, 0], hud: [0, 0], t: performance.now() };
    const rec = (k, ms) => { acc[k][0] += ms; acc[k][1] = Math.max(acc[k][1], ms); };
    return {
      lines,
      add: rec,
      frame(gap) {
        acc.n++; acc.gap += gap; acc.maxGap = Math.max(acc.maxGap, gap);
        if (performance.now() - acc.t < 1000) return;
        const f = (k) => (acc[k][0] / Math.max(1, acc.n)).toFixed(1) + '/' + acc[k][1].toFixed(0);
        lines.push(`w${game.wave}${game.boss ? ' boss' : ''} ${acc.n}fps gap max ${Math.round(acc.maxGap)} · step ${f('step')} draw ${f('draw')} hud ${f('hud')}`);
        if (lines.length > 40) lines.shift();
        acc.n = acc.gap = acc.maxGap = 0; acc.step = [0, 0]; acc.draw = [0, 0]; acc.hud = [0, 0]; acc.t = performance.now();
      },
    };
  })();
  let coffeeShownFor = null;
  function results(reason, afterCoffee = false) {
    // The coffee screen also appears when a run ends (web version only); the score is saved first.
    if (coffeeOn() && !afterCoffee && !game.practice && coffeeShownFor !== run?.id) {
      coffeeShownFor = run?.id;
      save();
      submitScore();
      showCoffee(() => results(reason, true), false, 'NOT NOW · SEE MY SCORE ▶');
      return;
    }
    showPanel(
      'results',
      game.practice ? 'PRACTICE COMPLETE' : 'RUN COMPLETE',
      `<div style="text-align:center"><p class="menu-note">${esc(run?.name)} · ${esc(reason)}</p><div class="score-result">${game.score.toLocaleString()}</div><div class="result-stats"><span><b>${game.wave}</b>WAVE</span><span><b>${game.kills}</b>KILLS</span><span><b>${game.bossesDown.length}</b>BOSSES</span></div><p class="menu-note" id="scoreStatus">${game.practice ? 'Practice run · not added to the board.' : 'Saving your score…'}</p><button class="primary-action" data-action="retry">ONE MORE RUN</button><button class="secondary-action" data-action="board">HIGH SCORES</button><button class="secondary-action" data-action="home">CHANGE PLAYER NAME</button></div>`,
      { closable: false },
    );
    save();
    submitScore();
  }
  async function submitScore() {
    if (!run || run.submitted) return;
    run.submitted = true;
    const completed = run,
      record = {
        id: run.id,
        name: run.name,
        score: game.score,
        kills: game.kills,
        seconds: game.t,
        wave: game.wave,
        practice: game.practice,
      };
    scores.recordLocal(record);
    save();
    if (run.ticketPromise) await run.ticketPromise;
    const result = await scores.finish({ ...record, ticket: completed.ticket });
    if (run !== completed) return;
    const status = $('scoreStatus');
    if (status)
      status.textContent = {
        practice: 'Practice run · not added to the board.',
        online: 'Score saved to the online leaderboard.',
        pending:
          'Saved on this device. Online upload queued for reconnection' +
          (scores.lastError ? ' (' + scores.lastError + ').' : '.'),
        local:
          'Saved on this device. This run has no online ticket' +
          (scores.lastError ? ' (' + scores.lastError + ').' : '.'),
        rejected:
          'Saved on this device. The online board could not accept this run' +
          (scores.lastError ? ' (' + scores.lastError + ').' : '.'),
      }[result.status];
  }
  // Phone vibration for gunfire, hits, damage and the big boss moments.
  function buzz(type, data) {
    switch (type) {
      case 'shot':
        haptics.impact(
          data.gun === 'shotgun' || data.gun === 'dmr' ? 'MEDIUM' : 'LIGHT',
          'shot',
          data.gun === 'smg' ? 130 : 95,
        );
        break;
      case 'hit':
        haptics.impact('LIGHT', 'hit', data.boss ? 120 : 160);
        break;
      case 'kill':
        haptics.impact('MEDIUM', 'kill', 110);
        break;
      case 'hurt':
        haptics.notify('ERROR', 'hurt', 0);
        break;
      case 'breach':
        zombiePop();
        ledBreach(true);
        haptics.notify('WARNING', 'breach', 0);
        break;
      case 'explosion':
        haptics.impact('HEAVY', 'boom', 60, true);
        break;
      case 'throw':
        haptics.impact('LIGHT', 'throw', 100);
        break;
      case 'pickup':
        haptics.notify('SUCCESS', 'pickup', 80);
        break;
      case 'boost':
        haptics.impact('MEDIUM', 'boost', 150, true);
        break;
      case 'bossAttack':
        haptics.impact('MEDIUM', 'bossAttack', 220, true);
        break;
      case 'entrance':
        haptics.notify('WARNING', 'entrance', 0);
        break;
      case 'panel':
        // Phase 1 of a boss arrival is Joey's shocked face.
        if (data.phase === 1) haptics.shock();
        break;
      case 'mutation':
        if (data.stage === 3) haptics.shock();
        else haptics.impact('HEAVY', 'mutation', 0, true);
        break;
      case 'bossDown':
        haptics.notify('SUCCESS', 'bossDown', 0);
        break;
      case 'death':
        haptics.notify('ERROR', 'death', 0);
        break;
    }
  }
  function event(type, data) {
    if (type === 'bossDown' && game.scene?.bossId && !game.practice) {
      const id = game.scene.bossId,
        had = beatenBosses();
      if (!had.has(id)) {
        had.add(id);
        write('zs7-beaten', [...had]);
        const skin = SKINS.find((x) => x.boss === id);
        if (skin) toast(skin.name + ' skin unlocked · Menu → Console Skins');
      }
    }
    if (type === 'panel' && data.phase === 2 && game.scene?.bossId) audio.playMusic(bossTrack(game.scene.bossId));
    if (type === 'music') {
      audio.playMusic(game.scene?.kind === 'arrival' ? 'entrance' : data.track);
      return;
    }
    const sounds = {
      shot: data.gun,
      kill: 'hit',
      ricochet: 'ricochet',
      boost: 'boost',
      breach: 'hurt',
      clear: 'pickup',
      hurt: 'hurt',
      pickup: 'pickup',
      throw: 'throw',
      explosion: 'grenade',
      entrance: 'alarm',
      panel: 'whoosh',
      mutation: 'alarm',
      bossAttack: 'boss-attack',
      bossDown: 'victory',
      death: 'loss',
    };
    // The new sound set closes a boss fight and a defeat with music stingers instead of the old effects.
    if (type === 'bossDown') audio.afterBoss = true; // later waves use the recorded wave music, not the orchestral synth
    if (audio.synthMode && type === 'bossDown') audio.stinger('victory');
    else if (audio.synthMode && type === 'death') audio.stinger('defeat');
    else if (sounds[type])
      audio.sfx(
        sounds[type],
        type === 'kill' ? 0.55 : type === 'entrance' ? 0.6 : type === 'pickup' ? 0.75 : type === 'clear' ? 0.6 : 1,
      );
    buzz(type, data);
    if (type === 'fight') {
      audio.playMusic(data.id === 'discoman' ? 'disco' : 'boss');
      audio.sfx('doom');
    }
    if (type === 'over') results(data.reason);
    if (type === 'wave') queueSave();
  }
  // Which finished clip (if any) covers the scene that is playing now.
  function sceneClipFor(s) {
    // Warning and Joey's shocked reaction always play first; the boss clip takes over at the reveal.
    if (!s.bossId || (s.kind === 'arrival' && s.phase < 2)) return null;
    const name =
        s.kind === 'arrival'
          ? ((s.startStage || 1) > 1 ? 'form' + s.startStage : 'intro')
          : s.kind === 'mutation'
            ? 'form' + s.stage
            : s.kind === 'down'
              ? 'bossdown'
              : s.kind === 'loss'
                ? 'joeydown'
                : null,
      file = name && sceneClips[s.bossId + '/' + name];
    return file && !failedClips.has(file) ? file : null;
  }
  function unclipBox(box) {
    box.style.bottom = box.style.zIndex = '';
    box.closest('.screen')?.classList.remove('clip-full', 'clip-live');
  }
  function removeSceneClip(box) {
    const v = box.querySelector('video.scene-clip');
    if (!v) return;
    v._dispose?.();
    v.pause();
    v.removeAttribute('src');
    v.load();
    v.remove();
  }
  function mountSceneClip(box, s, file) {
    const v = document.createElement('video');
    const originalDuration = s.duration;
    const phase = s.phase;
    let disposed = false,
      lastProgress = performance.now(),
      lastTime = -1;
    const current = () => !disposed && game.scene === s && s.phase === phase && v.isConnected;
    const restore = () => {
      if (!current()) return;
      failedClips.add(file);
      s.mediaControlled = false;
      s.duration = originalDuration;
      s.time = 0;
      removeSceneClip(box);
      box.classList.remove('clip-mode', 'clip-ready');
      unclipBox(box);
      sceneKey = '';
    };
    v.className = 'scene-clip';
    v.dataset.key = file.replace(/^scene-|\.mp4$/g, '');
    v.muted = true;
    v.playsInline = true;
    v.setAttribute('playsinline', '');
    v.setAttribute('webkit-playsinline', '');
    v.setAttribute('aria-label', 'Boss scene');
    v.preload = 'auto';
    s.mediaControlled = true;
    s.time = 0;
    v.addEventListener('playing', () => {
      if (!current()) return;
      lastProgress = performance.now();
      box.classList.add('clip-ready');
      box.closest('.screen')?.classList.add('clip-live');
    });
    // The film ends on the two close-ups; leaving is a split into the game (also used when FIRE skips the last hold).
    v._endScene = () => {
      if (!current() || v._leaving) return;
      v._leaving = true;
      splitAway(box, () => {
        if (game.scene !== s) return;
        s.mediaControlled = false;
        s.duration = 0.05;
        s.time = 0;
      });
    };
    v.addEventListener('ended', () => v._endScene());
    v.addEventListener('error', restore);
    const watchdog = setInterval(() => {
      if (!current()) return;
      if (paused || document.hidden) {
        lastProgress = performance.now();
        return;
      }
      if (v.currentTime > lastTime + 0.01) {
        lastTime = v.currentTime;
        lastProgress = performance.now();
      }
      if (!v.ended && performance.now() - lastProgress > 4500) restore();
    }, 250);
    v._dispose = () => {
      disposed = true;
      clearInterval(watchdog);
    };
    box.prepend(v);
    box.classList.add('clip-mode');
    v.src = './' + file;
    v.play().catch(() => {
      if (current() && !paused && !document.hidden) restore();
    });
  }
  let sceneIdle = false;
  function cinematic() {
    const s = game.scene,
      box = $('cinematic');
    document.body.classList.toggle('in-scene', !!s);
    if (!s) {
      // Nothing to tidy once the box is already clean: writing the same attributes every frame made the browser
      // re-style the whole game screen 60 times a second.
      if (sceneIdle) return;
      sceneIdle = true;
      box.hidden = true;
      sceneKey = '';
      box.classList.remove('clip-mode', 'clip-ready');

      unclipBox(box);
      removeSceneClip(box);
      return;
    }
    sceneIdle = false;
    const clip = sceneClipFor(s);
    const playing = box.querySelector('video.scene-clip');
    if (playing) {
      if (paused) playing.pause();
      else if (!playing._leaving && !playing.ended && playing.paused && playing.readyState > 2)
        playing.play().catch(() => {});
    }
    const key = [s.kind, s.bossId, s.phase, s.stage].join(':');
    if (sceneKey === key) return;
    removeSceneClip(box);
    sceneKey = key;
    box.hidden = false;
    box.classList.remove('clip-mode', 'clip-ready');
    const b = BOSSES.find((b) => b.id === s.bossId);

    unclipBox(box);
    box.className = s.kind === 'down' ? 'scene-down' : '';
    box.style.setProperty('--scene-color', b?.accent || '#b45139');
    let content = '';
    if (clip) content = '';
    else if (s.kind === 'arrival'  && s.phase === 0)
      content = '<div class="scene-alert">WARNING!<small>HOSTILE APPROACHING</small></div>';
    else if (s.kind === 'mutation') {
      const reaction = s.stage === 3;
      content = `<div class="scene-name long">${esc(b.name)}<span>${reaction ? 'FINAL MUTATION' : 'TRANSFORMATION'}</span></div><div class="scene-figures ${reaction ? 'dual' : ''}">${reaction ? '<img class="scene-art joey" src="./joey-reaction-close.webp" alt="Joey Rob reacts to the final mutation">' : ''}<img class="scene-art" src="./${b.sprites[s.stage - 1]}" alt="${esc(b.name)} form ${s.stage}"></div><div class="scene-copy"><small>${reaction ? 'JOEY ROB' : 'THREAT EVOLVING'}</small><p>${esc(b.stageLines[s.stage - 1] || b.react)}</p></div>`;
    } else if (s.kind === 'arrival' && s.phase === 1)
      content = `<div class="scene-name">JOEY ROB<span>SOMETHING’S COMING…</span></div><div class="scene-figures"><img class="scene-art joey" src="./joey-reaction-close.webp" alt="Joey Rob reacts in shock"></div><div class="scene-copy"><small>JOEY ROB</small><p>${esc(b.announce)}</p></div>`;
    else if (b) {
      const line = s.kind === 'down' ? b.finalLine : s.kind === 'loss' ? b.playerLoss : b.tease;
      content = `<div class="scene-name ${b.name.length > 14 ? 'long' : ''}">${s.kind === 'down' ? 'BOSS DOWN' : esc(b.name)}<span>${esc(b.title)}</span></div><div class="scene-figures"><img class="scene-art" src="./${b.sprites[(s.stage || s.startStage || 1) - 1]}" alt="${esc(b.name)}"></div><div class="scene-copy"><small>${esc(b.name)}</small><p>${esc(line)}</p></div>`;
    } else
      content = '<div class="scene-alert">LINE BROKEN<small>THE HORDE GOT THROUGH</small></div>';
    // While a finished film is mounted the box stays empty: the built-in cards below are only the fallback for a film that fails.
    box.innerHTML = clip ? '' : '<div class="scene-backdrop"></div><div class="scene-lines"></div>' + content;
    box.onclick = (e) => {
      if (!paused && e.target.closest('.scene-next')) sceneAdvance();
    };
    if (clip) mountSceneClip(box, s, clip);
  }

  // A zombie got through: a shaking zombie head pops up over the counter.
  function zombiePop() {
    const box = $('baseStatus');
    if (!box) return;
    box.classList.remove('hit');
    void box.offsetWidth;
    box.classList.add('hit');
    const pop = document.createElement('i');
    pop.className = 'zpop';
    pop.innerHTML = '<svg viewBox="0 0 20 20" aria-hidden="true"><circle cx="10" cy="10" r="9"/><path class="zeye" d="M4.5 7.5l4 1.2M15.5 7.5l-4 1.2"/><circle class="zeye2" cx="7" cy="9.5" r="1.7"/><circle class="zeye2" cx="13" cy="9.5" r="1.7"/><path class="zmouth" d="M5.5 14.5l1.6-1.8 1.6 1.8 1.6-1.8 1.6 1.8 1.6-1.8 1.6 1.8"/></svg>';
    box.appendChild(pop);
    setTimeout(() => pop.remove(), 1000);
  }
  // The HUD only touches the page when a value changes. Writing the same text, class or width every frame
  // forced the phone to restyle (and sometimes re-layout) the whole console 60 times a second.
  const hudCache = Object.create(null),
    hudEl = Object.create(null),
    hel = (id) => hudEl[id] || (hudEl[id] = $(id));
  function hudSet(key, value, apply) {
    if (hudCache[key] === value) return;
    hudCache[key] = value;
    apply(value);
  }
  const hudText = (id, value) => hudSet(id, String(value), (t) => (hel(id).textContent = t));
  let nameCache = '',
    nameAt = -1e9;
  function savedName() {
    const t = performance.now();
    if (t - nameAt > 1000) {
      nameAt = t;
      nameCache = read('zs7-name', '');
    }
    return nameCache;
  }
  const weaponButtons = {};
  // The retro console's joystick art shows one of three positions; the other skins ignore this.
  function stickLamp(dir) {
    hudSet('stickDir', dir, (v) => (hel('joystick').dataset.dir = v));
  }
  // Indicator lamps (cosmetic only). data-led / data-weapon / data-menu on the cabinet are the whole interface:
  // the lamps are drawn in CSS and nothing here touches the simulation, timing, saves or input.
  let breachTimer = 0;
  function ledBreach(on) {
    clearTimeout(breachTimer);
    hel('cabinet').classList.toggle('led-breach', on);
    if (on) window.ZSLedBar?.alert('BREACH ' + Math.min(10, game.breaches) + '/10', 'red');
    if (on) breachTimer = setTimeout(() => ledBreach(false), 1700);
  }
  function leds() {
    const lamps = ZSConsole.leds(game, !awaitStart);
    hudSet('led:power', lamps.power, (v) => {
      hel('cabinet').dataset.led = v;
      if (v === 'off') ledBreach(false);
    });
    hudSet('led:weapon', lamps.weapon, (v) => (hel('cabinet').dataset.weapon = v));
    hudSet('led:paused', paused || document.hidden, (v) => (hel('cabinet').dataset.paused = v ? '1' : ''));
    hudSet('led:menu', paused && !!panel && game.active && !awaitStart, (v) => (hel('cabinet').dataset.menu = v ? '1' : ''));
    {
      const started = game.active && !awaitStart && !game.over,
        boss = game.boss ? ZSData.BOSSES.find((b) => b.id === game.boss.bossId)?.name || '' : '',
        map = started ? MAPS[ZSData.mapIndex(game.wave)].name : '';
      const page = storyActive ? 'story' : panel || (awaitStart ? 'ready' : game.scene ? 'scene' : game.over ? 'over' : started ? 'play' : 'start');
      hudSet('bar', [page, started, game.over, game.wave, map, boss, run?.name || '', page === 'results' ? game.score : '', bot].join('|'), () =>
        window.ZSLedBar?.set({ page, started, over: !!game.over, wave: game.wave, map, boss, name: run?.name || '', score: game.score, bot }),
      );
      hudSet('lowhp', started && game.player.lives === 1, (v) => v && window.ZSLedBar?.alert('LOW HEALTH', 'red'));
      const sp = started && game.player.special && ZSEngine.SPECIALS.find((s) => s.id === game.player.special.id);
      hudSet('spec', sp ? sp.id : '', (v) => v && window.ZSLedBar?.alert(sp.name, 'green'));
    }
  }
  function hud() {
    const p = game.player;
    leds();
    hudSet('sped', (p.speedUp || 0) > 0, (v) => hel('joystick').classList.toggle('sped', v));
    hudText('waveValue', game.wave);
    hudText('leftValue', game.boss ? 'BOSS' : Math.max(0, game.target - game.resolved));
    hudSet('score', game.score, (v) => (hel('scoreValue').textContent = v.toLocaleString()));
    hudSet('best', scores.getBest(run?.name || savedName()), (v) => (hel('bestValue').textContent = v.toLocaleString()));
    {
      const max = game.maxLives || 5,
        l = Math.max(0, p.lives);
      hudSet('hearts', max + ':' + l + ':' + p.lives, () => {
        const el = hel('healthValue');
        el.classList.toggle('tenhearts', max > 5);
        el.dataset.health = max + ':' + l;
        el.innerHTML = Array.from(
          { length: max },
          (_, i) =>
            `<span class="heart${i >= 5 ? ' gold' : ''}${i < l ? '' : ' empty'}">${i < l ? '♥' : '♡'}</span>`,
        ).join('');
        el.setAttribute('aria-label', p.lives + ' hearts');
      });
    }
    const special = p.special && ZSEngine.SPECIALS.find((s) => s.id === p.special.id);
    hudText('gunValue', special ? special.name : ZSEngine.GUNS[p.gun].name);
    hudText('ammoValue', special ? Math.ceil(p.special.left) + 's' : !Number.isFinite(p.ammo) || game.infiniteAmmo ? '∞' : p.ammo);
    {
      const n = Math.min(10, game.breaches);
      hudSet('breach', n, () => {
        const el = hel('baseValue');
        el.dataset.n = n;
        el.setAttribute('aria-label', n + ' of 10 zombies through');
        el.innerHTML = Array.from(
          { length: 10 },
          (_, i) => `<svg class="zface${i < n ? ' lit' : ''}" viewBox="0 0 20 20" aria-hidden="true"><circle cx="10" cy="10" r="9"/><path class="zeye" d="M4.5 7.5l4 1.2M15.5 7.5l-4 1.2"/><circle class="zeye2" cx="7" cy="9.5" r="1.7"/><circle class="zeye2" cx="13" cy="9.5" r="1.7"/><path class="zmouth" d="M5.5 14.5l1.6-1.8 1.6 1.8 1.6-1.8 1.6 1.8 1.6-1.8 1.6 1.8"/></svg>`,
        ).join('');
      });
    }
    hudSet('grenades', p.grenades, (v) => {
      hel('grenadeValue').textContent = v;
      window.ZSLedBar?.grenades(v);
      hel('grenadeButton').classList.toggle('empty', v === 0);
      hel('grenadeButton').setAttribute('aria-label', 'Throw grenade, ' + v + ' remaining');
    });
    hudText('boostText', 'BOOST ×' + game.multiplier);
    hudSet('boostFill', Math.round(Math.max(0, game.comboLeft / 7) * 200) / 2, (v) => (hel('boostFill').style.width = v + '%'));
    hudText(
      'comboText',
      game.combo >= 30
        ? '×10 · KEEP IT GOING'
        : (game.combo < 10 ? 10 : game.combo < 20 ? 20 : 30) -
            game.combo +
            ' KILLS TO ×' +
            (game.combo < 10 ? 2 : game.combo < 20 ? 4 : 10),
    );
    for (const gun of ['smg', 'shotgun', 'dmr', 'burst']) {
      const active = p.gun === gun,
        ammo = active ? p.ammo : p.inventory?.[gun] || 0;
      hudSet('w:' + gun, active + ':' + ammo, () => {
        const el = $('inv-' + gun);
        if (el) el.textContent = ammo || '—';
        const btn = weaponButtons[gun] || (weaponButtons[gun] = document.querySelector(`[data-weapon="${gun}"]`));
        if (btn) {
          btn.disabled = active || !(ammo > 0);
          btn.classList.toggle('ready', ammo > 0);
          btn.classList.toggle('equipped', active);
          btn.setAttribute(
            'aria-label',
            `${active ? 'Equipped' : 'Use'} ${ZSEngine.GUNS[gun].name}, ${ammo} rounds`,
          );
        }
      });
    }
    const mapName = MAPS[ZSData.mapIndex(game.wave)].name;
    hudSet('map', mapName, (v) => (hel('mapLabel').textContent = hel('mapTag').textContent = v));
    hudText('headerName', run?.name || 'JOEY ROB VS DR MANTIS');
  }
  function inputs() {
    let axis =
        touchAxis +
        (keys.has('ArrowRight') || keys.has('KeyD') ? 1 : 0) -
        (keys.has('ArrowLeft') || keys.has('KeyA') ? 1 : 0),
      fire = touchFire || keys.has('Space'),
      grenade = false;
    stick.classList.toggle('push-l', axis < -0.15);
    stick.classList.toggle('push-r', axis > 0.15);
    try {
      const pad = padOn ? Array.from(navigator.getGamepads?.() || []).find(Boolean) : null;
      if (pad) {
        if (Math.abs(pad.axes[0] || 0) > 0.14) axis = pad.axes[0];
        if (pad.buttons[14]?.pressed) axis = -1;
        if (pad.buttons[15]?.pressed) axis = 1;
        fire ||= !!(pad.buttons[0]?.pressed || pad.buttons[7]?.pressed);
        grenade = !!pad.buttons[1]?.pressed;
        if (grenade && !padGrenade) game.grenade();
      }
    } catch {}
    if (stickId !== null && performance.now() < flickUntil && Math.sign(axis) !== -flickDir)
      axis = flickDir;
    padGrenade = grenade;
    trackStick(axis);
    game.setInput(axis, fire);
  }
  function fit() {
    const root = document.documentElement,
      focused = /INPUT|TEXTAREA/.test(document.activeElement?.tagName || ''),
      vv = visualViewport,
      w = Math.max(1, root.clientWidth || innerWidth),
      h = Math.max(1, root.clientHeight || innerHeight),
      keyboard = focused && vv && vv.height < innerHeight * 0.78,
      newLandscape = w > h * 1.04;
    landscape = newLandscape;
    if ($('rotateGate').hidden === landscape) $('rotateGate').hidden = !landscape;
    if (landscape) {
      if (game.active && !paused) {
        pause();
        menu();
      }
      return;
    }
    if (keyboard) return;
    const safe = getComputedStyle(document.documentElement),
      top =
        parseFloat(safe.getPropertyValue('--safe-top')) ||
        0 ||
        (navigator.standalone === true ? 20 : 0),
      bottom = parseFloat(safe.getPropertyValue('--safe-bottom')) || 0,
      usableHeight = Math.max(1, h - top - bottom),
      scale = Math.min(w / 375, usableHeight / 667),
      T = top + (usableHeight - 667 * scale) / 2,
      shift = 0,
      key = w + 'x' + h + '@' + scale.toFixed(4) + '/' + top + '/' + bottom;
    if (key === lastFit) return;
    lastFit = key;
    document.documentElement.style.setProperty('--console-scale', scale);
    document.documentElement.style.setProperty('--hs', shift.toFixed(1) + 'px');
    document.body.classList.toggle('sb-overlap', shift > 6);
    $('cabinet').style.left = w / 2 + 'px';
    $('cabinet').style.top = T + 333.5 * scale + 'px';
    renderer.resize();
  }
  let lastDraw = -Infinity, lastHud = -Infinity;
  function frame(now) {
    if (fitDirty) {
      fitDirty = false;
      fit();
    }
    if (storyActive || awaitStart || panel === 'start') padWatch();
    const elapsed = now - lastTime;
    // BOT_ testers: remember the last slow frames (over 70 ms) and what was happening, shown in the CHEATS page.
    if (bot && elapsed > 70 && elapsed < 2000 && !paused && game.active)
      slowFrames.push(Math.round(elapsed) + 'ms · wave ' + game.wave + (game.scene ? ' · ' + game.scene.kind + ' scene' : game.boss ? ' · boss' : '') + ' · ' + game.enemies.length + ' zombies');
    if (slowFrames.length > 40) slowFrames.shift();
    if (bot && !paused && game.active) prof.frame(elapsed);
    const dt = Math.min(0.1, elapsed / 1000 || 0);
    renderer.observeFrame(elapsed, !paused && !landscape && !document.hidden && ready && !game.scene);
    lastTime = now;
    if (!paused && !landscape && !document.hidden && ready) {
      inputs();
      accumulator += dt;
      let steps = 0;
      const tStep = bot ? performance.now() : 0;
      while (accumulator >= 1 / 60 && steps++ < 6) {
        game.step(1 / 60);
        accumulator -= 1 / 60;
      }
      if (bot) prof.add('step', performance.now() - tStep);
      saveClock += dt;
      if (saveClock > 5) {
        saveClock = 0;
        queueSave();
      }
    } else accumulator = 0;
    if (!document.hidden) {
      // Keep controls and simulation at full rate; avoid drawing a static menu or the same 60 Hz pose at 120 Hz.
      const interval = paused || game.scene ? 1000 / 15 : 1000 / 60;
      if (now - lastDraw >= interval - 0.5) {
        const tDraw = bot ? performance.now() : 0;
        renderer.draw(game);
        if (bot) prof.add('draw', performance.now() - tDraw);
        lastDraw = now - ((now - (Number.isFinite(lastDraw) ? lastDraw : now)) % interval);
      }
      cinematic();
      if (now - lastHud >= 1000 / 30) {
        const tHud = bot ? performance.now() : 0;
        hud();
        if (bot) prof.add('hud', performance.now() - tHud);
        lastHud = now;
      }
    }
    requestAnimationFrame(frame);
  }
  // iOS toolbars and the keyboard can change the size without a resize event: re-measure twice a second.
  setInterval(() => (fitDirty = true), 500);
  let flickDir = 0,
    flickUntil = 0,
    stickHist = [],
    stickVal = 0;
  const stick = $('joystick');
  // Floating stick: wherever the thumb lands on the pad becomes the centre; only dragging sideways steers.
  // Past full deflection the centre follows the thumb so reversing is instant, and a quick flick gives a short full-speed burst.
  function moveStick(e) {
    if (e.pointerId !== stickId || stickOrigin === null) return;
    const range = stick.getBoundingClientRect().width * 0.16,
      list = e.getCoalescedEvents?.().length ? e.getCoalescedEvents() : [e];
    for (const ev of list) {
      let dx = ev.clientX - stickOrigin;
      if (dx > range) {
        stickOrigin += dx - range;
        dx = range;
      } else if (dx < -range) {
        stickOrigin += dx + range;
        dx = -range;
      }
      const now = performance.now();
      stickHist.push([now, ev.clientX]);
      while (stickHist.length > 1 && now - stickHist[0][0] > 150) stickHist.shift();
      stickVal = dx / range;
      const a = Math.abs(stickVal);
      touchAxis = a < 0.1 ? 0 : Math.sign(stickVal) * Math.pow((a - 0.1) / 0.9, 0.8);
      const moved = ev.clientX - stickHist[0][1];
      if (Math.abs(moved) > range * 0.4) {
        flickDir = Math.sign(moved);
        flickUntil = now + 170;
      }
    }
    $('stickKnob').style.transform = `translateX(${stickVal * 25}px)`;
    stick.style.setProperty('--lean', stickVal.toFixed(2));
    stickLamp(stickVal < -0.3 ? -1 : stickVal > 0.3 ? 1 : 0);
    stick.setAttribute('aria-valuenow', Math.round(touchAxis * 100));
  }
  stick.addEventListener('pointerdown', (e) => {
    if (e.button !== 0 || stickId !== null) return;
    if (awaitStart || storyActive) {
      e.preventDefault();
      startNow();
      return;
    }
    if (paused || !game.active || game.scene) return;
    e.preventDefault();
    stickId = e.pointerId;
    stickOrigin = e.clientX;
    stickHist = [[performance.now(), e.clientX]];
    stickVal = 0;
    touchAxis = 0;
    stick.setPointerCapture(e.pointerId);
    audio.unlock();
  });
  stick.addEventListener('pointermove', moveStick);
  function releaseStick() {
    stickId = null;
    stickOrigin = null;
    flickUntil = 0;
    touchAxis = 0;
    stickVal = 0;
    $('stickKnob').style.transform = 'translateX(0)';
    stick.style.setProperty('--lean', '0');
    stick.setAttribute('aria-valuenow', '0');
    stickLamp(0);
  }
  function releaseFire() {
    touchFire = false;
    fireId = null;
    $('fireButton').classList.remove('pressed');
  }
  for (const type of ['pointerup', 'pointercancel', 'lostpointercapture'])
    stick.addEventListener(type, (e) => {
      if (e.pointerId === stickId) releaseStick();
    });
  // iPhone can swallow a finger-up (edge swipes, banners, calls). Never leave the stick or FIRE held:
  // release on any window-level lift/cancel, when no finger is left on the screen, and when the app loses focus.
  for (const type of ['pointerup', 'pointercancel'])
    addEventListener(type, (e) => {
      if (e.pointerId === stickId) releaseStick();
      if (e.pointerId === fireId) releaseFire();
    }, true);
  for (const type of ['touchend', 'touchcancel'])
    addEventListener(type, (e) => {
      if (e.touches.length === 0) {
        if (stickId !== null) releaseStick();
        if (fireId !== null) releaseFire();
      }
    }, true);
  addEventListener('blur', () => {
    if (stickId !== null) releaseStick();
    if (fireId !== null) releaseFire();
  });
  $('fireButton').addEventListener('pointerdown', (e) => {
    if (e.button !== 0 || fireId !== null) return;
    if (panel === 'start') {
      e.preventDefault();
      showPlayer();
      return;
    }
    if (storyActive) {
      e.preventDefault();
      storySkip();
      return;
    }
    if (awaitStart) {
      e.preventDefault();
      startNow();
      return;
    }
    feedToken('F');
    if (!paused) haptics.impact('MEDIUM', 'press', 0, true);
    if (paused || !game.active) return;
    e.preventDefault();
    fireId = e.pointerId;
    e.currentTarget.setPointerCapture(e.pointerId);
    touchFire = true;
    e.currentTarget.classList.add('pressed');
    audio.unlock();
    // During a boss scene a press (or holding FIRE) skips ahead once the scene has run for a couple of seconds.
    if (game.scene) {
      if (game.scene.bossId && game.scene.time >= 0.4) sceneAdvance();
      return;
    }
    game.fire();
  });
  for (const type of ['pointerup', 'pointercancel', 'lostpointercapture'])
    $('fireButton').addEventListener(type, (e) => {
      if (e.pointerId === fireId) {
        touchFire = false;
        fireId = null;
        e.currentTarget.classList.remove('pressed');
      }
    });
  $('grenadeButton').addEventListener('pointerdown', (e) => {
    if (storyActive) return;
    if (awaitStart) {
      e.preventDefault();
      startNow();
      return;
    }
    feedToken('G');
    if (paused) return;
    // A firm press when a grenade is thrown, a light tick when the pouch is empty.
    haptics.impact(game.player.grenades > 0 ? 'MEDIUM' : 'LIGHT', 'press', 0, true);
    e.preventDefault();
    audio.unlock();
    game.grenade();
  });
  // Stored-weapon buttons react to the first touch. A 'click' is not sent on iPhone while another finger
  // is held on the joystick, which made guns selectable only after letting go.
  function equipStored(weapon) {
    if (paused || !game.useStored(weapon)) return;
    audio.sfx('pickup');
    haptics.impact('MEDIUM', 'weapon', 0, true);
    toast(ZSEngine.GUNS[weapon].name + ' equipped');
  }
  $('weaponRack').addEventListener('pointerdown', (e) => {
    if (awaitStart) {
      e.preventDefault();
      startNow();
      return;
    }
    const b = e.target.closest('[data-weapon]');
    if (!b || b.disabled) return;
    e.preventDefault();
    audio.unlock();
    equipStored(b.dataset.weapon);
  });
  $('weaponRack').addEventListener('click', (e) => {
    const b = e.target.closest('[data-weapon]');
    if (b && e.detail === 0) equipStored(b.dataset.weapon); // keyboard / assistive technology
  });
  // One MENU button: it pauses the game and opens the menu (press again to resume).
  // pointerdown, not click, so it also works while a thumb is already on the joystick.
  const menuButton = $('menuButton');
  let menuDownAt = 0;
  menuButton.addEventListener('pointerdown', (e) => {
    e.preventDefault();
    menuDownAt = performance.now();
    // A name box still holding the keyboard would swallow the first tap on a phone.
    if (document.activeElement?.blur && /INPUT|TEXTAREA/.test(document.activeElement.tagName))
      document.activeElement.blur();
    // MENU works on every screen. It does not count as "any button" for starting the game.
    if (storyActive && panel === 'story') {
      storyVideo?.pause();
      clearTimeout(storyTimer);
    }
    menuButton.classList.add('pressed');
    audio.unlock();
    haptics.impact('LIGHT', 'ui', 0, true);
    menu();
  });
  for (const type of ['pointerup', 'pointercancel', 'pointerleave'])
    menuButton.addEventListener(type, () => menuButton.classList.remove('pressed'));
  menuButton.addEventListener('click', (e) => {
    // Keyboard / assistive technology only: a tap already opened the menu on pointerdown.
    if (e.detail === 0 && performance.now() - menuDownAt > 800) menu();
  });
  addEventListener('keydown', (e) => {
    if (/INPUT|TEXTAREA/.test(e.target.tagName)) return;
    if (panel === 'start') {
      if (e.code === 'Space' || e.code === 'Enter') {
        e.preventDefault();
        if (!e.repeat) showPlayer();
      }
      return;
    }
    if (storyActive) {
      if (e.code === 'Space' || e.code === 'Enter') {
        e.preventDefault();
        if (!e.repeat) storySkip();
      }
      return;
    }
    if (awaitStart) {
      e.preventDefault();
      if (!e.repeat) startNow();
      return;
    }
    if (
      ['ArrowLeft', 'ArrowRight', 'Space', 'KeyA', 'KeyD', 'KeyG', 'KeyP', 'Escape'].includes(
        e.code,
      )
    )
      e.preventDefault();
    if (e.code === 'Escape' || e.code === 'KeyP') {
      if (!e.repeat) {
        if (panel && game.active) closePanel();
        else menu();
      }
      return;
    }
    if (paused) return;
    keys.add(e.code);
    if (e.code === 'Space' && !e.repeat) {
      feedToken('F');
      audio.unlock();
      game.fire();
    }
    if (e.code === 'KeyG' && !e.repeat) {
      feedToken('G');
      game.grenade();
    }
  });
  addEventListener('keyup', (e) => keys.delete(e.code));
  $('overlay').addEventListener('keydown', (e) => {
    if (e.key !== 'Tab') return;
    const nodes = [...$('overlay').querySelectorAll('button:not(:disabled),input,a[href]')];
    if (!nodes.length) return;
    const first = nodes[0],
      last = nodes.at(-1);
    if (e.shiftKey && document.activeElement === first) {
      e.preventDefault();
      last.focus();
    } else if (!e.shiftKey && document.activeElement === last) {
      e.preventDefault();
      first.focus();
    }
  });
  $('overlay').addEventListener('submit', async (e) => {
    e.preventDefault();
    if (e.target.id === 'playerForm') {
      if (ready) start($('username').value);
    }
  });
  // Every menu button, skin tile and switch gives a light tap.
  $('overlay').addEventListener('pointerdown', (e) => {
    const b = e.target.closest('button:not(:disabled)');
    if (b) haptics.impact('LIGHT', 'ui', 0, true);
    if (storyActive && storyVideo?.paused) storyVideo.play().catch(() => {});
  });
  $('overlay').addEventListener('change', (e) => {
    if (e.target.type === 'checkbox') haptics.impact('LIGHT', 'ui', 0, true);
  });
  $('overlay').addEventListener('input', (e) => {
    const kind = e.target.dataset.volume;
    if (kind) audio.set(kind, e.target.value / 100);
  });
  $('overlay').addEventListener('change', (e) => {
    if (e.target.hasAttribute('data-haptics')) {
      haptics.set(e.target.checked);
      return;
    }
  });
  $('overlay').addEventListener('click', async (e) => {
    const button = e.target.closest('button');
    if (!button) return;
    if (button.dataset.preview) {
      previewSkin(button.dataset.preview);
      document.querySelectorAll('.skin-choice').forEach((b) => {
        b.classList.toggle('previewing', b.dataset.preview === button.dataset.preview);
      });
      return;
    }
    if (button.dataset.skin) {
      applySkin(button.dataset.skin);
      document.querySelectorAll('[data-skin]').forEach((b) => {
        const selected = b.dataset.skin === button.dataset.skin;
        b.classList.toggle('selected', selected);
        b.setAttribute('aria-pressed', selected);
      });
      return;
    }
    switch (button.dataset.action) {
      case 'player':
        showPlayer();
        break;
      case 'home':
        showStart();
        break;
      case 'name-change': {
        const box = $('username');
        if (box) {
          box.readOnly = false;
          box.focus();
          box.select();
        }
        button.disabled = true;
        break;
      }
      case 'close':
        closePanel();
        break;
      case 'home':
        showStart();
        break;
      case 'menu':
        menu();
        break;
      case 'skins':
        skins();
        break;
      case 'skins-char':
        skins('char');
        break;
      case 'skins-custom':
        skins('custom');
        break;
      case 'coffee':
        showCoffee(menu, true);
        break;
      case 'coffee-skip': {
        const go = coffeeNext;
        coffeeNext = null;
        go?.();
        break;
      }
      case 'board':
        board();
        break;
      case 'sound':
        sound();
        break;
      case 'privacy':
        privacyPanel();
        break;
      case 'help':
        help();
        break;
      case 'cheats':
        if (bot) cheatsPanel();
        break;
      case 'install':
        if (!nativeApp) install();
        break;
      case 'restart':
        showPanel(
          'restart',
          'START A NEW RUN?',
          `<p class="menu-note">Your current run will end without submitting its score.</p><button class="primary-action" data-action="newgame-go">START A NEW GAME</button><button class="secondary-action" data-action="home">CHOOSE A DIFFERENT PLAYER</button><button class="secondary-action" data-action="close">KEEP PLAYING</button>`,
        );
        break;
      case 'newgame-go':
        if (run?.name) start((run.bot ? 'BOT_' : '') + run.name, true);
        else showStart();
        break;
      case 'retry':
        start((run.bot ? 'BOT_' : '') + run.name, true);
        break;
      case 'story':
        storyReplay = true;
        showStory(parseName(read('zs7-name', 'Player')).name || 'Player', 0);
        break;
      case 'continue':
        {
          const saved = read('zs7-run', null);
          if (!ready) return;
          if (saved?.run && typeof saved.run.name === 'string' &&
              typeof saved.run.id === 'string' && game.restore(saved.engine)) {
            run = saved.run;
            bot = !!run.bot;
            sceneKey = '';
            closePanel();
          } else {
            try { localStorage.removeItem('zs7-run'); } catch {}
            showStart();
            toast('That saved run could not be restored. Start a new game; your best scores are kept.');
          }
        }
        break;
      case 'fix-sound': {
        audio.reset();
        toast('Audio reset · playing a test sound');
        setTimeout(() => audio.sfx('pickup'), 350);
        break;
      }
      case 'preview-sound': {
        const preview = ++soundPreview;
        audio.resume();
        audio.playMusic('main');
        ['pistol', 'hit', 'shotgun', 'grenade', 'pickup'].forEach((n, i) =>
          setTimeout(
            () => {
              if (preview === soundPreview && panel === 'sound') audio.sfx(n);
            },
            500 + i * 650,
          ),
        );
        haptics.impact('MEDIUM', 'preview', 0, true);
        setTimeout(() => {
          if (preview === soundPreview && paused) audio.pause();
        }, 5000);
        break;
      }
      case 'install-now':
        if (installPrompt) {
          await installPrompt.prompt();
          installPrompt = null;
          install();
        }
        break;
    }
  });
  addEventListener('resize', () => {
    lastFit = '';
    fitDirty = true;
  });
  visualViewport?.addEventListener('resize', () => {
    lastFit = '';
    fitDirty = true;
  });
  screen.orientation?.addEventListener('change', () => {
    lastFit = '';
    fitDirty = true;
  });
  addEventListener('blur', () => {
    clearInput();
    if (game.active && !panel && !awaitStart) {
      pause();
      menu();
    }
  });
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
      pause(true);
      storyVideo?.pause();
      if (game.active && !panel && !awaitStart) menu();
    } else {
      audio.revive();
      if (storyActive) {
        audio.resume();
        storyVideo?.play().catch(() => {});
      }
    }
  });
  for (const ev of ['pageshow', 'focus']) addEventListener(ev, () => audio.revive());
  // iOS can silently interrupt audio mid-game (calls, alerts, Siri): check often and bring it back.
  setInterval(() => {
    if (!document.hidden && audio.ctx && audio.ctx.state !== 'running') audio.revive();
    // Music watchdog: while the game is running, the music must be playing. Restart it if it somehow is not.
    else if (!document.hidden && game.active && !game.over && !paused && !awaitStart && !panel && audio.ctx && !audio.paused && audio.wantTrack && audio.wantTrack !== 'entrance' && !audio.seq && !audio.music && !audio.holdTrack) {
      audio.track = null;
      audio.playMusic(audio.wantTrack);
    }
  }, 2500);
  for (const ev of ['pointerdown', 'touchend'])
    document.addEventListener(ev, () => audio.revive(true), { capture: true, passive: true });
  addEventListener('pagehide', save);
  document.addEventListener('contextmenu', (e) => {
    if (!e.target.closest?.('input,textarea')) e.preventDefault();
  });
  addEventListener('beforeinstallprompt', (e) => {
    e.preventDefault();
    installPrompt = e;
  });
  // Move the former default to the new standard once; preserve other chosen skins.
  if (!read('zs7-retro-default', false)) {
    if (read('zs7-skin', 'toxic-pop') === 'toxic-pop') write('zs7-skin', 'retro-handheld');
    write('zs7-retro-default', true);
  }
  ZSConsole.apply();
  applySkin(read('zs7-skin', 'retro-handheld'));
  fetch('./skins-extra.json')
    .then((r) => r.json())
    .then((j) => {
      let added = 0;
      for (const s of j.skins || [])
        if (
          s?.id &&
          s.file &&
          Array.isArray(s.win) &&
          s.win.length === 4 &&
          !SKINS.some((x) => x.id === s.id)
        ) {
          s.group = 'character';
          s.deck3d = true; // illustrated 3D decks get the 3D controls (the build regenerates this file)
          if (s.id !== 'joeyrob') s.boss = s.id;
          SKINS.push(s);
          added++;
        }
      if (added) applySkin(read('zs7-skin', 'retro-handheld'));
    })
    .catch(() => {});
  showStart();
  requestAnimationFrame(frame);
  renderer
    .load((fraction) => {
      const line = $('loadingLine');
      if (line) line.textContent = 'Loading game artwork · ' + Math.round(fraction * 100) + '%';
    })
    .then(() => {
      ready = true;
      if (panel === 'start') $('loadingLine').textContent = '';
      if (panel === 'player' && $('newGameBtn')) $('newGameBtn').disabled = false;
      renderer.draw(game);
    })
    .catch((error) => {
      const line = $('loadingLine');
      if (line) line.textContent = 'Artwork download interrupted. Reload to retry.';
      toast(error.message);
    });
  scores.flush();
  if ('serviceWorker' in navigator) {
    const hadController = !!navigator.serviceWorker.controller;
    navigator.serviceWorker.addEventListener('controllerchange', () => {
      if (!hadController) return;
      pendingReload = true;
      reloadWhenSafe();
    });
    navigator.serviceWorker
      .register('./sw.js', { updateViaCache: 'none' })
      .then((reg) => {
        reg.update().catch(() => {});
        document.addEventListener('visibilitychange', () => {
          if (document.hidden) reloadWhenSafe();
          else reg.update().catch(() => {});
        });
        setInterval(() => reg.update().catch(() => {}), 600000);
        return navigator.serviceWorker.ready;
      })
      .then(() =>
        navigator.serviceWorker.controller?.postMessage({
          type: 'CACHE_STATUS',
        }),
      )
      .catch(() => {});
    navigator.serviceWorker.addEventListener('message', (e) => {
      if (e.data?.type === 'OFFLINE_READY') {
        write('zs7-offline-ready', true);
        if ($('offlineStatus'))
          $('offlineStatus').textContent = 'Game download complete · offline play ready.';
      }
    });
  }
  {
    const intro = $('studioIntro');
    if (intro) {
      const done = () => intro.remove();
      intro.addEventListener('pointerdown', (e) => { e.stopPropagation(); done(); });
      setTimeout(done, 3800);
    }
  }
  window.ZSLedBar?.init();
  window.ZSInspect = () => ({
    world: { width: ZSData.W, height: ZSData.H },
    player: { x: game.player.x, y: game.player.y },
    wave: game.wave,
    score: game.score,
    kills: game.kills,
    bullets: game.bullets.length,
    shots: game.shots.length,
    grenades: game.player.grenades,
    paused,
    landscape,
    scene: game.scene?.kind,
    scenePhase: game.scene?.phase,
    boss: game.boss?.bossId,
    stage: game.boss?.stage,
    practice: game.practice,
    active: game.active,
    over: game.over,
    panel,
    ready,
  });
})();
