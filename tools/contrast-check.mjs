// 路径全部相对本文件解析,项目整体挪位置也不用改代码。
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
// sharp 由 ./lib/sharp.mjs 统一解析(本地依赖 → 全局 pi-web 自带 → SHARP= 覆盖)。
import sharp from "./lib/sharp.mjs";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");

// 用法: node .pi-glass-check.mjs <tint> <scrim> <blur> <posX> [preview.png]
//      面板底色默认按纯白算;底色被壁纸染色时用 BASE=#rrggbb 传实际底色,结果才准
// 1) 复刻 CSS 的合成顺序:壁纸 -> 纱 -> 模糊/饱和 -> body纱(--bg) -> 面板
// 2) 量出各层的实际像素范围,再算 WCAG 对比度,判断文字还读不读得出来
const tint = Number(process.argv[2]), scrim = Number(process.argv[3]), blur = Number(process.argv[4]), posX = Number(process.argv[5]);
const OUT = process.argv[6];
const WALL = process.env.WALL || join(ROOT, "assets/source/1.jpg");
const W = 1600, H = 900;
const clamp = (v) => Math.min(1, Math.max(0, v));
const mul = (f) => clamp(tint * f);
const A = {
	bg: Number(process.env.A_BG ?? mul(1)),
	panel: Number(process.env.A_PANEL ?? mul(0.65)),
	assistant: Number(process.env.A_ASSISTANT ?? mul(1.15)),
	tool: Number(process.env.A_TOOL ?? mul(1.05)),
	user: Number(process.env.A_USER ?? mul(1.3)),
};

const lin = (c) => (c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4);
const lum = ([r, g, b]) => 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b);
const hex = (h) => { const n = parseInt(h.slice(1), 16); return [(n >> 16 & 255) / 255, (n >> 8 & 255) / 255, (n & 255) / 255]; };
const BASE = process.env.BASE || "#ffffff";
const BASE_RGB = hex(BASE).map((v) => v * 255);
const ratio = (L1, L2) => { const a = Math.max(L1, L2), b = Math.min(L1, L2); return (a + 0.05) / (b + 0.05); };

// ── 合成 ────────────────────────────────────────────────────
const m = await sharp(WALL).metadata();
const scale = Math.max(W / m.width, H / m.height);
const rw = Math.round(m.width * scale), rh = Math.round(m.height * scale);
const crop = sharp(await sharp(WALL).resize(rw, rh).toBuffer())
	.extract({ left: Math.round((rw - W) * posX), top: Math.round((rh - H) * 0.5), width: W, height: H });
const blurred = await crop.blur(blur).modulate({ saturation: 1.5 }).raw().toBuffer({ resolveWithObject: true });
const px = (buf, i, a) => { for (let k = 0; k < 3; k++) buf[i + k] = buf[i + k] * (1 - a) + BASE_RGB[k] * a; };
const copy = () => Buffer.from(blurred.data);

// 纱(白) + body(--bg)
const canvas = copy();
for (let i = 0; i < canvas.length; i += 3) { px(canvas, i, scrim); px(canvas, i, A.bg); }
// 侧栏 / 气泡 / 工具块
const panel = copy(); for (let i = 0; i < panel.length; i += 3) { px(panel, i, scrim); px(panel, i, A.bg); px(panel, i, A.panel); }
const bubble = copy(); for (let i = 0; i < bubble.length; i += 3) { px(bubble, i, scrim); px(bubble, i, A.bg); px(bubble, i, A.assistant); }

const range = (buf) => {
	let lo = [255, 255, 255], hi = [0, 0, 0], loL = 1, hiL = 0;
	for (let i = 0; i < buf.length; i += 3) {
		const L = lum([buf[i] / 255, buf[i + 1] / 255, buf[i + 2] / 255]);
		if (L < loL) { loL = L; lo = [buf[i], buf[i + 1], buf[i + 2]]; }
		if (L > hiL) { hiL = L; hi = [buf[i], buf[i + 1], buf[i + 2]]; }
	}
	return { loL, lo, hiL, hi };
};

const TEXT = [
	["--text #1a1a1a", "#1a1a1a"],
	["muted #515c6b(原)", "#515c6b"],
	["muted #232a33(新)", "#232a33"],
	["dim #272e38(新)", "#272e38"],
];
const layers = [["正文底 --bg", range(canvas)], ["侧栏 --bg-panel", range(panel)], ["气泡 --assistant-bg", range(bubble)]];

console.log(`\ntint=${tint} scrim=${scrim} blur=${blur}px posX=${posX} base=${BASE}  →  bg ${A.bg.toFixed(2)} panel ${A.panel.toFixed(2)} assistant ${A.assistant.toFixed(2)} tool ${A.tool.toFixed(2)} user ${A.user.toFixed(2)}`);
for (const [name, r] of layers) {
	console.log(`  ${name.padEnd(20)} 最暗 rgb(${r.lo.join(",")}) Y=${r.loL.toFixed(3)}   最亮 rgb(${r.hi.join(",")}) Y=${r.hiL.toFixed(3)}`);
}
console.log("  对比度(按各层最暗处,最坏情况):");
for (const [label, hexv] of TEXT) {
	const Lt = lum(hex(hexv));
	const cells = layers.map(([, r]) => `${ratio(Lt, r.loL).toFixed(1)}:1`);
	console.log(`    ${label.padEnd(18)} 正文底 ${cells[0].padStart(6)}  侧栏 ${cells[1].padStart(6)}  气泡 ${cells[2].padStart(6)}`);
}

if (OUT) {
	const svgFree = await sharp(canvas, { raw: { width: W, height: H, channels: 3 } }).png().toBuffer();
	await sharp(svgFree).toFile(OUT);
	console.log("  已输出铺底图(不含面板):", OUT);
}
