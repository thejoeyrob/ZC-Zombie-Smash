const CACHE = 'zombie-smash-v7.31.3';
const ASSETS = [
  './console-toxic-pop.webp',
  './console-disco-fever.webp',
  './console-pocket-arcade.webp',
  './404.html',
  './apple-touch-icon.png',
  './art-bounds.json',
  './audio-classic.js',
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
  './game-preview.webp',
  './game.css',
  './game.js',
  './haptics.js',
  './icon-192.png',
  './icon-512.png',
  './icon-maskable-512.png',
  './index.html',
  './joey-reaction-close.webp',
  './legacy-board.json',
  './manifest.webmanifest',
  './title-bg.webp',
  './logo-flat.png',

  './map-concrete.jpg',
  './map-desert.jpg',
  './map-hangar.jpg',
  './map-north.jpg',
  './map-wasteland.jpg',
  './music-boss.mp3',
  './music-debo.mp3',
  './music-disco.mp3',
  './music-entrance.mp3',
  './music-main.mp3',
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
  './sfx-pickup.mp3',
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
  './comic-caffeinatedsloth-bossdown.webp',
  './comic-caffeinatedsloth-form2.webp',
  './comic-caffeinatedsloth-intro.webp',
  './comic-caffeinatedsloth-joeydown.webp',
  './comic-debo-bossdown.webp',
  './comic-debo-form2.webp',
  './comic-debo-intro.webp',
  './comic-debo-joeydown.webp',
  './comic-discoman-bossdown.webp',
  './comic-discoman-form2.webp',
  './comic-discoman-intro.webp',
  './comic-discoman-joeydown.webp',
  './comic-drmantis-bossdown.webp',
  './comic-drmantis-form2.webp',
  './comic-drmantis-form3.webp',
  './comic-drmantis-intro.webp',
  './comic-drmantis-joeydown.webp',
  './comic-fatamy-bossdown.webp',
  './comic-fatamy-form2.webp',
  './comic-fatamy-form3.webp',
  './comic-fatamy-intro.webp',
  './comic-fatamy-joeydown.webp',
  './comic-glowinghumanity-bossdown.webp',
  './comic-glowinghumanity-form2.webp',
  './comic-glowinghumanity-intro.webp',
  './comic-glowinghumanity-joeydown.webp',
  './comic-jordan-bossdown.webp',
  './comic-jordan-form2.webp',
  './comic-jordan-intro.webp',
  './comic-jordan-joeydown.webp',
  './scene-clips.json',
  './skins-extra.json',
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
  './weapon-tea.webp',
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
      .then((cache) =>
        Promise.all(
          ASSETS.map(async (a) => {
            const r = await fetch(a, { cache: 'reload' });
            if (!r.ok) throw new Error(a);
            await cache.put(a, await clean(r));
          }),
        ),
      )
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
  const buffer = await response.clone().arrayBuffer(),
    size = buffer.byteLength,
    match = /bytes=(\d*)-(\d*)/.exec(header) || [],
    start = match[1] ? Number(match[1]) : 0,
    end = match[2] ? Math.min(Number(match[2]), size - 1) : size - 1;
  return new Response(buffer.slice(start, end + 1), {
    status: 206,
    headers: {
      'Content-Type': 'video/mp4',
      'Content-Range': `bytes ${start}-${end}/${size}`,
      'Content-Length': String(end - start + 1),
      'Accept-Ranges': 'bytes',
    },
  });
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
        if (range && /\.mp4$/.test(url.pathname)) return rangeResponse(cached, range);
        return clean(cached);
      }
      return fetch(req);
    }),
  );
});
