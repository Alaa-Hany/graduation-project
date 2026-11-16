// The web app is built with `--pwa-strategy=none`, so no service worker is
// registered. Older builds DID register one, and a stale service worker in a
// returning visitor's browser keeps serving its cached old bundle/assets even
// after a new deploy — which shows up as old UI, broken Arabic, and mojibake
// content from old caches. Whenever this fresh page loads, remove any leftover
// service worker and drop its caches so the visitor always gets the latest
// deployed build going forward.
//
// Kept in its own file (not inline in index.html) so the Content-Security-Policy
// can allow scripts from 'self' only, without 'unsafe-inline'.
(function () {
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.getRegistrations().then(function (regs) {
      regs.forEach(function (reg) { reg.unregister(); });
    });
  }
  if (window.caches && caches.keys) {
    caches.keys().then(function (keys) {
      keys.forEach(function (k) { caches.delete(k); });
    });
  }
})();
