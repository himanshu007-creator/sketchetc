// Inline SVG icon set. Visitors don't have Nerd Font installed, so the site
// never renders the glyphs from site.json — it draws these instead.
// Stroke based, currentColor, 24x24.
const ICONS = {
  clipboard: '<rect x="8" y="3" width="8" height="4" rx="1"/><path d="M16 5h2a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2h2"/>',
  shot: '<path d="M4 8V6a2 2 0 0 1 2-2h2M16 4h2a2 2 0 0 1 2 2v2M20 16v2a2 2 0 0 1-2 2h-2M8 20H6a2 2 0 0 1-2-2v-2"/><circle cx="12" cy="12" r="3"/>',
  network: '<path d="M12 20V10"/><path d="M8 14l4-4 4 4"/><path d="M5 4h14"/>',
  caffeine: '<path d="M17 8h1a3 3 0 0 1 0 6h-1"/><path d="M3 8h14v6a4 4 0 0 1-4 4H7a4 4 0 0 1-4-4V8z"/><path d="M6 2v2M10 2v2M14 2v2"/>',
  bluetooth: '<path d="M7 7l10 10-5 4V3l5 4L7 17"/>',
  switches: '<circle cx="8" cy="8" r="3"/><circle cx="16" cy="16" r="3"/><path d="M11 8h9M4 16h9"/>',
  temps: '<path d="M14 14V5a2 2 0 1 0-4 0v9a4 4 0 1 0 4 0z"/>',
  snap: '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M12 4v16"/>',
  pomodoro: '<circle cx="12" cy="13" r="8"/><path d="M12 13V9"/><path d="M9 2h6"/>',
  aura: '<path d="M12 3l2.5 5.5L20 11l-5.5 2.5L12 19l-2.5-5.5L4 11l5.5-2.5z"/>',
  journal: '<path d="M5 4a2 2 0 0 1 2-2h11v20H7a2 2 0 0 1-2-2z"/><path d="M9 2v20"/>',
  github: '<path d="M9 19c-4 1.5-4-2.5-6-3m12 6v-3.9a3.4 3.4 0 0 0-1-2.6c3-.3 6-1.5 6-6.5a5 5 0 0 0-1.4-3.5 4.6 4.6 0 0 0-.1-3.5s-1.4-.4-4.5 1.7a12.3 12.3 0 0 0-6 0C4.4 1.1 3 1.5 3 1.5a4.6 4.6 0 0 0-.1 3.5A5 5 0 0 0 1.5 8.5c0 5 3 6.2 6 6.5a3.4 3.4 0 0 0-1 2.6V22"/>',
  weather: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M5 5l1.5 1.5M17.5 17.5L19 19M19 5l-1.5 1.5M6.5 17.5L5 19"/>',
  speedtest: '<path d="M12 20a8 8 0 1 1 8-8"/><path d="M12 12l5-3"/>',
  meeting: '<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M8 3v4M16 3v4M3 11h18"/>',
  focus: '<path d="M20 14a8 8 0 1 1-9-11 6 6 0 0 0 9 11z"/>',
  media: '<circle cx="7" cy="17" r="3"/><circle cx="18" cy="15" r="3"/><path d="M10 17V5l11-2v12"/>',
  ports: '<rect x="4" y="9" width="16" height="11" rx="2"/><path d="M8 9V5a4 4 0 0 1 8 0v4"/>',
  spaces: '<rect x="3" y="4" width="7" height="7" rx="1"/><rect x="14" y="4" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/>',
  update: '<path d="M12 4v10"/><path d="M8 10l4 4 4-4"/><path d="M4 18a8 8 0 0 0 16 0"/>',
  clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  ram: '<rect x="3" y="7" width="18" height="10" rx="2"/><path d="M7 7V4M12 7V4M17 7V4"/>',
  cpu: '<rect x="6" y="6" width="12" height="12" rx="2"/><path d="M10 2v3M14 2v3M10 19v3M14 19v3M2 10h3M2 14h3M19 10h3M19 14h3"/>',
  battery: '<rect x="2" y="8" width="17" height="9" rx="2"/><path d="M21 11v3"/><path d="M5 11v3"/>',
  volume: '<path d="M11 5L6 9H3v6h3l5 4z"/><path d="M16 9a4 4 0 0 1 0 6"/>',
  wifi: '<path d="M2 8a16 16 0 0 1 20 0"/><path d="M5.5 12a11 11 0 0 1 13 0"/><path d="M9 15.5a6 6 0 0 1 6 0"/><circle cx="12" cy="19" r="1"/>',
  theme: '<circle cx="12" cy="12" r="9"/><path d="M12 3a9 9 0 0 0 0 18z" fill="currentColor" stroke="none"/>',
  widgets: '<rect x="3" y="3" width="8" height="8" rx="2"/><rect x="13" y="3" width="8" height="8" rx="2"/><rect x="3" y="13" width="8" height="8" rx="2"/><rect x="13" y="13" width="8" height="8" rx="2"/>',
  apple: '<path d="M16 3c0 2-1.5 3.5-3 3.5"/><path d="M12 8c-4 0-7 3-7 7 0 4 3 7 5 7 1.5 0 2-1 2-1s.5 1 2 1c2 0 5-3 5-7 0-4-3-7-7-7z"/>',
  // small set used only by the top bar pills
  tag: '<path d="M20.6 13.4 12 22l-9-9 8.6-8.6a2 2 0 0 1 1.4-.6H20a2 2 0 0 1 2 2v6a2 2 0 0 1-.6 1.4z"/><circle cx="17" cy="7" r="1.2"/>',
  download: '<path d="M12 3v12"/><path d="M7 11l5 5 5-5"/><path d="M4 20h16"/>',
  eye: '<path d="M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6-10-6-10-6z"/><circle cx="12" cy="12" r="2.5"/>',
  star: '<path d="M12 3l2.9 5.9 6.5.9-4.7 4.6 1.1 6.5L12 17.8 6.2 20.9l1.1-6.5L2.6 9.8l6.5-.9z"/>',
  fork: '<circle cx="7" cy="5" r="2.2"/><circle cx="17" cy="5" r="2.2"/><circle cx="12" cy="19" r="2.2"/><path d="M7 7.2v2A2.8 2.8 0 0 0 9.8 12h4.4A2.8 2.8 0 0 0 17 9.2v-2"/><path d="M12 12v4.8"/>',
  shield: '<path d="M12 3l8 3v6c0 5-3.4 8.2-8 9-4.6-.8-8-4-8-9V6z"/><path d="M9 12l2 2 4-4"/>',
  scale: '<path d="M12 3v18"/><path d="M6 7h12"/><path d="M6 7 3 14h6z"/><path d="M18 7l-3 7h6z"/><path d="M8 21h8"/>',
  default: '<circle cx="12" cy="12" r="8"/>',
};

function icon(name, cls = "ic") {
  const body = ICONS[name] || ICONS.default;
  return `<svg class="${cls}" viewBox="0 0 24 24" fill="none" stroke="currentColor"
    stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${body}</svg>`;
}
