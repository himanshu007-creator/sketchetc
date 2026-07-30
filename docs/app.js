// Everything is rendered from data/site.json + data/trust.json, both generated
// from the live config — new widgets, themes and icon sets appear by themselves.
const $ = (s, r = document) => r.querySelector(s);
const el = (t, c, h) => { const n = document.createElement(t); if (c) n.className = c; if (h != null) n.innerHTML = h; return n; };
const REPO = "himanshu007-creator/sketchetc";
const COUNTER = "https://api.counterapi.dev/v1/sketchetc";

const FAQ = [
  ["does it replace the native menu bar?", "It draws over the strip macOS already reserves, so your windows still tile below it and native menus stay reachable. One row in the apple menu reverts everything instantly."],
  ["what permissions does it want?", "Accessibility for window snapping, desktop switching and paste; Automation for media and app switching; Calendar for the meeting widget; Screen Recording for screenshots. Decline any of them and that widget simply hides."],
  ["is piping to bash safe here?", "Read it first — that is the honest answer. The installer is ~130 lines of plain shell with no obfuscation, the page shows its SHA256, the README embeds the whole thing, and you can pin an immutable release tag. It never uses sudo."],
  ["where does my data live?", "One folder you choose: journal entries, aura history and clipboard history all sit under it. Reinstall, point at the same folder, and everything is restored."],
  ["how do I uninstall?", "<code>~/.local/share/sketchetc/app/uninstall.sh</code> — stops the service, removes the symlink, restores any config it backed up."],
  ["can I add my own widget?", "Yes, about 30 lines of bash in two files. WIDGETS.md walks through it, and this page picks it up automatically once it is in the config."],
  ["what is the licence?", "CC BY-NC-ND 4.0 — free forever, never sold. Use it, share it, credit it. Do not charge for it and do not ship a modified copy as your own release. Tuning your own bar and writing your own themes are just use, not derivatives."],
];

function applyTheme(t) {
  const c = t.colors, r = document.documentElement;
  const map = { "--bar": "BAR_COLOR", "--pill": "ITEM_BG_COLOR", "--pop": "POPUP_BG", "--border": "POPUP_BORDER",
                "--a1": "PINK", "--a2": "CYAN", "--warn": "ORANGE", "--crit": "RED", "--glow": "PURPLE", "--text": "WHITE" };
  for (const [v, k] of Object.entries(map)) if (c[k]) r.style.setProperty(v, c[k]);
  r.dataset.theme = t.name;
  localStorage.setItem("sketchetc-theme", t.name);
  document.querySelectorAll(".sw").forEach(s => s.setAttribute("aria-pressed", s.dataset.name === t.name));
}

function fauxBar(d) {
  const pick = k => d.widgets.find(w => w.key === k);
  const bar = $("#fauxbar");
  const items = [
    ["apple", "", "p"], ["theme", "", ""], ["widgets", "", ""],
    ["spaces", "1 2 3 4", ""],
    ["aura", "187", "g"], ["clipboard", "", ""], ["snap", "", ""],
    ["network", "↓14K ↑438K", ""], ["volume", "100%", ""],
    ["cpu", "27%", "ring"], ["clock", "—", "c"],
  ];
  items.forEach(([k, label, cls]) => {
    const s = el("span", "fbi " + cls, icon(k) + (label ? ` <b>${label}</b>` : ""));
    s.id = "fb-" + k;
    s.title = (pick(k)?.description) || k;
    bar.appendChild(s);
  });
}

function render(d, trust) {
  $("#ver").textContent = "v" + d.version;
  $("#total").textContent = "$" + d.replaces_total;
  $("#count").textContent = d.widgets.length;
  $("#isets").textContent = d.iconsets.length;
  $("#widgets").textContent = d.widgets.length;

  // theme swatches
  d.themes.forEach(t => {
    const b = el("button", "sw");
    b.dataset.name = t.name; b.title = t.name;
    b.style.background = `linear-gradient(135deg, ${t.colors.PINK}, ${t.colors.CYAN})`;
    b.onclick = () => applyTheme(t);
    $("#swatches").appendChild(b);
  });
  const saved = localStorage.getItem("sketchetc-theme");
  applyTheme(d.themes.find(t => t.name === saved) || d.themes.find(t => t.name === "vice-city") || d.themes[0]);

  fauxBar(d);

  // marquee: what you stop paying for
  const paid = d.widgets.filter(w => w.replaces && w.replaces.price);
  const chips = paid.map(w => `<span class="chip">${icon(w.key)} <s>${w.replaces.app}</s> <b>$${w.replaces.price}</b></span>`).join("");
  $("#track").innerHTML = chips + chips;

  // instead-of rows
  paid.sort((a, b) => b.replaces.price - a.replaces.price).forEach(w => {
    const li = el("li");
    li.appendChild(el("span", "k", icon(w.key)));
    li.appendChild(el("span", null, `<span class="n">${w.key}</span><div class="d">${w.description || ""}</div>`));
    li.appendChild(el("span", "r", `${w.replaces.app} · $${w.replaces.price}`));
    $("#pricerows").appendChild(li);
  });

  // every widget
  d.widgets.forEach(w => {
    const li = el("li");
    li.appendChild(el("span", "k", icon(w.key)));
    li.appendChild(el("span", null,
      `<span class="n">${w.key}</span><span class="tag ${w.default_on ? "on" : "off"}">${w.default_on ? "default" : "opt in"}</span>
       <div class="d">${w.description || ""}</div>`));
    $("#featrows").appendChild(li);
  });

  // theme gallery
  d.themes.forEach(t => {
    const s = el("div", "shot");
    const img = el("img");
    img.loading = "lazy"; img.alt = t.name; img.src = `../assets/theme-${t.name}.png`;
    img.onerror = () => s.remove();
    s.appendChild(img); s.appendChild(el("span", null, t.name));
    $("#gallery").appendChild(s);
  });

  FAQ.forEach(([q, a]) => {
    const dt = el("details");
    dt.appendChild(el("summary", null, q));
    dt.appendChild(el("p", null, a));
    $("#faq").appendChild(dt);
  });

  if (trust) {
    $("#sum").textContent = "# " + trust.sha256;
    $("#lines").textContent = trust.lines;
    $("#pin").textContent = `raw.githubusercontent.com/${REPO}/v${trust.version}/docs/install.sh`;
  }

  document.querySelectorAll(".block, .marquee, footer").forEach(n => n.classList.add("rv"));
  const io = new IntersectionObserver(es => es.forEach(e => {
    if (e.isIntersecting) { e.target.classList.add("in"); io.unobserve(e.target); }
  }), { threshold: .08 });
  document.querySelectorAll(".rv").forEach(n => io.observe(n));
  $(".hero").classList.add("in");
}

// live clock in the faux bar
function liveBar() {
  const tick = () => {
    const c = $("#fb-clock b"), n = new Date();
    if (c) c.textContent = n.toLocaleDateString("en-GB", { weekday: "short", day: "2-digit", month: "short" })
      + "  " + n.toTimeString().slice(0, 5);
  };
  tick(); setInterval(tick, 10000);
  const hum = v => v > 999 ? (v / 1000).toFixed(1) + "M" : v + "K";
  setInterval(() => {
    const n = $("#fb-network b");
    if (n) n.textContent = `↓${hum(Math.floor(4 + Math.random() * 90))} ↑${hum(Math.floor(20 + Math.random() * 700))}`;
  }, 2400);
  let a = 187;
  setInterval(() => { const e = $("#fb-aura b"); if (e && Math.random() < .35) e.textContent = ++a; }, 3600);
}

// counters: one visit ping, one installs read (no analytics, no cookies)
function counters() {
  fetch(`${COUNTER}/visits/up`).then(r => r.json())
    .then(d => { if (typeof d.count === "number") $("#visits").textContent = d.count.toLocaleString(); })
    .catch(() => {});
  fetch(`${COUNTER}/installs/`).then(r => r.json())
    .then(d => { if (typeof d.count === "number") $("#installs").textContent = d.count.toLocaleString(); })
    .catch(() => {});
}

function badges() {
  const defs = [
    ["latest release", `https://img.shields.io/github/v/release/${REPO}?style=flat&label=release&color=ff6ec7&labelColor=1b0d33&display_name=tag&sort=semver`,
     `https://github.com/${REPO}/releases/latest`],
    ["stars", `https://img.shields.io/github/stars/${REPO}?style=flat&logo=github&logoColor=white&label=stars&color=9b5de5&labelColor=1b0d33`,
     `https://github.com/${REPO}/stargazers`],
    ["forks", `https://img.shields.io/github/forks/${REPO}?style=flat&logo=github&logoColor=white&label=forks&color=555&labelColor=1b0d33`,
     `https://github.com/${REPO}/forks`],
    ["OpenSSF Scorecard", `https://api.scorecard.dev/projects/github.com/${REPO}/badge`,
     `https://scorecard.dev/viewer/?uri=github.com/${REPO}`],
    ["licence: CC BY-NC-ND 4.0", "https://img.shields.io/badge/licence-CC%20BY--NC--ND%204.0-0bd3d3?style=flat&labelColor=1b0d33",
     `https://github.com/${REPO}/blob/production/LICENSE`],
  ];
  // anchors are created up front so the order is the order above, not whichever
  // badge happens to load first; each stays hidden until its image resolves
  defs.forEach(([alt, src, href]) => {
    const a = el("a");
    a.href = href; a.target = "_blank"; a.rel = "noopener";
    a.hidden = true; a.title = alt;
    const img = new Image();
    img.alt = alt;
    img.onload = () => { a.hidden = false; };
    img.onerror = () => a.remove();
    a.appendChild(img);
    $("#topbadges").appendChild(a);
    img.src = src;
  });
}

// cursor glow + hero tilt + scroll progress
function motion() {
  if (matchMedia("(prefers-reduced-motion: reduce)").matches) return;
  const glow = $("#glow"), bar = $("#fauxbar");
  let tx = innerWidth / 2, ty = innerHeight * .22, cx = tx, cy = ty;
  addEventListener("pointermove", e => {
    tx = e.clientX; ty = e.clientY;
    if (bar) {
      const r = bar.getBoundingClientRect();
      const dx = (e.clientX - (r.left + r.width / 2)) / r.width;
      const dy = (e.clientY - (r.top + r.height / 2)) / Math.max(r.height, 1);
      bar.style.transform = `rotateX(${Math.max(-6, Math.min(6, -dy * 3 + 6))}deg) rotateY(${Math.max(-6, Math.min(6, dx * 6))}deg)`;
    }
  }, { passive: true });
  (function loop() {
    cx += (tx - cx) * .12; cy += (ty - cy) * .12;
    if (glow) { glow.style.left = cx + "px"; glow.style.top = cy + "px"; }
    requestAnimationFrame(loop);
  })();
  addEventListener("scroll", () => {
    const h = document.body.scrollHeight - innerHeight;
    $("#progress").style.width = (h > 0 ? (scrollY / h) * 100 : 0) + "%";
  }, { passive: true });
}

$("#copy").onclick = async () => {
  await navigator.clipboard.writeText($("#cmdtext").textContent.trim());
  const b = $("#copy");
  b.textContent = "copied ✓"; b.classList.add("done");
  setTimeout(() => { b.textContent = "copy"; b.classList.remove("done"); }, 1800);
};

addEventListener("load", () => {
  const t = performance.getEntriesByType("navigation")[0];
  $("#load").textContent = t ? Math.round(t.domContentLoadedEventEnd) + "ms" : "fast";
});

Promise.all([
  fetch("data/site.json").then(r => r.json()),
  fetch("data/trust.json").then(r => r.json()).catch(() => null),
]).then(([d, trust]) => { render(d, trust); liveBar(); motion(); counters(); badges(); })
  .catch(() => { $("#featrows").innerHTML = "<li>could not load feature data</li>"; });
