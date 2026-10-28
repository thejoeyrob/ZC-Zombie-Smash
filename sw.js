const CACHE = 'zombie-smash-v7.56.0';
const ASSETS = [
  './console-retro-handheld.webp',
  './retro-stick.png',
  './retro-fire.png',
  './retro-grenade.png',
  './retro-menu.png',
  './retro-led-power.png',
  './retro-led-weapon.png',
  './console-toxic-pop.webp',
  './console-disco-fever.webp',
  './console-pocket-arcade.webp',
  './404.html',
  './apple-touch-icon.png',
  './art-bounds.json',
  './audio.js',
  './boss-caffeinatedsloth-stage1.webp',
  './boss-caffeinatedsloth-stage2.webp',
  './boss-debo-stage1.webp',
  './boss-debo-stage2.webp',
  './boss-discoman-stage1.webp',
  './boss-discoman-stage2.webp',
  './boss-drmantis-stage1.webp',
  './boss-drmantis-stage2.webp',
  './boss-drmantis-stage3.webp',
  './boss-fatamy-stage1.webp',
  './boss-fatamy-stage2.webp',
  './boss-fatamy-stage3.webp',
  './boss-glowinghumanity-stage1.webp',
  './boss-glowinghumanity-stage2.webp',
  './boss-jordan-stage1.webp',
  './boss-jordan-stage2.webp',
  './bullet-dmr.webp',
  './bullet-pistol.webp',
  './bullet-smg.webp',
  './console-arctic.webp',
  './console-carbon.webp',
  './console-circuit.webp',
  './console-electro.webp',
  './console-ember.webp',
  './console-hazard.webp',
  './console-layout.js',
  './console-neon.webp',
  './console-rustyard.webp',
  './console-splatter.webp',
  './console-toxic.webp',
  './console-void.webp',
  './console-warzone.webp',
  './engine.js',
  './font-barlow-condensed-700.woff2',
  './font-barlow-condensed-900.woff2',
  './font-inter.woff2',
  './game-banner.webp',
  './game-data.js',
  './game.css',
  './game.js',
  './haptics.js',
  './icon-192.png',
  './icon-512.png',
  './icon-maskable-512.png',
  './index.html',
  './joey-reaction-close.webp',
  './manifest.webmanifest',
  './title-bg.webp',
  './story-joey.webp',
  './story-army.webp',
  './intro-jw.png',
  './led-display.js',

  './map-concrete.jpg',
  './music-main.mp3',
  './arc-boss.mp3',
  './arc-main.mp3',
  './arc-entrance.mp3',
  './arc-disco.mp3',
  './arc-victory.mp3',
  './arc-victory-d.mp3',
  './arc-defeat.mp3',
  './arc-defeat-d.mp3',
  './new-pickup.mp3',
  './pickup-bomb.webp',
  './pickup-clock.webp',
  './pickup-dmr.webp',
  './pickup-heart.webp',
  './pickup-shield.webp',
  './pickup-smg.webp',
  './pickup-speed.webp',
  './player-fire.webp',
  './player-hit.webp',
  './player-portrait.webp',
  './player-transparent.webp',
  './player-victory.webp',
  './player-wounded.webp',
  './prop-barrel.webp',
  './renderer.js',
  './scores.js',
  './sfx-alarm.mp3',
  './sfx-boost.mp3',
  './sfx-boss-attack.mp3',
  './sfx-burst.mp3',
  './sfx-dmr.mp3',
  './sfx-grenade.mp3',
  './sfx-hit.mp3',
  './sfx-hurt.mp3',
  './sfx-loss.mp3',
  './sfx-pistol.mp3',
  './sfx-ricochet.mp3',
  './sfx-shotgun.mp3',
  './sfx-smg.mp3',
  './sfx-throw.mp3',
  './sfx-victory.mp3',
  './sfx-whoosh.mp3',
  './arena-caffeinatedsloth.webp',
  './arena-debo.webp',
  './arena-discoman.webp',
  './arena-drmantis.webp',
  './arena-fatamy.webp',
  './arena-glowinghumanity.webp',
  './arena-jordan.webp',
  './scene-clips.json',
  './scene-beats.json',
  './skins-extra.json',
  './scene-jordan-intro.mp4',
  './scene-jordan-form2.mp4',
  './scene-jordan-bossdown.mp4',
  './scene-jordan-joeydown.mp4',
  './scene-glowinghumanity-intro.mp4',
  './scene-glowinghumanity-form2.mp4',
  './scene-glowinghumanity-bossdown.mp4',
  './scene-glowinghumanity-joeydown.mp4',
  './scene-debo-intro.mp4',
  './scene-debo-form2.mp4',
  './scene-debo-bossdown.mp4',
  './scene-debo-joeydown.mp4',
  './scene-caffeinatedsloth-intro.mp4',
  './scene-caffeinatedsloth-form2.mp4',
  './scene-caffeinatedsloth-bossdown.mp4',
  './scene-caffeinatedsloth-joeydown.mp4',
  './scene-discoman-intro.mp4',
  './scene-discoman-form2.mp4',
  './scene-discoman-bossdown.mp4',
  './scene-discoman-joeydown.mp4',
  './scene-fatamy-intro.mp4',
  './scene-fatamy-form2.mp4',
  './scene-fatamy-form3.mp4',
  './scene-fatamy-bossdown.mp4',
  './scene-fatamy-joeydown.mp4',
  './scene-drmantis-intro.mp4',
  './scene-drmantis-form2.mp4',
  './scene-drmantis-form3.mp4',
  './scene-drmantis-bossdown.mp4',
  './scene-drmantis-joeydown.mp4',
  './console-joeyrob.webp',
  './console-jordan.webp',
  './console-glowinghumanity.webp',
  './console-debo.webp',
  './console-caffeinatedsloth.webp',
  './console-discoman.webp',
  './console-fatamy.webp',
  './console-drmantis.webp',
  './story-1.mp4',
  './story-2.mp4',
  './story-3.mp4',
  './weapon-bodypart.webp',
  './weapon-burger.webp',
  './weapon-chain.webp',
  './weapon-coffee.webp',
  './weapon-disco.webp',
  './weapon-donut.webp',
  './weapon-ember.webp',
  './weapon-glowstick-blue.webp',
  './weapon-glowstick-green.webp',
  './weapon-glowstick-orange.webp',
  './weapon-glowstick-pink.webp',
  './weapon-glowstick-violet.webp',
  './weapon-glowstick-yellow.webp',
  './weapon-handcuffs.webp',
  './weapon-missile.webp',
  './weapon-venom.webp',
  './zombie-armored.webp',
  './zombie-berserker.webp',
  './zombie-brute.webp',
  './zombie-bulwark.webp',
  './zombie-fuse.webp',
  './zombie-helmet.webp',
  './zombie-normal.webp',
  './zombie-runner.webp',
  './zombie-titan.webp',
  './zombie-toxic.webp',
];
// Install the complete release atomically, including music and every boss form.
self.addEventListener('install', (event) =>
  event.waitUntil(
    caches
      .open(CACHE)
      .then(async (cache) => {
        // Six downloads at a time instead of all of them at once.
        for (let i = 0; i < ASSETS.length; i += 6) {
          await Promise.all(
            ASSETS.slice(i, i + 6).map(async (a) => {
              const r = await fetch(a, { cache: 'reload' });
              if (!r.ok) throw new Error(a);
              await cache.put(a, await clean(r));
            }),
          );
        }
      })
      .then(() => self.skipWaiting()),
  ),
);
// Safari rejects a service-worker response flagged as redirected (Vercel cleanUrls redirects /index.html to /).
async function clean(r) {
  if (!r.redirected) return r;
  return new Response(await r.blob(), {
    status: r.status,
    statusText: r.statusText,
    headers: r.headers,
  });
}
// Safari only plays video when the server answers byte-range requests, so the cached clip is sliced here.
async function rangeResponse(response, header) {
  const match = /^bytes=(\d*)-(\d*)$/.exec(header.trim());
  if (!match || (!match[1] && !match[2])) return response;
  const blob = await response.clone().blob(), size = blob.size;
  let start, end;
  if (!match[1]) { const suffix = Number(match[2]); start = Math.max(0,size-suffix); end = size-1; }
  else { start = Number(match[1]); end = match[2] ? Math.min(Number(match[2]),size-1) : size-1; }
  const headers = new Headers(response.headers); headers.set('Accept-Ranges','bytes');
  if (!Number.isSafeInteger(start) || !Number.isSafeInteger(end) || start < 0 || start >= size || end < start) {
    headers.set('Content-Range',`bytes */${size}`); headers.set('Content-Length','0'); return new Response(null,{status:416,headers});
  }
  headers.set('Content-Range',`bytes ${start}-${end}/${size}`); headers.set('Content-Length',String(end-start+1));
  return new Response(blob.slice(start,end+1),{status:206,headers});
}

async function ready() {
  const clients = await self.clients.matchAll({ includeUncontrolled: true });
  for (const client of clients) client.postMessage({ type: 'OFFLINE_READY' });
}
self.addEventListener('activate', (event) =>
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys
            .filter(
              (k) =>
                (k.startsWith('zombie-smash-') || k.startsWith('zc2-community-')) && k !== CACHE,
            )
            .map((k) => caches.delete(k)),
        ),
      )
      .then(() => self.clients.claim())
      .then(ready),
  ),
);
self.addEventListener('message', (event) => {
  if (event.data?.type === 'CACHE_STATUS') event.waitUntil(ready());
});
self.addEventListener('fetch', (event) => {
  const req = event.request,
    url = new URL(req.url);
  if (req.method !== 'GET' || url.origin !== self.location.origin) return;
  event.respondWith(
    caches.open(CACHE).then(async (cache) => {
      // Navigation uses the same cached build as its scripts. Worker updates replace it as a unit.
      const cached = await cache.match(req.mode === 'navigate' ? './index.html' : req, {
        ignoreSearch: true,
      });
      if (cached) {
        const range = req.headers.get('range');
        if (range && /\.(mp4|mp3)$/.test(url.pathname)) return rangeResponse(cached, range);
        return clean(cached);
      }
      return fetch(req);
    }),
  );
});
