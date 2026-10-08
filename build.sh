#!/usr/bin/env bash
#
# 一键生成 pi-web 的 Stylus 主题 CSS → output/pi-web-theme.css
#
#   ./build.sh                 用下面的默认外观(默认壁纸 assets/source/1.jpg + 当前调好的参数)
#   ./build.sh --tint 0.25     覆盖任意参数(追加在默认之后,同名以最后一次为准)
#   ./build.sh --scrim 0.60 --tint-panel 0.40 --position "45% center"
#   ./build.sh --base-mix 0.35 让玻璃跟着壁纸色相(默认 0 = 全中性)
#
# 换壁纸(用 WALLPAPER 环境变量,其它参数全部保留):
#   WALLPAPER=/绝对/路径/我的壁纸.jpg ./build.sh     # 直接给原图,构建时自动压成 webp
#   WALLPAPER=/绝对/路径/图.png ./build.sh             # 相对路径按项目根算
# 压缩结果缓存在 .cache/<名字>.webp;源图没变就不重复压。
#
# 参数含义见 ./src/generate.sh -h
#
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$HERE/output"

# 壁纸:默认 assets/source/1.jpg;WALLPAPER=... 可换(相对路径按项目根算)
WALLPAPER="${WALLPAPER:-assets/source/1.jpg}"
case "$WALLPAPER" in
	/*) ;;
	*) WALLPAPER="$HERE/$WALLPAPER" ;;
esac
[ -f "$WALLPAPER" ] || { echo "找不到壁纸:$WALLPAPER" >&2; exit 1; }

# 原图 → 受控体积的 webp(缓存,源图没变就复用):用户只需提供原图
CACHE_DIR="$HERE/.cache"
mkdir -p "$CACHE_DIR"
CACHE_WEBP="$CACHE_DIR/$(basename "${WALLPAPER%.*}").webp"
if [ ! -f "$CACHE_WEBP" ] || [ "$WALLPAPER" -nt "$CACHE_WEBP" ]; then
	if node "$HERE/tools/compress-wallpaper.mjs" "$WALLPAPER" "$CACHE_WEBP"; then
		:
	else
		echo "提示:壁纸压缩失败,直接用原图(体积可能较大)" >&2
		CACHE_WEBP="$WALLPAPER"
	fi
fi

exec "$HERE/src/generate.sh" "$CACHE_WEBP" \
	--preset glass --scrim 0.52 \
	--tint 0.33 --tint-panel 0.35 --tint-tool 0.50 --tint-bubble 0.35 --tint-user 0.55 \
	--backdrop "blur(20px) saturate(1.7)" --blur 4px --saturate 1.5 \
	--base-mix 0 \
	--position "45% center" \
	-o "$HERE/output/pi-web-theme.css" \
	"$@"
