/**
 * DevReload - Auto refresh browser saat file berubah
 * Hanya aktif di localhost / 127.0.0.1
 */
(function () {
  // Hanya aktif di local development
  const isLocal = ["localhost", "127.0.0.1", "::1"].includes(location.hostname);
  if (!isLocal) return;

  const POLL_INTERVAL = 1500; // cek setiap 1.5 detik
  let lastTimestamp = null;
  let failCount = 0;
  const MAX_FAILS = 5;

  // Cari base path ke api/watch.php
  function getWatchUrl() {
    const path = location.pathname; // e.g. /mikrotik_monitor/web/settings.html
    const parts = path.split("/");
    // Cari folder 'web' dan build path dari sana
    const webIdx = parts.indexOf("web");
    if (webIdx >= 0) {
      return "/" + parts.slice(1, webIdx + 1).join("/") + "/api/watch.php";
    }
    return "/api/watch.php";
  }

  async function checkChanges() {
    try {
      const res = await fetch(getWatchUrl() + "?_=" + Date.now(), {
        cache: "no-store",
      });
      if (!res.ok) {
        failCount++;
        return;
      }
      const data = await res.json();

      if (lastTimestamp === null) {
        lastTimestamp = data.timestamp;
      } else if (data.timestamp !== lastTimestamp) {
        console.log("[DevReload] File berubah, refresh...");
        location.reload();
        return;
      }
      failCount = 0;
    } catch (e) {
      failCount++;
      if (failCount >= MAX_FAILS) {
        console.warn(
          "[DevReload] Tidak bisa koneksi ke watch.php, auto-reload dinonaktifkan.",
        );
        clearInterval(timer);
      }
    }
  }

  checkChanges();
  const timer = setInterval(checkChanges, POLL_INTERVAL);

  // Tampilkan indikator kecil di pojok kanan atas
  const badge = document.createElement("div");
  badge.style.cssText = [
    "position:fixed",
    "bottom:10px",
    "left:10px",
    "z-index:99999",
    "background:rgba(0,200,100,0.15)",
    "border:1px solid rgba(0,200,100,0.4)",
    "color:#00c864",
    "font-size:10px",
    "font-family:monospace",
    "padding:3px 8px",
    "border-radius:4px",
    "cursor:pointer",
    "opacity:0.6",
    "user-select:none",
  ].join(";");
  badge.textContent = "⟳ DevReload aktif";
  badge.title = "Klik untuk refresh manual";
  badge.onclick = () => location.reload();
  document.addEventListener("DOMContentLoaded", () =>
    document.body.appendChild(badge),
  );
})();
