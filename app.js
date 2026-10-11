// fosh&fish website: real download links + sizes, your platform highlighted, the current version.
// Everything falls back to plain links (the GitHub releases page) if a request fails.
(() => {
  const REPO = "iiafosh/fosh-and-fish";
  // where update.json lives: the site root when live, ../ for the /site/ preview
  const ROOT = location.pathname.includes("/site/") ? "../" : "./";

  // your platform
  const ua = navigator.userAgent.toLowerCase();
  const os = /android/.test(ua) ? "android" : /windows/.test(ua) ? "windows" : /linux|x11|cros/.test(ua) ? "linux" : "other";
  const mine = document.querySelector(`.pill[data-os="${os}"]`);
  if (mine) mine.classList.add("mine");
  const hints = {
    windows: "Unzip, then run <b>fosh_fish.exe</b>. If Windows says it protected your PC, choose <b>More info → Run anyway</b> (the game isn't code-signed yet).",
    android: "Open the downloaded <b>.apk</b> and allow installs from your browser when your phone asks.",
    linux: "Extract, then run <b>fosh_fish.x86_64</b>.",
    other: "fosh&fish is available for <b>Windows</b>, <b>Linux</b> and <b>Android</b>.",
  };
  document.getElementById("hint").innerHTML = hints[os];

  // downloads: the newest full release on GitHub (sizes go into each button)
  fetch(`https://api.github.com/repos/${REPO}/releases/latest`, { headers: { Accept: "application/vnd.github+json" } })
    .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
    .then((rel) => {
      document.querySelectorAll(".pill[data-asset]").forEach((pill) => {
        const a = rel.assets.find((x) => x.name.endsWith(pill.dataset.asset));
        if (!a) return;
        pill.href = a.browser_download_url;
        const em = pill.querySelector("em");
        em.textContent = `${em.textContent} · ${Math.round(a.size / 1048576)} MB`;     // (no line break inside "60 MB")
      });
    })
    .catch(() => {});

  // the version players get today (the base download plus in-game updates)
  fetch(`${ROOT}update.json?t=${Date.now()}`)
    .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
    .then((m) => (document.getElementById("ver-chip").textContent = `v${m.version} beta`))
    .catch(() => {});
})();
