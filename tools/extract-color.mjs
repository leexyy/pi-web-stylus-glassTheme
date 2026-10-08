#!/usr/bin/env node
/*
 * 从壁纸里取「基调色」,供 src/generate.sh 把面板底色染向壁纸,
 * 让整个 UI 的色系和壁纸保持一致(而不是固定的白/灰玻璃)。
 *
 * 用法:
 *   node tools/extract-color.mjs <图片> [--saturation-cap 0.35] [--light-value 0.92] [--dark-value 0.18]
 * 输出:
 *   两行 #rrggbb(第一行=浅色主题用的高亮基调,第二行=深色主题用的暗基调);
 *   失败时打印错误到 stderr 并以非 0 退出。
 *
 * 做法:缩到 48x48 取平均色 → 取它的色相 H 和饱和度 S(压到 saturation-cap),
 *      然后用固定的明度分别生成浅色基调(light-value)和深色基调(dark-value)。
 *      这样色相跟壁纸走,但明度是可控的:浅色主题不会被壁纸的暗部拉灰、
 *      深色主题也不会被洗亮,文字对比度不会因此变差。
 */
import sharp from "./lib/sharp.mjs";

function parseArgs(argv) {
  const out = { img: null, saturationCap: 0.35, lightValue: 0.92, darkValue: 0.18 };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--saturation-cap") out.saturationCap = Number(argv[++i]);
    else if (a === "--light-value") out.lightValue = Number(argv[++i]);
    else if (a === "--dark-value") out.darkValue = Number(argv[++i]);
    else if (!out.img) out.img = a;
  }
  return out;
}

const opt = parseArgs(process.argv.slice(2));
if (!opt.img) {
  console.error("用法: node tools/extract-color.mjs <图片> [--saturation-cap 0.35] [--light-value 0.92] [--dark-value 0.18]");
  process.exit(2);
}

const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));

// HSV → #rrggbb
function hsvHex(h, s, v) {
  const c = v * s;
  const x = c * (1 - Math.abs(((h / 60) % 2) - 1));
  const m = v - c;
  let rr = 0, gg = 0, bb = 0;
  if (h < 60) [rr, gg, bb] = [c, x, 0];
  else if (h < 120) [rr, gg, bb] = [x, c, 0];
  else if (h < 180) [rr, gg, bb] = [0, c, x];
  else if (h < 240) [rr, gg, bb] = [0, x, c];
  else if (h < 300) [rr, gg, bb] = [x, 0, c];
  else [rr, gg, bb] = [c, 0, x];
  return (
    "#" +
    [rr, gg, bb]
      .map((u) => Math.round((u + m) * 255))
      .map((u) => u.toString(16).padStart(2, "0"))
      .join("")
  );
}

try {
  const { data, info } = await sharp(opt.img)
    .resize(48, 48, { fit: "cover" })
    .removeAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });

  let r = 0, g = 0, b = 0;
  const n = info.width * info.height;
  for (let i = 0; i < data.length; i += info.channels) {
    r += data[i];
    g += data[i + 1];
    b += data[i + 2];
  }
  r = Math.round(r / n);
  g = Math.round(g / n);
  b = Math.round(b / n);

  // RGB → 色相/饱和度(明度丢掉,后面按主题深浅重新给)
  const rn = r / 255, gn = g / 255, bn = b / 255;
  const mx = Math.max(rn, gn, bn);
  const mn = Math.min(rn, gn, bn);
  const d = mx - mn;
  let h = 0;
  if (d > 0) {
    if (mx === rn) h = 60 * (((gn - bn) / d) % 6);
    else if (mx === gn) h = 60 * ((bn - rn) / d + 2);
    else h = 60 * ((rn - gn) / d + 4);
  }
  if (h < 0) h += 360;

  const s = clamp(mx > 0 ? d / mx : 0, 0, opt.saturationCap);

  console.log(hsvHex(h, s, opt.lightValue));
  console.log(hsvHex(h, s, opt.darkValue));
} catch (e) {
  console.error("extract-color: " + (e && e.message ? e.message : e));
  process.exit(1);
}
