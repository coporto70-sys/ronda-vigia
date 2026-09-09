/* Ronda Vigía — service worker.
   Guarda la app en el dispositivo para que abra sin señal, que es lo normal
   en un cerco perimetral o una sala de máquinas.
   Al publicar una versión nueva, sube el número de CACHE. */
const CACHE = "ronda-vigia-v3";

const ARCHIVOS = [
  "./",
  "./index.html",
  "./manifest.webmanifest",
  "./icon-192.png",
  "./icon-512.png",
  "./icon-maskable-512.png",
  "./apple-touch-icon.png",
  /* lector y generador de códigos QR: van alojados aquí para funcionar sin señal */
  "./qrcode.min.js",
  "./qr-scanner.umd.min.js",
  "./qr-scanner-worker.min.js"
];

self.addEventListener("install", e => {
  e.waitUntil(
    caches.open(CACHE)
      .then(c => c.addAll(ARCHIVOS))
      .then(() => self.skipWaiting())
      .catch(() => self.skipWaiting())
  );
});

self.addEventListener("activate", e => {
  e.waitUntil(
    caches.keys()
      .then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

function cacheable(url) {
  return url.origin === self.location.origin ||
         url.hostname === "fonts.googleapis.com" ||
         url.hostname === "fonts.gstatic.com";
}

self.addEventListener("fetch", e => {
  const req = e.request;
  if (req.method !== "GET") return;

  /* La página: red primero, para que una versión nueva se vea al recargar
     con señal; si no hay red, la copia guardada. */
  if (req.mode === "navigate") {
    e.respondWith(
      fetch(req)
        .then(res => {
          const copia = res.clone();
          caches.open(CACHE).then(c => c.put("./index.html", copia)).catch(() => {});
          return res;
        })
        .catch(() => caches.match("./index.html").then(hit => hit || caches.match("./")))
    );
    return;
  }

  /* Tipografías e iconos: la copia guardada primero. */
  e.respondWith(
    caches.match(req).then(hit => hit || fetch(req).then(res => {
      try {
        const url = new URL(req.url);
        if (res.ok && cacheable(url)) {
          const copia = res.clone();
          caches.open(CACHE).then(c => c.put(req, copia)).catch(() => {});
        }
      } catch (err) { /* url no analizable: se sirve sin guardar */ }
      return res;
    }))
  );
});
