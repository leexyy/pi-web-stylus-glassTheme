// 路径全部相对本文件解析,项目整体挪位置也不用改代码。
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
// sharp 由 ./lib/sharp.mjs 统一解析(本地依赖 → 全局 pi-web 自带 → SHARP= 覆盖)。
import sharp from "./lib/sharp.mjs";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");

async function render({ tint, scrim, blur, posX, panelA, toolA, bubbleA, userA, theme }) {
  const WALL = process.env.WALL || join(ROOT, "assets/source/1.jpg");
  const W = 800, H = 900;
  const clamp = (v) => Math.min(1, Math.max(0, v));
  const bg = clamp(tint * 1.0).toFixed(2);
  const panel = clamp(panelA).toFixed(2);
  const tool = clamp(toolA).toFixed(2);
  const assistant = clamp(bubbleA).toFixed(2);
  const user = clamp(userA).toFixed(2);
  const m = await sharp(WALL).metadata();
  const scale = Math.max(W / m.width, H / m.height);
  const rw = Math.round(m.width * scale), rh = Math.round(m.height * scale);
  const crop = sharp(await sharp(WALL).resize(rw, rh).toBuffer())
    .extract({ left: Math.round((rw - W) * posX), top: Math.round((rh - H) * 0.5), width: W, height: H });
  const base = await crop.blur(blur).modulate({ saturation: 1.5 }).jpeg({ quality: 85 }).toBuffer();
  const isDark = theme === "dark";
  const scrimCol = isDark ? `rgba(10,12,16,${scrim})` : `rgba(255,255,255,${scrim})`;
  const panelCol = isDark ? `rgba(36,36,36,${panel})` : `rgba(245,245,245,${panel})`;
  const surfCol  = isDark ? `rgba(26,26,26,${bg})` : `rgba(255,255,255,${bg})`;
  const assCol   = isDark ? `rgba(26,26,26,${assistant})` : `rgba(255,255,255,${assistant})`;
  const toolCol  = isDark ? `rgba(34,34,34,${tool})` : `rgba(249,250,251,${tool})`;
  const userCol  = isDark ? `rgba(41,41,41,${user})` : `rgba(239,246,255,${user})`;
  const textCol  = isDark ? "#ececec" : "#14202e";
  const mutedCol = isDark ? "#c2c2c2" : "#262e3a";
  const border   = isDark ? "rgba(255,255,255,0.14)" : "rgba(0,0,0,0.10)";
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}">
 <image href="data:image/jpeg;base64,${base.toString('base64')}" width="${W}" height="${H}"/>
 <rect width="${W}" height="${H}" fill="${scrimCol}"/>
 <rect width="${W}" height="${H}" fill="${surfCol}"/>
 <rect x="0" y="0" width="200" height="${H}" fill="${panelCol}"/>
 <rect x="200" y="0" width="${W-200}" height="26" fill="${panelCol}"/>
 <rect x="220" y="40" width="560" height="22" rx="4" fill="${toolCol}"/>
 <rect x="220" y="76" width="560" height="100" rx="6" fill="${assCol}"/>
 <rect x="220" y="76" width="560" height="100" rx="6" fill="none" stroke="${border}"/>
 <rect x="220" y="200" width="380" height="60" rx="6" fill="${toolCol}"/>
 <rect x="610" y="200" width="170" height="60" rx="6" fill="${userCol}"/>
 <rect x="610" y="200" width="170" height="60" rx="6" fill="none" stroke="${border}"/>
 <rect x="220" y="280" width="560" height="200" rx="6" fill="${surfCol}"/>
 <rect x="220" y="280" width="560" height="200" rx="6" fill="none" stroke="${border}"/>
 <text x="14" y="20" font-family="sans-serif" font-size="11" fill="${textCol}">panel ${panel}</text>
 <text x="210" y="18" font-family="sans-serif" font-size="10" fill="${textCol}">topbar ${panel}</text>
 <text x="226" y="55" font-family="sans-serif" font-size="10" fill="${mutedCol}">tool ${tool}</text>
 <text x="232" y="118" font-family="sans-serif" font-size="13" fill="${textCol}">bubble ${assistant} - readable text</text>
 <text x="232" y="148" font-family="sans-serif" font-size="11" fill="${mutedCol}">muted - The quick brown fox</text>
 <text x="232" y="235" font-family="sans-serif" font-size="11" fill="${textCol}">tool block ${tool}</text>
 <text x="618" y="235" font-family="sans-serif" font-size="11" fill="${textCol}">user ${user}</text>
 <text x="232" y="320" font-family="sans-serif" font-size="14" fill="${textCol}">main chat --bg ${bg}</text>
 <text x="232" y="350" font-family="sans-serif" font-size="11" fill="${mutedCol}">无 backdrop-filter · 直接看到壁纸细节</text>
</svg>`;
  return { svg: Buffer.from(svg), bg, panel, tool, assistant, user };
}

async function composite(outFile, theme) {
  const old = await render({ tint: 0.56, scrim: 0.45, blur: 12, posX: 0.45, panelA: 0.92, toolA: 0.95, bubbleA: 0.56 * 1.15, userA: 0.56 * 1.30, theme });
  const next = await render({ tint: 0.56, scrim: 0.45, blur: 12, posX: 0.45, panelA: 0.55, toolA: 0.50, bubbleA: 0.35, userA: 0.55, theme });
  const W = 1600, H = 900;
  const isDark = theme === "dark";
  const divider = isDark ? "rgba(255,255,255,0.4)" : "rgba(0,0,0,0.4)";
  const labelBg = isDark ? "rgba(0,0,0,0.7)" : "rgba(255,255,255,0.92)";
  const labelFg = isDark ? "#ececec" : "#14202e";
  const oldPng = await sharp(old.svg).png().toBuffer();
  const nextPng = await sharp(next.svg).png().toBuffer();
  const final = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}">
 <image href="data:image/png;base64,${oldPng.toString('base64')}" x="0" y="0" width="800" height="${H}"/>
 <image href="data:image/png;base64,${nextPng.toString('base64')}" x="800" y="0" width="800" height="${H}"/>
 <line x1="800" y1="0" x2="800" y2="${H}" stroke="${divider}" stroke-width="2"/>
 <rect x="14" y="14" width="320" height="34" fill="${labelBg}"/>
 <text x="26" y="36" font-family="sans-serif" font-size="14" font-weight="600" fill="${labelFg}">① 上一版 panel=0.92</text>
 <rect x="820" y="14" width="380" height="34" fill="${labelBg}"/>
 <text x="832" y="36" font-family="sans-serif" font-size="14" font-weight="600" fill="${labelFg}">② 强毛玻璃 panel=0.55 +blur</text>
</svg>`;
  await sharp(Buffer.from(final)).png().toFile(outFile);
  console.log(outFile, "ok", `old=${JSON.stringify({b:old.bg,p:old.panel,t:old.tool,a:old.assistant})}  new=${JSON.stringify({b:next.bg,p:next.panel,t:next.tool,a:next.assistant})}`);
}

await composite(join(ROOT, "tools/shots/preview-compare-light.png"), "light");
await composite(join(ROOT, "tools/shots/preview-compare-dark.png"), "dark");
