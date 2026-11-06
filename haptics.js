/* Phone vibration feedback. In the iPhone app this uses the Capacitor Haptics plugin (Taptic Engine);
   on the web it falls back to the Vibration API where the browser has one. */
(() => {
  'use strict';
  class Haptics {
    constructor() {
      this.on = true;
      try {
        this.on = JSON.parse(localStorage.getItem('zs7-haptics')) !== false;
      } catch {}
      this.last = {};
      this.lastAny = 0;
      this.plugin = null;
    }
    get native() {
      return !!window.Capacitor?.isNativePlatform?.();
    }
    set(on) {
      this.on = !!on;
      try {
        localStorage.setItem('zs7-haptics', JSON.stringify(this.on));
      } catch {}
      if (this.on) this.impact('MEDIUM', 'preview', 0, true);
    }
    call(method, options) {
      try {
        if (this.native) {
          const cap = window.Capacitor;
          this.plugin ||= cap.Plugins?.Haptics || cap.registerPlugin?.('Haptics');
          this.plugin?.[method]?.(options)?.catch?.(() => {});
        } else if (navigator.vibrate) {
          navigator.vibrate(
            method === 'notification'
              ? [30, 40, 30]
              : options.style === 'HEAVY'
                ? 35
                : options.style === 'MEDIUM'
                  ? 20
                  : 10,
          );
        }
      } catch {}
    }
    // gap = minimum milliseconds between two buzzes of the same kind, so rapid fire stays a soft patter.
    gate(kind, gap, force) {
      const now = performance.now();
      if (!this.on || now - (this.last[kind] || 0) < gap || (!force && now - this.lastAny < 55))
        return false;
      this.last[kind] = this.lastAny = now;
      return true;
    }
    // force = important moments (damage, explosions, bosses) that must never be skipped.
    impact(style = 'MEDIUM', kind = style, gap = 40, force = false) {
      if (this.gate(kind, gap, force)) this.call('impact', { style });
    }
    notify(type = 'SUCCESS', kind = type, gap = 120, force = true) {
      if (this.gate(kind, gap, force)) this.call('notification', { type });
    }
    // Two thumps a beat apart: Joey's shocked face.
    shock() {
      if (!this.on) return;
      this.impact('HEAVY', 'shock', 0, true);
      setTimeout(() => this.impact('MEDIUM', 'shock2', 0, true), 120);
    }
  }
  window.ZSHaptics = Haptics;
})();
