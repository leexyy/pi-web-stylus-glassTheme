#!/usr/bin/env node
/*
 * 压缩壁纸:任意原图 → 体积受控的 webp,供 src/generate.sh 内联成 base64。
 * 目的是让用户只提供原图,不用自己先压。
 *
 * 用法:
 *   node tools/compress-wallpaper.mjs <输入图> <输出.webp> [--max-width 1920] [--quality 80]
 * 退出码:
 *   0 = 成功(输出文件已写好);非 0 = 失败(调用方回退到原图)
 *
 * 说明:
 *   - 按 EXIF 方向摆正(rotate());
 *   - 宽度超过 max-width 时等比缩小(高度不限);
 *   - 统一输出 webp(lossy),体积通常只有原 jpg/png 的 1/5 ~ 1/20;
 *   - 进度信息打到 stderr,不污染 stdout。
 */
import { statSync } from "node:fs";
import sharp from "./lib/sharp.mjs";

const argv = process.argv.slice(2);
let src = null, dst = null, maxWidth = 1920, quality = 80;
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a === "--max-width") maxWidth = Number(argv[++i]);
  else if (a === "--quality") quality = Number(argv[++i]);
  else if (!src) src = a;
  else if (!dst) dst = a;
}
if (!src || !dst) {
  console.error("用法: node tools/compress-wallpaper.mjs <输入图> <输出.webp> [--max-width 1920] [--quality 80]");
  process.exit(2);
}

const kb = (n) => `${(n / 1024).toFixed(0)}KB`;
const mb = (n) => `${(n / 1048576).toFixed(2)}MB`;
const fmt = (n) => (n >= 1048576 ? mb(n) : kb(n));

try {
  const meta = await sharp(src).metadata();
  const before = statSync(src).size;

  let pipe = sharp(src).rotate(); // 先按 EXIF 摆正
  if (meta.width && meta.width > maxWidth) pipe = pipe.resize({ width: maxWidth });

  await pipe.webp({ quality, effort: 4 }).toFile(dst);

  const after = statSync(dst).size;
  console.error(
    `压缩壁纸:${fmt(before)} → ${fmt(after)}` +
    `  (${meta.width ?? "?"}x${meta.height ?? "?"} → 宽≤${maxWidth}, webp q${quality})`
  );
} catch (e) {
  console.error("compress-wallpaper: " + (e && e.message ? e.message : e));
  process.exit(1);
}
