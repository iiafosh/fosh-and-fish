// fosh&fish website: live downloads, version, leaderboard. Everything degrades to static links if offline.
(() => {
  const REPO = "iiafosh/fosh-and-fish";
  // public (publishable) key: the same one the game ships with; the database only lets it read the leaderboard
  const SUPABASE = "https://covbtshpynvtpdpbyjkg.supabase.co";
  const ANON = "sb_publishable_RRfBhFNE2FHFB1stCxiJWA_I2RcMY2D";

  // where the web game and update.json live: foshfish.xyz/play/ when live, ../ for the /site/ preview
  const preview = location.pathname.includes("/site/");
  const GAME = preview ? "../" : "play/";
  const ROOT = preview ? "../" : "./";
  document.querySelectorAll("[data-play]").forEach((a) => (a.href = GAME));

  // nav background once you scroll
  const nav = document.querySelector(".nav");
  const onScroll = () => nav.classList.toggle("scrolled", scrollY > 30);
  addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  // your platform
  const ua = navigator.userAgent.toLowerCase();
  const os = /android/.test(ua) ? "android" : /windows/.test(ua) ? "windows" : /linux|x11/.test(ua) ? "linux" : "web";
  const mine = document.querySelector(`.plat[data-os="${os}"]`);
  if (mine) mine.classList.add("mine");
  const heroDl = document.getElementById("hero-download");
  const names = { windows: "Windows", android: "Android", linux: "Linux" };

  const mb = (n) => (n / 1048576).toFixed(0) + " MB";

  // downloads: the newest full release on GitHub
  fetch(`https://api.github.com/repos/${REPO}/releases/latest`, { headers: { Accept: "application/vnd.github+json" } })
    .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
    .then((rel) => {
      document.querySelectorAll(".plat[data-asset]").forEach((card) => {
        const a = rel.assets.find((x) => x.name.endsWith(card.dataset.asset));
        if (!a) return;
        card.href = a.browser_download_url;
        const ext = card.dataset.asset.replace(/^-[a-z]+/, "");
        card.querySelector(".size").textContent = `${mb(a.size)} · ${ext}`;
      });
      if (names[os] && mine && mine.dataset.asset) {
        heroDl.href = mine.href;
        heroDl.querySelector("span").textContent = `Download for ${names[os]}`;
      }
    })
    .catch(() => {});

  // version + what's new: the game's own update manifest
  fetch(`${ROOT}update.json?t=${Date.now()}`)
    .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
    .then((m) => {
      document.getElementById("ver-chip").textContent = `v${m.version} beta`;
      const date = m.date ? new Date(m.date + "T12:00:00Z").toLocaleDateString(undefined, { day: "numeric", month: "short", year: "numeric" }) : "";
      document.getElementById("news-ver").textContent = `fosh&fish ${m.version}` + (date ? ` · ${date}` : "");
      if (Array.isArray(m.notes) && m.notes.length) {
        const ul = document.getElementById("news-notes");
        ul.replaceChildren(...m.notes.map((n) => Object.assign(document.createElement("li"), { textContent: n })));
      }
    })
    .catch(() => {});

  // live leaderboard
  fetch(`${SUPABASE}/rest/v1/leaderboard?select=display_name,level,prestige&order=prestige.desc,level.desc,money_earned.desc&limit=10`,
    { headers: { apikey: ANON, Accept: "application/json" } })
    .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
    .then((rows) => {
      if (!Array.isArray(rows) || !rows.length) return;
      const ol = document.getElementById("ranks");
      rows.forEach((row, i) => {
        const li = document.createElement("li");
        const pos = Object.assign(document.createElement("span"), { className: "pos", textContent: i + 1 });
        const name = Object.assign(document.createElement("span"), { className: "name", textContent: row.display_name });
        const pr = Object.assign(document.createElement("span"), { className: "pr", textContent: `P${row.prestige}` });
        const lv = Object.assign(document.createElement("span"), { className: "lv", textContent: `Lv ${Number(row.level).toLocaleString()}` });
        li.append(pos, name, pr, lv);
        ol.append(li);
      });
      if (rows.length < 5) {
        const p = Object.assign(document.createElement("p"), { className: "more", textContent: "The sea is still quiet. Grab a top spot while you can!" });
        ol.after(p);
      }
      document.getElementById("leaderboard").hidden = false;
    })
    .catch(() => {});
})();
