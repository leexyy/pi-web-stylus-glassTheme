// 路径全部相对本文件解析,项目整体挪位置也不用改代码。
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
// sharp 由 ./lib/sharp.mjs 统一解析(本地依赖 → 全局 pi-web 自带 → SHARP= 覆盖)。
import sharp from "./lib/sharp.mjs";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");

// 用法:
//   老用法(向后兼容): node tools/preview.mjs <tint> <scrim> <blurpx> <posX> <outfile>
//   新用法:            node tools/preview.mjs <tint> <scrim> <blurpx> <posX> <panelA> <toolA> <bubbleA> <userA> <outfile>
// 各 A 默认 = src/generate.sh 的派生系数
//   panelA = tint × 0.65, toolA = tint × 1.05, bubbleA = tint × 1.15, userA = tint × 1.30
// WALL 可通过环境变量覆盖: WALL=/path/to/img node tools/preview.mjs ...
// argv.length: 老=7, 中(panel+tool)=9, 新(panel+tool+bubble+user)=11
// MDN: CSS blur(<length>) 的 length 就是高斯标准差,所以 blurpx 直接对应 --piw-blur
const argv = process.argv;
const WALL = process.env.WALL || join(ROOT, "assets/source/1.jpg");
const tint = Number(argv[2]), scrim = Number(argv[3]), blur = Number(argv[4]), posX = Number(argv[5]);
const isMid = argv.length >= 9;
const isFull = argv.length >= 11;
const OUT = isFull ? argv[10] : isMid ? argv[8] : argv[6];
const panelA   = isMid  ? Number(argv[6]) : tint * 0.65;
const toolA    = isMid  ? Number(argv[7]) : tint * 1.05;
const bubbleA  = isFull ? Number(argv[8]) : tint * 1.15;
const userA    = isFull ? Number(argv[9]) : tint * 1.30;
const W = 1600, H = 900;
const clamp = (v) => Math.min(1, Math.max(0, v));
const mul = (f) => clamp(tint * f).toFixed(2);
const bg = mul(1), panel = clamp(panelA).toFixed(2), tool = clamp(toolA).toFixed(2), assistant = clamp(bubbleA).toFixed(2), user = clamp(userA).toFixed(2);

const m = await sharp(WALL).metadata();
const scale = Math.max(W / m.width, H / m.height);
const rw = Math.round(m.width * scale), rh = Math.round(m.height * scale);
const crop = sharp(await sharp(WALL).resize(rw, rh).toBuffer())
	.extract({ left: Math.round((rw - W) * posX), top: Math.round((rh - H) * 0.5), width: W, height: H });
const base = await crop.blur(blur).modulate({ saturation: 1.5 }).toBuffer();

// 叠层顺序与 CSS 一致:纱 -> body(--bg) -> 侧栏(--bg-panel) -> 内容面/气泡
const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}">
 <rect width="${W}" height="${H}" fill="#ffffff" fill-opacity="${scrim}"/>
 <rect width="${W}" height="${H}" fill="#ffffff" fill-opacity="${bg}"/>
 <rect x="0" y="0" width="400" height="${H}" fill="#ffffff" fill-opacity="${panel}"/>
 <line x1="400.5" y1="0" x2="400.5" y2="${H}" stroke="#000000" stroke-opacity="0.10"/>
 <rect x="401" y="0" width="${W - 401}" height="52" fill="#ffffff" fill-opacity="${panel}"/>
 <line x1="401" y1="52.5" x2="${W}" y2="52.5" stroke="#000000" stroke-opacity="0.10"/>
 <text x="20" y="40" font-family="DejaVu Sans" font-size="13" fill="#14202e">sidebar --bg-panel ${panel}</text>
 <text x="424" y="33" font-family="DejaVu Sans" font-size="14" fill="#14202e">topbar --bg-panel ${panel}</text>
 <rect x="770" y="110" width="800" height="150" rx="12" fill="#ffffff" fill-opacity="${assistant}"/>
 <rect x="770" y="110" width="800" height="150" rx="12" fill="none" stroke="#000000" stroke-opacity="0.10"/>
 <text x="798" y="152" font-family="DejaVu Sans" font-size="17" fill="#14202e">assistant-bg ${assistant} - text #14202e</text>
 <text x="798" y="184" font-family="DejaVu Sans" font-size="14" fill="#262e3a">muted #262e3a - The quick brown fox 0123456789</text>
 <text x="798" y="216" font-family="DejaVu Sans" font-size="14" fill="#2b333f">dim #2b333f - 正文玻璃最厚,保证阅读comfort</text>
 <rect x="770" y="300" width="560" height="86" rx="8" fill="#ffffff" fill-opacity="${tool}"/>
 <text x="788" y="332" font-family="DejaVu Sans" font-size="13" fill="#14202e">tool block --tool-bg ${tool}</text>
 <text x="788" y="362" font-family="DejaVu Sans" font-size="12" fill="#262e3a">$ npm i -g @agegr/pi-web</text>
 <rect x="1350" y="300" width="220" height="86" rx="12" fill="#ffffff" fill-opacity="${user}"/>
 <text x="1372" y="350" font-family="DejaVu Sans" font-size="14" fill="#14202e">user ${user}</text>
 <rect x="770" y="760" width="700" height="86" rx="14" fill="#ffffff" fill-opacity="${assistant}"/>
 <rect x="770" y="760" width="700" height="86" rx="14" fill="none" stroke="#000000" stroke-opacity="0.10"/>
 <text x="796" y="800" font-family="DejaVu Sans" font-size="15" fill="#262e3a">composer --bg ${bg}</text>
 <text x="796" y="826" font-family="DejaVu Sans" font-size="13" fill="#2b333f">tint ${tint} / scrim ${scrim} / blur ${blur}px / posX ${posX}</text>
</svg>`;

await sharp(base).composite([{ input: Buffer.from(svg), top: 0, left: 0 }]).png().toFile(OUT);
console.log(`OK ${OUT}  → bg ${bg} panel ${panel} assistant ${assistant} tool ${tool} user ${user}`);
