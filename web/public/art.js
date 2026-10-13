/*
 * Иллюстрации техники для ТехноМира: объёмные SVG-рисунки для каждого вида товара.
 * Вид определяется по названию товара, цвет корпуса (серебро, белый, чёрный) —
 * по id, чтобы разные модели одной категории выглядели по-разному.
 * Градиенты объявлены один раз в скрытом <svg> (ART_DEFS) и используются всеми рисунками.
 */
"use strict";

const ART_DEFS = `
<svg width="0" height="0" style="position:absolute" aria-hidden="true" focusable="false">
  <defs>
    <linearGradient id="m-silver" x1="0" x2="1">
      <stop offset="0" stop-color="#8d969b"/><stop offset=".14" stop-color="#d9dfe2"/>
      <stop offset=".42" stop-color="#bfc7cb"/><stop offset=".68" stop-color="#eef2f3"/>
      <stop offset=".9" stop-color="#c4cbcf"/><stop offset="1" stop-color="#959ea3"/>
    </linearGradient>
    <linearGradient id="m-white" x1="0" x2="1">
      <stop offset="0" stop-color="#cfd5d8"/><stop offset=".16" stop-color="#f7f9fa"/>
      <stop offset=".55" stop-color="#ffffff"/><stop offset=".85" stop-color="#f1f4f5"/>
      <stop offset="1" stop-color="#cdd3d6"/>
    </linearGradient>
    <linearGradient id="m-black" x1="0" x2="1">
      <stop offset="0" stop-color="#121517"/><stop offset=".18" stop-color="#3b4246"/>
      <stop offset=".5" stop-color="#23282b"/><stop offset=".76" stop-color="#4a5257"/>
      <stop offset="1" stop-color="#16191b"/>
    </linearGradient>
    <linearGradient id="m-graphite" x1="0" x2="1">
      <stop offset="0" stop-color="#4a5054"/><stop offset=".2" stop-color="#7d868b"/>
      <stop offset=".55" stop-color="#5c6469"/><stop offset=".8" stop-color="#8a9398"/>
      <stop offset="1" stop-color="#474d51"/>
    </linearGradient>
    <linearGradient id="chrome" x1="0" x2="1">
      <stop offset="0" stop-color="#5f676c"/><stop offset=".3" stop-color="#f4f6f7"/>
      <stop offset=".55" stop-color="#9aa3a8"/><stop offset=".8" stop-color="#ffffff"/>
      <stop offset="1" stop-color="#6c7479"/>
    </linearGradient>
    <linearGradient id="chrome-v" x1="0" x2="0" y1="0" y2="1">
      <stop offset="0" stop-color="#ffffff"/><stop offset=".45" stop-color="#9aa3a8"/>
      <stop offset=".7" stop-color="#e9edef"/><stop offset="1" stop-color="#6c7479"/>
    </linearGradient>
    <linearGradient id="top-light" x1="0" x2="0" y1="0" y2="1">
      <stop offset="0" stop-color="#fff" stop-opacity=".45"/><stop offset=".25" stop-color="#fff" stop-opacity="0"/>
      <stop offset=".8" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".14"/>
    </linearGradient>
    <linearGradient id="screen" x1="0" x2="1" y1="0" y2="1">
      <stop offset="0" stop-color="#1d2a33"/><stop offset=".5" stop-color="#0b1116"/><stop offset="1" stop-color="#151f26"/>
    </linearGradient>
    <linearGradient id="screen-glare" x1="0" x2="1" y1="0" y2="1">
      <stop offset="0" stop-color="#fff" stop-opacity=".22"/><stop offset=".45" stop-color="#fff" stop-opacity=".04"/>
      <stop offset=".46" stop-color="#fff" stop-opacity="0"/>
    </linearGradient>
    <linearGradient id="tv-picture" x1="0" x2="1" y1="0" y2="1">
      <stop offset="0" stop-color="#1b5e7a"/><stop offset=".45" stop-color="#2f8f8a"/>
      <stop offset=".7" stop-color="#e3a64a"/><stop offset="1" stop-color="#7a3b4f"/>
    </linearGradient>
    <linearGradient id="tv-picture-1" x1="0" x2="1" y1="1" y2="0">
      <stop offset="0" stop-color="#0d2a4a"/><stop offset=".5" stop-color="#3366b8"/><stop offset=".8" stop-color="#9ad0f5"/><stop offset="1" stop-color="#f4f0e0"/>
    </linearGradient>
    <linearGradient id="tv-picture-2" x1="0" x2="1" y1="0" y2="1">
      <stop offset="0" stop-color="#3d1f5c"/><stop offset=".4" stop-color="#c2477a"/><stop offset=".75" stop-color="#f29a54"/><stop offset="1" stop-color="#ffd27a"/>
    </linearGradient>
    <radialGradient id="porthole" cx=".42" cy=".38" r=".75">
      <stop offset="0" stop-color="#55707f"/><stop offset=".55" stop-color="#1f2c33"/><stop offset="1" stop-color="#0a0f12"/>
    </radialGradient>
    <linearGradient id="glass" x1="0" x2="1">
      <stop offset="0" stop-color="#bcd3dc" stop-opacity=".55"/><stop offset=".25" stop-color="#ffffff" stop-opacity=".85"/>
      <stop offset=".6" stop-color="#d7e6ec" stop-opacity=".45"/><stop offset="1" stop-color="#9fb8c2" stop-opacity=".6"/>
    </linearGradient>
    <linearGradient id="water" x1="0" x2="0" y1="0" y2="1">
      <stop offset="0" stop-color="#9fd6ea" stop-opacity=".55"/><stop offset="1" stop-color="#4aa6cf" stop-opacity=".75"/>
    </linearGradient>
    <linearGradient id="dark-glass" x1="0" x2="1" y1="0" y2="1">
      <stop offset="0" stop-color="#3a4a53"/><stop offset=".5" stop-color="#11181c"/><stop offset="1" stop-color="#26323a"/>
    </linearGradient>
    <linearGradient id="bin" x1="0" x2="1">
      <stop offset="0" stop-color="#c9d6dc" stop-opacity=".7"/><stop offset=".35" stop-color="#ffffff" stop-opacity=".9"/>
      <stop offset="1" stop-color="#a9bcc5" stop-opacity=".7"/>
    </linearGradient>
    <linearGradient id="accent" x1="0" x2="1">
      <stop offset="0" stop-color="#6b2a7a"/><stop offset=".5" stop-color="#9b4bb0"/><stop offset="1" stop-color="#5e2370"/>
    </linearGradient>
    <linearGradient id="bread" x1="0" x2="0" y1="0" y2="1">
      <stop offset="0" stop-color="#e2a35c"/><stop offset="1" stop-color="#b8743a"/>
    </linearGradient>
    <radialGradient id="floor" cx=".5" cy=".5" r=".5">
      <stop offset="0" stop-color="#16231f" stop-opacity=".32"/><stop offset="1" stop-color="#16231f" stop-opacity="0"/>
    </radialGradient>
  </defs>
</svg>`;

(function injectArtDefs() {
  const holder = document.createElement("div");
  holder.innerHTML = ART_DEFS;
  document.body.prepend(holder.firstElementChild);
})();

const ART = (() => {
  const E = 'stroke="#0d1a16" stroke-opacity=".16" stroke-width="1"';
  const shadow = (cx, w, y = 183) => `<ellipse cx="${cx}" cy="${y}" rx="${w}" ry="${Math.max(4, w * 0.09)}" fill="url(#floor)"/>`;
  const light = (x, y, w, h, rx = 6) => `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${rx}" fill="url(#top-light)"/>`;
  const led = (x, y, w = 14, h = 6, c = "#6fe3a8") =>
    `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="1.5" fill="#0c1215"/><rect x="${x + 2}" y="${y + 2}" width="${w * 0.45}" height="${h - 4}" rx=".8" fill="${c}" opacity=".9"/>`;
  const knob = (cx, cy, r) =>
    `<circle cx="${cx}" cy="${cy}" r="${r}" fill="url(#chrome)" ${E}/><circle cx="${cx}" cy="${cy}" r="${r * 0.62}" fill="url(#m-silver)"/><rect x="${cx - 0.8}" y="${cy - r * 0.85}" width="1.6" height="${r * 0.55}" fill="#2b3236"/>`;
  const dark = (f) => f === "black" || f === "graphite";
  const trim = (f) => (dark(f) ? "#0d1012" : "#c9d0d4");

  const draw = {
    fridge(f) {
      return `${shadow(100, 52)}
        <rect x="58" y="12" width="84" height="170" rx="7" fill="url(#m-${f})" ${E}/>
        <rect x="58" y="12" width="7" height="170" rx="3" fill="#000" opacity=".07"/>
        <line x1="60" y1="108" x2="140" y2="108" stroke="${trim(f)}" stroke-width="2"/>
        <rect x="127" y="36" width="5" height="58" rx="2.5" fill="url(#chrome)" ${E}/>
        <rect x="127" y="120" width="5" height="40" rx="2.5" fill="url(#chrome)" ${E}/>
        ${led(70, 30, 18, 8, "#7cc8ff")}
        ${light(58, 12, 84, 170, 7)}
        <rect x="64" y="178" width="72" height="4" rx="1" fill="#1a1f22" opacity=".55"/>`;
    },
    sidebyside(f) {
      return `${shadow(100, 72)}
        <rect x="34" y="12" width="132" height="170" rx="7" fill="url(#m-${f})" ${E}/>
        <line x1="100" y1="13" x2="100" y2="181" stroke="${trim(f)}" stroke-width="2"/>
        <rect x="90" y="40" width="5" height="96" rx="2.5" fill="url(#chrome)" ${E}/>
        <rect x="105" y="40" width="5" height="96" rx="2.5" fill="url(#chrome)" ${E}/>
        <rect x="48" y="54" width="32" height="44" rx="4" fill="url(#dark-glass)"/>
        <rect x="58" y="74" width="12" height="16" rx="2" fill="#2c3a42"/>
        ${led(52, 46, 24, 5, "#7cc8ff")}
        ${light(34, 12, 132, 170, 7)}`;
    },
    washer(f, opts = {}) {
      const body = opts.narrow ? [56, 88] : [48, 104];
      const [x, w] = body, cx = x + w / 2;
      return `${shadow(cx, w / 2 + 6)}
        <rect x="${x}" y="30" width="${w}" height="152" rx="7" fill="url(#m-${f})" ${E}/>
        <rect x="${x}" y="30" width="${w}" height="26" rx="7" fill="#000" opacity=".05"/>
        <line x1="${x + 2}" y1="56" x2="${x + w - 2}" y2="56" stroke="${trim(f)}" stroke-width="1.5"/>
        <rect x="${x + 8}" y="38" width="${w * 0.28}" height="11" rx="2" fill="url(#m-${f})" ${E}/>
        ${led(cx - 4, 39, 22, 9, opts.dryer ? "#ffb86b" : "#6fe3a8")}
        ${knob(x + w - 14, 43, 7)}
        <circle cx="${cx}" cy="116" r="${w * 0.36}" fill="url(#chrome)" ${E}/>
        <circle cx="${cx}" cy="116" r="${w * 0.36 - 6}" fill="#2a3338"/>
        <circle cx="${cx}" cy="116" r="${w * 0.36 - 9}" fill="url(#porthole)"/>
        <path d="M ${cx - w * 0.2} ${100} a ${w * 0.26} ${w * 0.26} 0 0 1 ${w * 0.3} -8" stroke="#fff" stroke-opacity=".55" stroke-width="3" fill="none" stroke-linecap="round"/>
        <ellipse cx="${cx}" cy="128" rx="${w * 0.18}" ry="7" fill="#3c5562" opacity=".7"/>
        ${light(x, 30, w, 152, 7)}`;
    },
    dishwasher(f, opts = {}) {
      if (opts.builtin) {
        return `${shadow(100, 46)}
          <rect x="56" y="22" width="88" height="160" rx="3" fill="#d8c3a5"/>
          <rect x="56" y="22" width="88" height="160" rx="3" fill="url(#top-light)"/>
          <rect x="56" y="22" width="88" height="16" fill="url(#m-silver)" ${E}/>
          ${led(64, 27, 20, 6)}
          <circle cx="118" cy="30" r="2.4" fill="#2b3236"/><circle cx="126" cy="30" r="2.4" fill="#2b3236"/><circle cx="134" cy="30" r="2.4" fill="#2b3236"/>
          <rect x="80" y="48" width="40" height="5" rx="2.5" fill="url(#chrome)" ${E}/>
          <line x1="56" y1="110" x2="144" y2="110" stroke="#c2ab8a" stroke-width="1"/>`;
      }
      return `${shadow(100, 54)}
        <rect x="48" y="26" width="104" height="156" rx="6" fill="url(#m-${f})" ${E}/>
        <rect x="48" y="26" width="104" height="22" rx="6" fill="#000" opacity=".06"/>
        <line x1="50" y1="48" x2="150" y2="48" stroke="${trim(f)}" stroke-width="1.5"/>
        ${led(58, 33, 26, 8)}
        <circle cx="112" cy="37" r="3" fill="#2b3236"/><circle cx="123" cy="37" r="3" fill="#2b3236"/><circle cx="134" cy="37" r="3" fill="#2b3236"/>
        <rect x="70" y="58" width="60" height="6" rx="3" fill="url(#chrome)" ${E}/>
        <rect x="56" y="170" width="88" height="8" rx="1" fill="#1a1f22" opacity=".5"/>
        ${light(48, 26, 104, 156, 6)}`;
    },
    tv(f, opts = {}) {
      const pic = ["tv-picture", "tv-picture-1", "tv-picture-2"][opts.v || 0];
      return `${shadow(100, 70, 176)}
        <rect x="10" y="34" width="180" height="108" rx="3" fill="#0b0e10"/>
        <rect x="13" y="37" width="174" height="102" rx="1.5" fill="url(#${pic})"/>
        <path d="M13 120 C 50 96, 80 110, 110 92 S 170 80, 187 96 L187 139 L13 139 Z" fill="#0f2d3a" opacity=".55"/>
        <circle cx="146" cy="62" r="12" fill="#ffe7b0" opacity=".8"/>
        <rect x="13" y="37" width="174" height="102" fill="url(#screen-glare)"/>
        <rect x="94" y="142" width="12" height="26" fill="url(#m-graphite)"/>
        <path d="M60 176 L 140 176 L 132 168 L 68 168 Z" fill="url(#m-graphite)" ${E}/>`;
    },
    microwave(f) {
      return `${shadow(100, 80, 168)}
        <rect x="22" y="58" width="156" height="104" rx="7" fill="url(#m-${f})" ${E}/>
        <rect x="32" y="68" width="100" height="84" rx="5" fill="url(#dark-glass)"/>
        <rect x="32" y="68" width="100" height="84" rx="5" fill="url(#screen-glare)"/>
        <rect x="128" y="76" width="4" height="68" rx="2" fill="url(#chrome-v)"/>
        <rect x="140" y="66" width="30" height="88" rx="3" fill="${dark(f) ? "#15191b" : "#e4e8ea"}"/>
        ${led(144, 72, 22, 8, "#7cc8ff")}
        ${knob(155, 104, 9)}
        ${knob(155, 132, 7)}
        ${light(22, 58, 156, 104, 7)}
        <rect x="30" y="160" width="10" height="4" rx="1" fill="#1a1f22" opacity=".6"/><rect x="160" y="160" width="10" height="4" rx="1" fill="#1a1f22" opacity=".6"/>`;
    },
    robot(f) {
      return `${shadow(100, 80, 160)}
        <ellipse cx="100" cy="152" rx="74" ry="24" fill="${dark(f) ? "#0e1113" : "#b8c0c4"}"/>
        <rect x="26" y="134" width="148" height="18" fill="url(#m-${f})"/>
        <ellipse cx="100" cy="134" rx="74" ry="24" fill="url(#m-${f})" ${E}/>
        <ellipse cx="100" cy="134" rx="74" ry="24" fill="url(#top-light)"/>
        <path d="M 40 146 Q 100 170 160 146" stroke="#2b3236" stroke-opacity=".5" stroke-width="2" fill="none"/>
        <ellipse cx="100" cy="122" rx="20" ry="7" fill="${dark(f) ? "#2a3034" : "#dfe4e6"}" ${E}/>
        <rect x="80" y="114" width="40" height="8" fill="${dark(f) ? "#2a3034" : "#dfe4e6"}"/>
        <ellipse cx="100" cy="114" rx="20" ry="7" fill="url(#m-${f})" ${E}/>
        <circle cx="124" cy="138" r="3" fill="#6fe3a8"/>`;
    },
    canister(f) {
      return `${shadow(96, 74, 178)}
        <path d="M150 50 L 174 166" stroke="url(#chrome)" stroke-width="7" stroke-linecap="round"/>
        <path d="M160 166 L 192 166 L 194 176 L 156 176 Z" fill="#2a3034" ${E}/>
        <rect x="156" y="172" width="38" height="4" rx="1" fill="url(#accent)"/>
        <path d="M144 40 L 160 36 L 164 60 L 148 64 Z" fill="#2a3034"/>
        <path d="M100 120 C 92 70, 120 40, 150 52" stroke="#2f363a" stroke-width="8" fill="none" stroke-linecap="round"/>
        <path d="M100 120 C 92 70, 120 40, 150 52" stroke="#59636a" stroke-width="3" fill="none" stroke-dasharray="1.5 3.5"/>
        <path d="M24 172 C 20 128, 52 112, 90 114 C 122 116, 136 140, 132 172 Z" fill="url(#m-${f})" ${E}/>
        <path d="M24 172 C 20 128, 52 112, 90 114 C 122 116, 136 140, 132 172 Z" fill="url(#top-light)"/>
        <path d="M42 160 C 42 136, 60 126, 84 126 C 102 126, 112 140, 110 160 Z" fill="url(#bin)" ${E}/>
        <circle cx="34" cy="168" r="11" fill="#1e2427"/><circle cx="34" cy="168" r="5" fill="url(#chrome)"/>
        <circle cx="120" cy="168" r="11" fill="#1e2427"/><circle cx="120" cy="168" r="5" fill="url(#chrome)"/>
        <circle cx="98" cy="122" r="6" fill="#2b3236"/>`;
    },
    stick(f) {
      return `${shadow(92, 46, 182)}
        <path d="M58 176 L 128 176 L 126 166 C 110 160, 76 160, 62 166 Z" fill="#2a3034" ${E}/>
        <rect x="60" y="170" width="68" height="6" rx="2" fill="url(#accent)"/>
        <rect x="92" y="60" width="7" height="108" rx="3" fill="url(#chrome)" transform="rotate(6 95 114)"/>
        <rect x="92" y="22" width="34" height="52" rx="10" fill="url(#m-${f})" ${E}/>
        <rect x="96" y="32" width="26" height="34" rx="6" fill="url(#bin)" ${E}/>
        <path d="M126 30 C 146 32, 148 60, 130 66" stroke="#2a3034" stroke-width="7" fill="none" stroke-linecap="round"/>
        <circle cx="109" cy="28" r="2.5" fill="#6fe3a8"/>`;
    },
    handheld(f) {
      return `${shadow(100, 66, 156)}
        <path d="M34 128 L 70 112 L 150 112 C 170 112, 176 136, 160 146 L 70 146 L 34 138 Z" fill="url(#m-${f})" ${E}/>
        <path d="M34 128 L 70 112 L 150 112 C 170 112, 176 136, 160 146 L 70 146 L 34 138 Z" fill="url(#top-light)"/>
        <rect x="78" y="116" width="44" height="26" rx="6" fill="url(#bin)" ${E}/>
        <path d="M140 112 C 140 84, 172 84, 170 112" stroke="#2a3034" stroke-width="8" fill="none" stroke-linecap="round"/>
        <rect x="24" y="126" width="16" height="10" rx="2" fill="#2a3034"/>`;
    },
    kettle(f, opts = {}) {
      const body = opts.glass ? "url(#glass)" : `url(#m-${f})`;
      return `${shadow(98, 52, 178)}
        <ellipse cx="96" cy="170" rx="50" ry="9" fill="url(#m-${opts.glass ? "black" : f})" ${E}/>
        <rect x="46" y="160" width="100" height="10" fill="url(#m-${opts.glass ? "black" : f})"/>
        <path d="M58 160 L 64 70 C 66 56, 126 56, 128 70 L 134 160 Z" fill="${body}" ${E}/>
        ${opts.glass ? `<path d="M60 160 L 63 104 L 129 104 L 132 160 Z" fill="url(#water)"/>
          <path d="M60 160 L 63 104 L 129 104 L 132 160 Z" fill="${opts.glow ? "#3aa0ff" : "none"}" opacity=".25"/>
          <rect x="62" y="150" width="68" height="10" fill="url(#m-black)"/>` : ""}
        <path d="M64 70 L 40 54 L 48 50 L 72 64" fill="${opts.glass ? "url(#m-black)" : `url(#m-${f})`}" ${E}/>
        <path d="M128 76 C 160 74, 164 140, 132 146" stroke="${opts.glass ? "#1c2124" : dark(f) ? "#15191b" : "#c3cacd"}" stroke-width="11" fill="none" stroke-linecap="round"/>
        <ellipse cx="96" cy="64" rx="31" ry="7" fill="${opts.glass ? "#1c2124" : `url(#m-${f})`}" ${E}/>
        <rect x="88" y="54" width="16" height="7" rx="3" fill="#2a3034"/>
        ${opts.glass ? "" : `<path d="M66 70 L 72 156" stroke="#fff" stroke-opacity=".5" stroke-width="5" stroke-linecap="round"/>`}
        <circle cx="140" cy="136" r="2.5" fill="${opts.smart ? "#7cc8ff" : "#ff7a5c"}"/>`;
    },
    airfryer(f) {
      return `${shadow(100, 54, 180)}
        <path d="M52 176 L 56 50 C 58 30, 142 30, 144 50 L 148 176 Z" fill="url(#m-${f})" ${E}/>
        <path d="M52 176 L 56 50 C 58 30, 142 30, 144 50 L 148 176 Z" fill="url(#top-light)"/>
        <rect x="70" y="44" width="60" height="22" rx="5" fill="url(#dark-glass)"/>
        <text x="100" y="60" text-anchor="middle" font-family="sans-serif" font-size="11" fill="#7cc8ff">200°</text>
        <path d="M58 104 L 142 104 L 144 170 L 56 170 Z" fill="${dark(f) ? "#1b1f22" : "#e6eaec"}" ${E}/>
        <rect x="84" y="124" width="32" height="20" rx="6" fill="url(#m-black)" ${E}/>`;
    },
    grill(f) {
      return `${shadow(100, 74, 168)}
        <rect x="30" y="132" width="140" height="30" rx="8" fill="url(#m-${f})" ${E}/>
        <path d="M30 132 L 44 82 C 46 74, 154 74, 156 82 L 170 132 Z" fill="url(#m-${f})" ${E}/>
        <path d="M30 132 L 44 82 C 46 74, 154 74, 156 82 L 170 132 Z" fill="url(#top-light)"/>
        <path d="M40 132 L 160 132 L 158 138 L 42 138 Z" fill="#1b1f22"/>
        <rect x="64" y="66" width="72" height="12" rx="6" fill="url(#m-black)" ${E}/>
        <rect x="78" y="142" width="44" height="10" rx="2" fill="url(#dark-glass)"/>
        <circle cx="86" cy="147" r="2" fill="#ff7a5c"/><circle cx="96" cy="147" r="2" fill="#ffb86b"/><circle cx="106" cy="147" r="2" fill="#6fe3a8"/>`;
    },
    standmixer(f) {
      return `${shadow(100, 66, 180)}
        <rect x="40" y="160" width="124" height="18" rx="7" fill="url(#m-${f})" ${E}/>
        <rect x="128" y="62" width="30" height="104" rx="10" fill="url(#m-${f})" ${E}/>
        <path d="M60 46 C 60 34, 156 32, 160 50 L 160 82 C 120 86, 80 86, 60 74 Z" fill="url(#m-${f})" ${E}/>
        <path d="M60 46 C 60 34, 156 32, 160 50 L 160 82 C 120 86, 80 86, 60 74 Z" fill="url(#top-light)"/>
        <path d="M58 110 L 120 110 L 112 160 L 66 160 Z" fill="url(#chrome)" ${E}/>
        <ellipse cx="89" cy="110" rx="31" ry="6" fill="#aab2b6"/>
        <rect x="86" y="80" width="6" height="34" fill="#7b8388"/>
        ${knob(143, 92, 6)}`;
    },
    blender(f) {
      return `${shadow(100, 46, 180)}
        <path d="M60 178 L 64 132 L 136 132 L 140 178 Z" fill="url(#m-${f})" ${E}/>
        <circle cx="100" cy="156" r="10" fill="url(#chrome)" ${E}/>
        <path d="M68 132 L 62 30 L 138 30 L 132 132 Z" fill="url(#glass)" ${E}/>
        <path d="M66 132 L 63 90 L 137 90 L 134 132 Z" fill="url(#water)" opacity=".5"/>
        <path d="M84 126 L 116 118 M 84 118 L 116 126" stroke="#8b9398" stroke-width="3"/>
        <rect x="60" y="22" width="80" height="10" rx="3" fill="#20262a"/>
        <path d="M138 44 C 162 46, 160 104, 134 104" stroke="#20262a" stroke-width="8" fill="none" stroke-linecap="round"/>`;
    },
    immersion(f) {
      return `${shadow(100, 30, 182)}
        <rect x="84" y="14" width="32" height="74" rx="14" fill="url(#m-${f})" ${E}/>
        <rect x="84" y="14" width="32" height="74" rx="14" fill="url(#top-light)"/>
        <rect x="94" y="32" width="12" height="16" rx="5" fill="#2a3034"/>
        <rect x="93" y="86" width="14" height="66" fill="url(#chrome)" ${E}/>
        <path d="M78 176 C 78 156, 122 156, 122 176 Z" fill="url(#chrome)" ${E}/>
        <rect x="76" y="174" width="48" height="5" rx="2" fill="#7b8388"/>`;
    },
    coffee(f) {
      return `${shadow(100, 56, 182)}
        <rect x="50" y="20" width="100" height="160" rx="8" fill="url(#m-${f})" ${E}/>
        <rect x="50" y="20" width="100" height="160" rx="8" fill="url(#top-light)"/>
        <rect x="62" y="32" width="76" height="26" rx="4" fill="url(#dark-glass)"/>
        <circle cx="76" cy="45" r="5" fill="none" stroke="#e8c27a" stroke-width="1.5"/><circle cx="96" cy="45" r="5" fill="none" stroke="#e8c27a" stroke-width="1.5"/><circle cx="116" cy="45" r="5" fill="none" stroke="#7cc8ff" stroke-width="1.5"/>
        <rect x="58" y="70" width="84" height="88" rx="4" fill="#15191b"/>
        <rect x="86" y="72" width="28" height="14" rx="3" fill="url(#chrome)"/>
        <rect x="94" y="86" width="4" height="8" fill="#5a3a26"/><rect x="102" y="86" width="4" height="8" fill="#5a3a26"/>
        <path d="M84 128 L 116 128 L 112 150 L 88 150 Z" fill="#fbfbfb" ${E}/>
        <path d="M116 132 C 124 132, 124 144, 114 144" stroke="#fbfbfb" stroke-width="3" fill="none"/>
        <rect x="58" y="152" width="84" height="8" rx="2" fill="url(#chrome)"/>`;
    },
    multicooker(f) {
      return `${shadow(100, 64, 176)}
        <path d="M40 92 C 40 70, 160 70, 160 92 L 156 166 C 156 176, 44 176, 44 166 Z" fill="url(#m-${f})" ${E}/>
        <path d="M40 92 C 40 70, 160 70, 160 92 L 156 166 C 156 176, 44 176, 44 166 Z" fill="url(#top-light)"/>
        <path d="M36 92 C 36 54, 164 54, 164 92 Z" fill="url(#m-${f === "white" ? "silver" : f})" ${E}/>
        <rect x="76" y="50" width="48" height="10" rx="5" fill="#20262a"/>
        <rect x="68" y="112" width="64" height="30" rx="5" fill="url(#dark-glass)"/>
        <text x="100" y="132" text-anchor="middle" font-family="sans-serif" font-size="12" fill="#ffb86b">00:45</text>
        <circle cx="60" cy="150" r="4" fill="#2a3034"/><circle cx="140" cy="150" r="4" fill="#2a3034"/>`;
    },
    handmixer(f) {
      return `${shadow(92, 50, 180)}
        <path d="M44 64 C 44 40, 150 38, 160 60 L 160 92 L 50 96 Z" fill="url(#m-${f})" ${E}/>
        <path d="M44 64 C 44 40, 150 38, 160 60 L 160 92 L 50 96 Z" fill="url(#top-light)"/>
        <path d="M70 52 C 80 20, 140 20, 150 50" stroke="${dark(f) ? "#15191b" : "#c3cacd"}" stroke-width="12" fill="none" stroke-linecap="round"/>
        <rect x="76" y="96" width="5" height="54" fill="url(#chrome)"/><rect x="104" y="96" width="5" height="54" fill="url(#chrome)"/>
        <path d="M68 150 C 68 178, 90 178, 90 150 Z" fill="none" stroke="url(#chrome)" stroke-width="4"/>
        <path d="M96 150 C 96 178, 118 178, 118 150 Z" fill="none" stroke="url(#chrome)" stroke-width="4"/>
        <rect x="116" y="58" width="18" height="10" rx="5" fill="#2a3034"/>`;
    },
    toaster(f) {
      return `${shadow(100, 66, 176)}
        <rect x="74" y="54" width="22" height="26" rx="3" fill="url(#bread)"/><rect x="104" y="50" width="22" height="30" rx="3" fill="url(#bread)"/>
        <path d="M36 172 L 36 92 C 36 74, 164 74, 164 92 L 164 172 Z" fill="url(#m-${f})" ${E}/>
        <path d="M36 172 L 36 92 C 36 74, 164 74, 164 92 L 164 172 Z" fill="url(#top-light)"/>
        <rect x="70" y="78" width="28" height="5" rx="2" fill="#15191b"/><rect x="102" y="78" width="28" height="5" rx="2" fill="#15191b"/>
        <rect x="150" y="100" width="18" height="8" rx="3" fill="#20262a"/>
        ${knob(100, 140, 9)}`;
    },
    iron(f, opts = {}) {
      const base = opts.station ? `
        <rect x="18" y="138" width="164" height="38" rx="12" fill="url(#m-${f})" ${E}/>
        <rect x="18" y="138" width="164" height="38" rx="12" fill="url(#top-light)"/>
        <rect x="30" y="146" width="40" height="22" rx="6" fill="url(#bin)" ${E}/>
        <path d="M168 140 C 186 110, 176 90, 160 96" stroke="#2a3034" stroke-width="4" fill="none"/>` : "";
      const y = opts.station ? -40 : 0;
      return `${shadow(100, 72, opts.station ? 182 : 168)}${base}
        <g transform="translate(0 ${y})">
          <path d="M30 160 C 40 128, 90 118, 168 124 L 172 160 Z" fill="url(#accent)" ${E}/>
          <path d="M28 160 L 174 160 L 172 166 L 34 166 Z" fill="url(#chrome)"/>
          <path d="M70 124 C 76 90, 150 88, 158 124" stroke="${dark(f) ? "#15191b" : "#eef1f2"}" stroke-width="14" fill="none" stroke-linecap="round"/>
          <path d="M70 124 C 76 90, 150 88, 158 124" stroke="#000" stroke-opacity=".12" stroke-width="14" fill="none" stroke-linecap="round"/>
          <circle cx="120" cy="140" r="5" fill="#ffffff" opacity=".8"/>
        </g>`;
    },
    toothbrush() {
      return `${shadow(100, 26, 182)}
        <path d="M86 180 L 88 160 L 112 160 L 114 180 Z" fill="url(#m-white)" ${E}/>
        <rect x="90" y="56" width="20" height="108" rx="10" fill="url(#m-black)" ${E}/>
        <rect x="96" y="96" width="8" height="14" rx="4" fill="#cfd5d8"/>
        <rect x="96" y="20" width="8" height="40" rx="4" fill="url(#m-white)" ${E}/>
        <rect x="92" y="14" width="16" height="12" rx="4" fill="#7cc8ff"/>`;
    },
    purifier(f) {
      return `${shadow(100, 46, 182)}
        <rect x="62" y="24" width="76" height="156" rx="12" fill="url(#m-${f})" ${E}/>
        <rect x="62" y="24" width="76" height="156" rx="12" fill="url(#top-light)"/>
        <ellipse cx="100" cy="28" rx="34" ry="5" fill="#2a3034"/>
        ${Array.from({ length: 9 }, (_, r) => Array.from({ length: 6 }, (_, c) => `<circle cx="${74 + c * 10.4}" cy="${100 + r * 8.4}" r="1.6" fill="#2b3236" opacity=".5"/>`).join("")).join("")}
        <circle cx="100" cy="58" r="12" fill="none" stroke="#6fe3a8" stroke-width="2"/>
        <text x="100" y="62" text-anchor="middle" font-family="sans-serif" font-size="10" fill="#2b3236">12</text>`;
    },
    generic(f) {
      return `${shadow(100, 50)}
        <rect x="52" y="60" width="96" height="120" rx="10" fill="url(#m-${f})" ${E}/>
        ${light(52, 60, 96, 120, 10)}
        ${led(72, 76, 56, 10)}`;
    }
  };

  // вид товара по названию (порядок важен: «Стирально-сушильная» раньше «Стиральная»)
  const KINDS = [
    [/side-by-side/i, "sidebyside"],
    [/холодильник/i, "fridge"],
    [/стирально-сушильная/i, "washer", { dryer: true }],
    [/стиральная/i, "washer"],
    [/посудомоечная.*встраив|встраив.*посудомоечн/i, "dishwasher", { builtin: true }],
    [/посудомоечная/i, "dishwasher"],
    [/телевизор/i, "tv"],
    [/микроволнов/i, "microwave"],
    [/робот-пылесос/i, "robot"],
    [/ручной пылесос/i, "handheld"],
    [/вертикальн|беспроводной пылесос/i, "stick"],
    [/пылесос/i, "canister"],
    [/чайник/i, "kettle"],
    [/аэрогриль/i, "airfryer"],
    [/электрогриль|гриль/i, "grill"],
    [/кухонная машина/i, "standmixer"],
    [/погружной блендер/i, "immersion"],
    [/блендер/i, "blender"],
    [/кофемашина/i, "coffee"],
    [/мультиварка/i, "multicooker"],
    [/миксер/i, "handmixer"],
    [/тостер/i, "toaster"],
    [/парогенератор/i, "iron", { station: true }],
    [/утюг/i, "iron"],
    [/зубная щ/i, "toothbrush"],
    [/очиститель воздуха/i, "purifier"]
  ];
  const BIG = new Set(["fridge", "sidebyside", "washer", "dishwasher", "microwave"]);

  function finishFor(kind, p) {
    const id = Number(p.id) || 0;
    const big = ["silver", "white", "black", "white", "graphite"];
    const small = ["white", "black", "silver", "graphite", "white"];
    return (BIG.has(kind) ? big : small)[id % 5];
  }

  return function art(p) {
    const name = String(p.name || "");
    const desc = String(p.description || "") + " " + name;
    let kind = "generic", opts = {};
    for (const [re, k, o] of KINDS) { if (re.test(name)) { kind = k; opts = { ...(o || {}) }; break; } }
    if (kind === "washer" && /узк/i.test(desc)) opts.narrow = true;
    if (kind === "tv") opts.v = (Number(p.id) || 0) % 3;
    if (kind === "kettle") {
      if (/стекл/i.test(desc)) opts.glass = true;
      if (/подсвет/i.test(desc)) opts.glow = true;
      if (/умный|смартфон/i.test(desc)) opts.smart = true;
    }
    const f = finishFor(kind, p);
    return `<svg class="art" viewBox="0 0 200 200" role="img" aria-label="${name.replace(/"/g, "&quot;")}">${draw[kind](f, opts)}</svg>`;
  };
})();
