// 统一的 sharp 加载器(所有构建/预览脚本共用)。
//
// 解析顺序:
//   1. 环境变量 SHARP=<模块路径或包名>        —— 手动指定,优先级最高
//   2. 项目本地 node_modules/sharp            —— npm i sharp 之后
//   3. 全局安装的 @agegr/pi-web 自带的 sharp  —— 只要装了 pi-web 就无需另装依赖
//
// 找不到时给出明确提示并以非 0 退出,避免各脚本各写一份路径。
import { existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
// 全局 node_modules 与当前 node 可执行文件同级:
//   <node>/bin/node  →  <node>/lib/node_modules
const GLOBAL_MODULES = resolve(dirname(process.execPath), "..", "lib", "node_modules");

const candidates = [
	process.env.SHARP,
	"sharp",
	join(ROOT, "node_modules", "sharp", "lib", "index.js"),
	join(GLOBAL_MODULES, "@agegr", "pi-web", "node_modules", "sharp", "dist", "index.mjs"),
].filter(Boolean);

let sharp = null;
for (const spec of candidates) {
	const isPath = spec.startsWith("/") || spec.startsWith(".");
	if (isPath && !existsSync(spec)) continue;
	try {
		sharp = (await import(isPath ? pathToFileURL(spec).href : spec)).default;
		break;
	} catch {
		/* 换下一个候选 */
	}
}

if (!sharp) {
	console.error(
		"找不到 sharp。请任选其一:\n" +
			"  · npm i -D sharp\n" +
			"  · SHARP=/绝对/路径/到/sharp/dist/index.mjs <命令>\n" +
			"  · 全局安装 @agegr/pi-web(其自带的 sharp 会被自动复用)"
	);
	process.exit(1);
}

export default sharp;
