#!/usr/bin/env bash
#
# pi-web Stylus 主题 · CSS 生成器(项目 pi-web-stylus-glassTheme)
#
# 作用:把一张壁纸压成 base64,生成一段可直接粘进 Stylus 的完整 CSS。
#      全程不修改 pi-web 安装目录里的任何文件,所以 `npm i -g @agegr/pi-web`
#      升级后样式依然有效。
#
# 平时不用直接调本脚本:用项目根里的 ./build.sh 即可 —— 那里写死了壁纸
# (assets/source/1.jpg = 默认壁纸)和当前调好的参数。
#
# 修订号:改 CSS 规则时把下面的 PROJECT_REV 加 1。
#      生成物头部会写「修订:rN-sha8」,运行时也会暴露 --piw-rev,
#      两边对上才能确认页面上生效的就是这一版。
#
# 用法:
#   ./src/generate.sh <图片路径> [选项]
#
# 选项:
#   -o, --out <文件>           把生成的 CSS 写入文件(默认打印到标准输出)
#       --preset <名字>        glass(默认,磨砂最重) | vivid(壁纸色最足) | crisp(人物清晰)
#       --scrim <0~1>          白纱强度,越大壁纸越亮越"雾"(glass 0.45 / vivid 0.30 / crisp 0.15)
#       --tint <0~1>           内容面(--bg)的不透明度,即"玻璃浓度"(默认 0.56,越小越透)
#       --tint-panel <0~1>     顶栏/侧栏(--bg-panel)不透明度
#                              默认 = tint × 0.65(派生,老用法保持不变)
#                              顶栏文字/图标看不清时调到 0.85~0.95
#       --tint-tool <0~1>      工具条/输入框(--tool-bg)不透明度
#                              默认 = tint × 1.05(派生,老用法保持不变)
#                              工具块重叠主界面时调到 0.85~0.95
#       --tint-bubble <0~1>    消息气泡(--assistant-bg)不透明度
#                              默认 = tint × 1.15(派生)
#                              想要 chat 主区看到更多壁纸 → 调到 0.30~0.45
#       --tint-user <0~1>      用户气泡(--user-bg)不透明度
#                              默认 = tint × 1.30(派生)
#       --tint-popover <0~1>   普通浮层(下拉/弹窗,含 session-info-popover)不透明度
#                              默认 0.6(浮层压在文字上,要能读;= --piw-popover-bg)
#       --tint-minimap <0~1>   ChatMinimap 展开面板不透明度
#                              默认 = --tint-panel(与左栏同一块玻璃)
#       --base-mix <0~1>       内容面(聊天区/气泡/工具块)混入「壁纸基调色」的比例
#                              默认 0 = 全中性(推荐);>0 则玻璃色相跟着壁纸走
#                              调大更贴壁纸色,但二级文字对比度会降(跑 tools/contrast-check.mjs 核对)
#                              基调色由 tools/extract-color.mjs 从壁纸提取(取色相/饱和度,明度按主题深浅给)
#       --base-color <#rrggbb> 手动指定基调色(覆盖自动提取)
#       --blur <长度>          壁纸层模糊标准差,等同 CSS blur() 的半径(12px / 10px / 6px)
#       --saturate <倍数>      壁纸层饱和度(1.5 / 1.5 / 1.35)
#       --backdrop <滤镜>      面板毛玻璃滤镜(顶栏/侧栏/弹窗/工具条/终端/输入框/代码块)
#                              默认:blur(18px) saturate(1.6)
#                              关闭:设 none
#       --position <值>        壁纸对位("68% center" / "72% center" / "75% center")
#   -h, --help                 显示本帮助
#
# 调参建议:想更看得见壁纸 → 调小 --tint 和 --scrim;想人物更清晰 → 用 --preset crisp;
#          想让文字更清楚 → 调大 --tint(内容面更实) 和 --scrim(壁纸更亮)
#          想让顶栏/工具条不透明 → 调大 --tint-panel 和 --tint-tool
#
# 覆盖主题:pi-web 的 light / mist / rose(浅色系)与 dark / pine(深色系)
#          都会各自变成半透明玻璃,换主题不会失效。
#
# 示例:
#   ./src/generate.sh assets/source/1.jpg -o output/pi-web-theme.css
#   ./src/generate.sh /path/to/img.png --preset vivid --tint 0.44 --position "72% center"
#
set -euo pipefail

# ── 修订号:改规则就 +1(生成物里会写 修订:rN-sha8,运行时可读 --piw-rev) ──
PROJECT_REV="34"

usage() { awk 'NR>1 { if ($0 !~ /^#/) exit; sub(/^# ?/, ""); print }' "$0"; }
warn() { printf '%s\n' "$*" >&2; }
die() { warn "错误:$*"; exit 1; }

[ $# -ge 1 ] || { usage; exit 1; }
case "$1" in -h | --help) usage; exit 0 ;; esac

IMG="$1"
shift

PRESET="glass"
SCRIM="" BLUR="" SATURATE="" POSITION="" TINT="" TINT_PANEL="" TINT_TOOL="" TINT_BUBBLE="" TINT_USER="" TINT_POPOVER="" TINT_MINIMAP="" BACKDROP="" OUT="" BASE_MIX="" BASE_COLOR=""

while [ $# -gt 0 ]; do
	case "$1" in
	-o | --out) OUT="${2:-}"; shift 2 ;;
	--preset) PRESET="${2:-}"; shift 2 ;;
	--scrim) SCRIM="${2:-}"; shift 2 ;;
	--tint) TINT="${2:-}"; shift 2 ;;
	--tint-panel) TINT_PANEL="${2:-}"; shift 2 ;;
	--tint-tool) TINT_TOOL="${2:-}"; shift 2 ;;
	--tint-bubble) TINT_BUBBLE="${2:-}"; shift 2 ;;
	--tint-user) TINT_USER="${2:-}"; shift 2 ;;
	--tint-popover) TINT_POPOVER="${2:-}"; shift 2 ;;
	--tint-minimap) TINT_MINIMAP="${2:-}"; shift 2 ;;
	--backdrop) BACKDROP="${2:-}"; shift 2 ;;
	--base-mix) BASE_MIX="${2:-}"; shift 2 ;;
	--base-color) BASE_COLOR="${2:-}"; shift 2 ;;
	--blur) BLUR="${2:-}"; shift 2 ;;
	--saturate) SATURATE="${2:-}"; shift 2 ;;
	--position) POSITION="${2:-}"; shift 2 ;;
	-h | --help) usage; exit 0 ;;
	*) die "未知参数:$1(用 -h 看用法)" ;;
	esac
done

case "$PRESET" in
glass)
	D_SCRIM="0.45" D_BLUR="12px" D_SATURATE="1.5" D_POSITION="72% center"
	;;
vivid)
	D_SCRIM="0.30" D_BLUR="10px" D_SATURATE="1.5" D_POSITION="72% center"
	;;
crisp)
	D_SCRIM="0.15" D_BLUR="6px" D_SATURATE="1.35" D_POSITION="75% center"
	;;
*) die "--preset 只能是 glass / vivid / crisp" ;;
esac

SCRIM="${SCRIM:-$D_SCRIM}"
BLUR="${BLUR:-$D_BLUR}"
SATURATE="${SATURATE:-$D_SATURATE}"
POSITION="${POSITION:-$D_POSITION}"
TINT="${TINT:-0.56}"

in_range() { awk -v v="$1" 'BEGIN{ exit !(v ~ /^[0-9]*\.?[0-9]+$/ && v+0 >= 0 && v+0 <= 1) }'; }
in_range "$TINT" || die "--tint 需要 0~1 之间的小数,例如 0.50"
in_range "$SCRIM" || die "--scrim 需要 0~1 之间的小数,例如 0.55"

# --tint = 内容面(--bg)的不透明度,其余按 macOS 的层级派生:
#   --bg(内容表面:正文/右栏文件面板/设置面板/代码块/输入框)  要厚,保可读性
#   --bg-panel(玻璃板:侧栏/顶栏/右栏头部)                  要薄,壁纸主要从这里透出来
#   消息/用户/工具                                        更厚,是内容上的内容
# --tint-panel / --tint-tool 可以显式覆盖派生值(顶栏/工具条看不清时调大)
tint_of() { awk -v t="$TINT" -v f="$1" 'BEGIN{v=t*f; if(v>1)v=1; if(v<0)v=0; printf "%.2f", v}'; }
T_BG="$(tint_of 1.00)"
T_PANEL="${TINT_PANEL:-$(tint_of 0.65)}"
T_ASSISTANT="${TINT_BUBBLE:-$(tint_of 1.15)}"
T_TOOL="${TINT_TOOL:-$(tint_of 1.05)}"
T_USER="${TINT_USER:-$(tint_of 1.30)}"
# 普通浮层(下拉/弹窗):默认比面板厚一档 —— 它们压在聊天文字上,要能读
T_POPOVER="${TINT_POPOVER:-0.6}"
# minimap 展开面板:默认跟左栏同一档(--bg-panel 的 alpha),要更实再显式传 --tint-minimap
T_MINIMAP="${TINT_MINIMAP:-$T_PANEL}"
T_BACKDROP="${BACKDROP:-blur(18px) saturate(1.6)}"

# 校验显式传入的值
[ -n "$TINT_PANEL" ]   && (in_range "$TINT_PANEL"   || die "--tint-panel 需要 0~1 之间的小数,例如 0.90")
[ -n "$TINT_TOOL" ]    && (in_range "$TINT_TOOL"    || die "--tint-tool 需要 0~1 之间的小数,例如 0.92")
[ -n "$TINT_BUBBLE" ]  && (in_range "$TINT_BUBBLE"  || die "--tint-bubble 需要 0~1 之间的小数,例如 0.40")
[ -n "$TINT_USER" ]    && (in_range "$TINT_USER"    || die "--tint-user 需要 0~1 之间的小数,例如 0.60")
[ -n "$TINT_POPOVER" ] && (in_range "$TINT_POPOVER" || die "--tint-popover 需要 0~1 之间的小数,例如 1.0")
[ -n "$TINT_MINIMAP" ] && (in_range "$TINT_MINIMAP" || die "--tint-minimap 需要 0~1 之间的小数,例如 0.96")

[ -f "$IMG" ] || die "找不到图片:$IMG"
[ -r "$IMG" ] || die "图片不可读:$IMG"

# ── 壁纸基调色:把面板底色染向壁纸,保持整体 UI 色系一致 ─────────────
#   --base-mix 0    关(完全用主题自带配色)
#   --base-mix 1    面板底色完全取基调色
#   基调色默认由 tools/extract-color.mjs 提取(压饱和度、限明度到中间区间);
#   提取失败或显式给了 --base-color 时走对应分支。
BASE_MIX="${BASE_MIX:-0}"
in_range "$BASE_MIX" || die "--base-mix 需要 0~1 之间的小数,例如 0.5"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TINT_HEX=""
if [ -n "$BASE_COLOR" ]; then
	TINT_HEX="$BASE_COLOR"
	TINT_DHEX=""
elif awk -v m="$BASE_MIX" 'BEGIN{exit !(m>0)}'; then
	TINT_OUT="$(node "$SCRIPT_DIR/../tools/extract-color.mjs" "$IMG" 2>/dev/null || true)"
	if [ -n "$TINT_OUT" ]; then
		TINT_HEX="$(printf '%s\n' "$TINT_OUT" | sed -n '1p')"
		TINT_DHEX="$(printf '%s\n' "$TINT_OUT" | sed -n '2p')"
	else
		warn "提示:未能从壁纸提取基调色,面板底色沿用主题自带配色(可用 --base-color #rrggbb 指定)"
	fi
fi
if [ -n "$TINT_HEX" ]; then
	is_hex() { case "$1" in \#[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]) return 0 ;; *) return 1 ;; esac; }
	is_hex "$TINT_HEX" || die "--base-color 需要 #rrggbb 格式,收到:$TINT_HEX"
	TINT_R=$((16#${TINT_HEX:1:2}))
	TINT_G=$((16#${TINT_HEX:3:2}))
	TINT_B=$((16#${TINT_HEX:5:2}))
	if [ -z "$TINT_DHEX" ]; then
		# 手动 --base-color 时没给暗基调:同色相压暗(避免把深色底洗亮、拉低对比)
		TINT_DR=$((TINT_R * 40 / 100))
		TINT_DG=$((TINT_G * 40 / 100))
		TINT_DB=$((TINT_B * 40 / 100))
	else
		is_hex "$TINT_DHEX" || die "基调色格式不对:$TINT_DHEX"
		TINT_DR=$((16#${TINT_DHEX:1:2}))
		TINT_DG=$((16#${TINT_DHEX:3:2}))
		TINT_DB=$((16#${TINT_DHEX:5:2}))
	fi
else
	BASE_MIX="0"
fi

# mix r g b → 把主题色按 BASE_MIX 混向壁纸基调色,输出 "r, g, b"(浅色主题用)
mix() {
	awk -v r="$1" -v g="$2" -v b="$3" -v R="${TINT_R:-0}" -v G="${TINT_G:-0}" -v B="${TINT_B:-0}" -v m="$BASE_MIX" \
		'BEGIN{printf "%d, %d, %d", r+(R-r)*m, g+(G-g)*m, b+(B-b)*m}'
}
# mix_dark r g b → 同上,但混向压暗后的基调色(深色主题用)
mix_dark() {
	awk -v r="$1" -v g="$2" -v b="$3" -v R="${TINT_DR:-0}" -v G="${TINT_DG:-0}" -v B="${TINT_DB:-0}" -v m="$BASE_MIX" \
		'BEGIN{printf "%d, %d, %d", r+(R-r)*m, g+(G-g)*m, b+(B-b)*m}'
}

EXT="$(printf '%s' "${IMG##*.}" | tr '[:upper:]' '[:lower:]')"
case "$EXT" in
jpg | jpeg | jpe) MIME="image/jpeg" ;;
png) MIME="image/png" ;;
webp) MIME="image/webp" ;;
avif) MIME="image/avif" ;;
gif) MIME="image/gif" ;;
*) die "不支持的图片格式:.$EXT(支持 jpg / jpeg / png / webp / avif / gif)" ;;
esac

SIZE="$(wc -c <"$IMG" | tr -d ' ')"
if [ "$SIZE" -gt 4194304 ]; then
	warn "提示:图片 $(awk -v s="$SIZE" 'BEGIN{printf "%.1f", s/1048576}') MB,base64 后约 $(awk -v s="$SIZE" 'BEGIN{printf "%.1f", s*1.37/1048576}') MB,样式文件会偏大,建议先压到 2 MB 以内。"
fi

B64="$(base64 -w0 "$IMG")"
MIME_SIZE="$(awk -v s="$SIZE" 'BEGIN{printf "%.0f KB", s/1024}')"
STAMP="$(date '+%Y-%m-%d %H:%M:%S')"

emit_css() {
	cat <<CSS
/* ============================================================
   pi-web · 毛玻璃背景(macOS 风格)
   由 src/generate.sh 生成(项目 pi-web-stylus-glassTheme),可直接粘进 Stylus

   生成时间:__PIW_STAMP__
   修订:__PIW_REV__
   图片:$MIME, $MIME_SIZE
   参数:preset=$PRESET scrim=$SCRIM tint=$TINT tint-panel=$T_PANEL tint-tool=$T_TOOL tint-bubble=$T_ASSISTANT tint-user=$T_USER tint-popover=$T_POPOVER tint-minimap=$T_MINIMAP backdrop="$T_BACKDROP" blur=$BLUR saturate=$SATURATE position=$POSITION base-mix=$BASE_MIX base-color=${TINT_HEX:-(theme)}

   装法:Stylus → 新建样式 → Applies to(点 + 可以加多条,模式与写法必须配对):
         [URL 前缀]      http://127.0.0.1:30141/
         [URL 前缀]      http://localhost:30141/
         [正则表达式]    ^https?://(127\\.0\\.0\\.1|localhost):30141/
       ※ ^ $ \\ . | 是正则语法,只对「正则表达式」模式有效;
         填进「URL 前缀」框里会永远不匹配(这就是之前不生效的原因)。
       ※ 不建议用「所有页面」:壁纸层和滚动条规则是无条件的,
         会在你访问的每个网站上都生效。
       ※ 浅色系主题会把 --text-muted / --text-dim 压深,
         否则玻璃上的次级灰字对比度只有 2:1 出头(见 CSS 内注释)。
   说明:只覆盖 pi-web 的公开 CSS 变量,不碰任何安装目录里的文件,
        因此 npm i -g 升级后依然生效。
   ============================================================ */

:root {
  /* ── 可调参数 ───────────────────────────────────────────── */
  --piw-wallpaper: url("data:$MIME;base64,$B64");
  /* 纱:把壁纸压成柔和底色、保证文字可读性。
     透光率 ≈ (1-scrim) x (1-面板alpha):想更看得见壁纸就调小它 */
  --piw-scrim-color: rgba(255, 255, 255, $SCRIM);
  /* 磨砂强度:越大越像 macOS 的 vibrancy(MDN:blur() 的 length 就是高斯标准差) */
  --piw-blur: $BLUR;
  --piw-saturate: $SATURATE;
  /* 壁纸对位:人物压到右半侧,避开左侧栏和底部输入框 */
  --piw-position: $POSITION;
}

/* 模态遮罩(窗口背后那层雾):浅色系用**白雾**。
   浅色玻璃叠黑纱 = 0.35 白 叠 0.38 黑 = 灰扑扑的泥色,和浅色系不搭;
   换成白雾后,窗口叠上去 = 亮磨砂,与左栏同质感。 */
:root {
  --piw-scrim-modal: rgba(255, 255, 255, 0.22);
}

/* 深色系主题的纱换成深色 */
html[data-theme="dark"],
html.dark,
html[data-theme="pine"] {
  --piw-scrim-color: rgba(10, 12, 16, $SCRIM);
  --piw-scrim-modal: rgba(10, 12, 16, 0.50);
}

/* ── 1. 壁纸层:固定全屏,盖一层纱,并在层内直接模糊 ──────────
   z-index 必须为负:压在 pi-web 的面板之下,否则会把界面一起糊掉。
   inset 外扩 2 倍模糊半径:让模糊产生的淡边落到视口之外。      */
html::before {
  content: "";
  position: fixed;
  inset: calc(var(--piw-blur) * -2);
  z-index: -2;
  pointer-events: none;
  background-image:
    linear-gradient(var(--piw-scrim-color), var(--piw-scrim-color)),
    var(--piw-wallpaper);
  background-size: cover, cover;
  background-position: center, var(--piw-position);
  background-repeat: no-repeat, no-repeat;
  /* 模糊 + 提饱和 = macOS vibrancy 的味道 */
  filter: blur(var(--piw-blur)) saturate(var(--piw-saturate));
  -webkit-filter: blur(var(--piw-blur)) saturate(var(--piw-saturate));
}

/* ── 2. 玻璃面板 ─────────────────────────────────────────
   pi-web 的面板(含无类名、用行内样式写的输入框)都取这些变量,
   所以改变量 = 全站变玻璃,不需要依赖任何类名。
   分两类:
     · 面板面(--bg-panel):侧栏/顶栏/轨道/弹窗——保持**中性**,不受壁纸染色,
       不管换哪张壁纸都一样,只靠 alpha + backdrop 模糊与聊天区区分;
     · 内容面(--bg / --tool-bg / --assistant-bg / --user-bg):
       按 --base-mix 混入壁纸基调色,让聊天区玻璃的色相跟着壁纸走。 */

/* 浅色系 · light(#fff / #f5f5f5 / #f9fafb / #eff6ff) */
html[data-theme="light"],
html:not([data-theme]) {
  --bg: rgba($(mix 255 255 255), $T_BG) !important;
  --bg-panel: rgba(245, 245, 245, $T_PANEL) !important;
  --assistant-bg: rgba($(mix 255 255 255), $T_ASSISTANT) !important;
  --tool-bg: rgba($(mix 249 250 251), $T_TOOL) !important;
  --piw-backdrop: $T_BACKDROP;
  --piw-popover-bg: rgba(245, 245, 245, $T_POPOVER) !important;
  --piw-minimap-bg: rgba(245, 245, 245, $T_MINIMAP) !important;
  --user-bg: rgba($(mix 239 246 255), $T_USER) !important;
  --bg-hover: rgba(0, 0, 0, 0.05) !important;
  --bg-selected: rgba(0, 0, 0, 0.09) !important;
  --border: rgba(0, 0, 0, 0.10) !important;
}

/* 浅色系 · mist 雾青(#f4f8f7 / #e9f0ee / #ecf3f0 / #e0efeb) */
html[data-theme="mist"] {
  --bg: rgba($(mix 244 248 247), $T_BG) !important;
  --bg-panel: rgba(233, 240, 238, $T_PANEL) !important;
  --assistant-bg: rgba($(mix 244 248 247), $T_ASSISTANT) !important;
  --tool-bg: rgba($(mix 236 243 240), $T_TOOL) !important;
  --piw-backdrop: $T_BACKDROP;
  --piw-popover-bg: rgba(233, 240, 238, $T_POPOVER) !important;
  --piw-minimap-bg: rgba(233, 240, 238, $T_MINIMAP) !important;
  --user-bg: rgba($(mix 224 239 235), $T_USER) !important;
  --bg-hover: rgba(0, 0, 0, 0.05) !important;
  --bg-selected: rgba(0, 0, 0, 0.09) !important;
  --border: rgba(0, 0, 0, 0.10) !important;
}

/* 浅色系 · rose 蔷薇(#fcf7f8 / #f3edef / #f7eef2 / #f3e4eb) */
html[data-theme="rose"] {
  --bg: rgba($(mix 252 247 248), $T_BG) !important;
  --bg-panel: rgba(243, 237, 239, $T_PANEL) !important;
  --assistant-bg: rgba($(mix 252 247 248), $T_ASSISTANT) !important;
  --tool-bg: rgba($(mix 247 238 242), $T_TOOL) !important;
  --piw-backdrop: $T_BACKDROP;
  --piw-popover-bg: rgba(243, 237, 239, $T_POPOVER) !important;
  --piw-minimap-bg: rgba(243, 237, 239, $T_MINIMAP) !important;
  --user-bg: rgba($(mix 243 228 235), $T_USER) !important;
  --bg-hover: rgba(0, 0, 0, 0.05) !important;
  --bg-selected: rgba(0, 0, 0, 0.09) !important;
  --border: rgba(0, 0, 0, 0.10) !important;
}

/* 深色系 · dark(#1a1a1a / #242424 / #222222 / #292929) */
html[data-theme="dark"],
html.dark {
  --bg: rgba($(mix_dark 26 26 26), $T_BG) !important;
  --bg-panel: rgba(36, 36, 36, $T_PANEL) !important;
  --assistant-bg: rgba($(mix_dark 26 26 26), $T_ASSISTANT) !important;
  --tool-bg: rgba($(mix_dark 34 34 34), $T_TOOL) !important;
  --piw-backdrop: $T_BACKDROP;
  --piw-popover-bg: rgba(36, 36, 36, $T_POPOVER) !important;
  --piw-minimap-bg: rgba(36, 36, 36, $T_MINIMAP) !important;
  --user-bg: rgba($(mix_dark 41 41 41), $T_USER) !important;
  --bg-hover: rgba(255, 255, 255, 0.08) !important;
  --bg-selected: rgba(255, 255, 255, 0.14) !important;
  --border: rgba(255, 255, 255, 0.14) !important;
}

/* 深色系 · pine 松夜(#19201f / #212b28 / #222d29 / #25382f) */
html[data-theme="pine"] {
  --bg: rgba($(mix_dark 25 32 31), $T_BG) !important;
  --bg-panel: rgba(33, 43, 40, $T_PANEL) !important;
  --assistant-bg: rgba($(mix_dark 25 32 31), $T_ASSISTANT) !important;
  --tool-bg: rgba($(mix_dark 34 45 41), $T_TOOL) !important;
  --piw-backdrop: $T_BACKDROP;
  --piw-popover-bg: rgba(33, 43, 40, $T_POPOVER) !important;
  --piw-minimap-bg: rgba(33, 43, 40, $T_MINIMAP) !important;
  --user-bg: rgba($(mix_dark 37 56 47), $T_USER) !important;
  --bg-hover: rgba(255, 255, 255, 0.08) !important;
  --bg-selected: rgba(255, 255, 255, 0.14) !important;
  --border: rgba(255, 255, 255, 0.14) !important;
}

/* ── 3. 浅色系主题的次级文字压深 ───────────────────────────
   玻璃底比主题原本的底色暗,而 pi-web 的 --text-muted #515c6b /
   --text-dim #5e6673 是按纯白底调的,直接放在玻璃上只有 2:1 出头,
   看起来就是"灰字洗得看不清、区域间深浅不一致"。这里把这两个灰压深。
   实测(当前默认参数,壁纸最暗处):muted ~6.0:1 / dim ~5.7:1,均达 WCAG AA。
   注:--scrim / --tint / --base-mix 改动后底色会变,二级文字对比度会跟着浮动;
       改动后请跑 tools/contrast-check.mjs(传 BASE=实际底色)核对。 */
html[data-theme="light"],
html:not([data-theme]),
html[data-theme="mist"],
html[data-theme="rose"] {
  --text-muted: #232a33 !important;
  --text-dim: #272e38 !important;
}

/* ── 4. 细节打磨(不需要可整块删) ─────────────────────────── */
::-webkit-scrollbar {
  width: 10px;
  height: 10px;
}
::-webkit-scrollbar-track {
  background: transparent;
}
::-webkit-scrollbar-thumb {
  background: rgba(0, 0, 0, 0.18);
  border: 3px solid transparent;
  border-radius: 999px;
  background-clip: padding-box;
}
::-webkit-scrollbar-thumb:hover {
  background: rgba(0, 0, 0, 0.30);
  background-clip: padding-box;
}

/* ── 5. 毛玻璃滤镜:仅给顶栏/弹窗/工具条/终端/代码块 ──
   不给 chat 主区 / 消息气泡 / 输入框加,那里要看清壁纸细节。
   用 @supports 包裹,不支持 backdrop-filter 的浏览器优雅降级。
   ⚠ 不要用 [style*="--bg-panel"] 这种宽泛属性选择器把顶栏也匹配上:
     给顶栏加 backdrop-filter 会创建 stacking context,把里面的 popover 困住。
   ⚠ 左栏也不在这里:它的模糊放在自己的 ::before(见 6.1)。
     理由:带 backdrop-filter 的元素会成为**子孙的 backdrop root**,
     子孙自己的 backdrop-filter 就只能看到这个 root 内部,看不到页面(壁纸)那一层 ——
     左栏里的「筛选项目」下拉、轨道里的 minimap 展开面板就是这样“看着没磨砂、太透”的。
     ::before 不是任何元素的祖先,所以自己模糊照旧,却不会卡住子孙。 */
@supports ((backdrop-filter: blur(1px)) or (-webkit-backdrop-filter: blur(1px))) {
  /* 模糊只给「本身就是一块玻璃面板」的元素(最外层、自己带底色):
     ⚠ 已经在另一块磨砂面板里面的子元素不要再加 —— 嵌套的 backdrop-filter 会把
       下面那块面板再画一遍,那个区域反而变白、没磨砂。设置窗口「只有标题栏有磨砂」
       就是这么来的(.settings-dialog-main 在已磨砂的 .settings-dialog-surface 里)。
     ⚠ 同理,自己底色是透明的子元素也没有底色可糊(如 .extension-widget-panel ——
       底色在它的容器 .extension-widget-panels 上,所以模糊加在容器上)。
     已因此从名单里移除:.settings-dialog-main / .settings-shell-option /
     .file-viewer-shell / .file-viewer-toolbar / .markdown-code-header /
     .enabled-models-header / .tool-definitions-sidebar
     (右边这些的父面板都在别处列了模糊:.settings-dialog-surface 见 7.1、
      .right-panel-container 见 6.6、.markdown-code-block / .tool-definitions-panel 见本块)。
     .config-panel-surface 只留「独立弹窗」那一支(is-modal);嵌入式那一支
     (设置窗口里的 模型/技能/Agents/插件 页)的玻璃由 .settings-dialog-surface 提供,
     自己不再磨砂 —— 见 7.3。 */
  .config-panel-root.is-modal > .config-panel-surface,
  .markdown-code-block,
  .tool-definitions-panel,
  .extension-widget-panels,
  .terminal-panel,
  .terminal-panel-header {
    backdrop-filter: var(--piw-backdrop) !important;
    -webkit-backdrop-filter: var(--piw-backdrop) !important;
  }
}

/* ── 6. 顶栏单独覆盖:把它抬高到 chat-content 之上(否则顶栏里的下拉会被聊天区盖住)。
   注意:不能给顶栏加 backdrop-filter(会创建 stacking context,把里面的 popover 困住),
   只用 position + z-index 把它在 stacking 排序上提前。
   ⚠ 选择器必须只命中顶栏:inline 写 background: var(--bg-panel) + flex-shrink: 0。
     DOM 实测:聊天列 > 顶栏容器 ;聊天列 > div > .chat-content。
     注意 .chat-content 外面还包了一层 <div>,所以 :has(> .chat-content) 命中的
     是里层,拿不到顶栏;必须用 :has(> div > .chat-content) 才命中顶栏所在的聊天列。
     旧写法 [style*="--bg-panel"] 太宽 —— 它会把 minimap 轨道、分支下拉、
     子会话面板、文件树里的悬浮按钮全都强改成 position:relative + z-index:50,
     其中「分支下拉」本来是 position:fixed 的浮层,被改成 relative 之后
     就画在错误的层叠/位置上(看起来像“没生效”)。 */
div:has(> div > .chat-content) > div[style*="background: var(--bg-panel)"][style*="flex-shrink: 0"] {
  position: relative !important;
  z-index: 50 !important;
}

/* ── 6.1. 去掉面板之间的 1px 分隔线 ─────────────────────
   左栏右边界、顶栏下边界都是 pi-web 自己 inline 画的 1px var(--border);
   玻璃面板和聊天区本来就有透明度差,这两条线反而割裂了整体。
   顶栏的线在它内部那行 tab 上(顶栏容器的第一个子元素)。
   (轨道那一列的竖线在 6.7 里一并去掉) */
#session-sidebar {
  border-right-color: transparent !important;
  /* 下面那条 ::before 的包含块(左栏 inline 没写 position) */
  position: relative;
}
/* 左栏的毛玻璃从「元素自身」挪到 ::before —— 原因是 backdrop root:
   带 backdrop-filter 的元素会成为子孙的 backdrop root;左栏里的「筛选项目」下拉
   自己也有 backdrop-filter,却看不到壁纸那一层,结果背景色在、模糊没了,“太透”。
   ::before 不是任何元素的祖先,自己照旧磨砂,却不挡子孙。
   底色仍由左栏自己的 background: var(--bg-panel) 提供,所以观感不变。 */
@supports ((backdrop-filter: blur(1px)) or (-webkit-backdrop-filter: blur(1px))) {
  #session-sidebar::before {
    content: "";
    position: absolute;
    inset: 0;
    z-index: -1;
    pointer-events: none;
    backdrop-filter: var(--piw-backdrop);
    -webkit-backdrop-filter: var(--piw-backdrop);
  }
}
div:has(> div > .chat-content) > div[style*="background: var(--bg-panel)"][style*="flex-shrink: 0"] > div:first-child {
  border-bottom-color: transparent !important;
}
/* 保险:不论是不是第一个子元素,凡带这条下边线的直接子元素都去掉 */
div:has(> div > .chat-content) > div[style*="background: var(--bg-panel)"][style*="flex-shrink: 0"] > div[style*="border-bottom: 1px solid var(--border)"] {
  border-bottom-color: transparent !important;
}

/* 顶栏那排 tab、侧栏隐藏按钮、文件面板右上的按钮:各自 inline/类里都画了
   一条 border(竖线或左边线),这里一并去掉,并把圆角对齐左栏底部
   「模型 / 技能」那排按钮的风格(borderRadius:9,这里取 6px 更贴合 36px 高)。
   只取顶栏 tab 行(> div:first-child)内的按钮,避免误伤顶栏下拉里的按钮。 */
div:has(> div > .chat-content) > div[style*="background: var(--bg-panel)"][style*="flex-shrink: 0"] > div:first-child button,
#session-sidebar button[style*="border-right: 1px solid var(--border)"],
.right-panel-container > div:first-child > button {
  border-right: none !important;
  border-left: none !important;
  border-radius: 6px !important;
}
/* 顶栏按钮 hover 底色:“系统/工具/分支”这几个 pi-web 只做变色、不显底色,
   这里统一给个 bg-hover(与“生成标题/完整历史”一致);选中态除外 */
div:has(> div > .chat-content) > div[style*="background: var(--bg-panel)"][style*="flex-shrink: 0"] > div:first-child button:hover:not([aria-pressed="true"]) {
  background: var(--bg-hover) !important;
}

/* ── 6.5. 输入框 / 底部一层:让出右侧 36px 轨道,并与消息列逐像素重合 ───────
   结构(0.9.3 实测):聊天列 .chat-content
     ├─ 消息行(relative flex): [消息滚动区] [minimap 轨道 36px]
     └─ div.relative.shrink-0 : 输入框 fieldset + 工具行 + status shelf  ← 整列宽
   问题:底部这层是「消息行」的兄弟、整列宽,而轨道只活在消息行里 ——
         1) 它横跨了轨道那一列,把轨道盖掉;
         2) 上游给的 paddingRight:52 = 16+36 只抵掉轨道,没补滚动条槽那 10px,
            所以输入框比消息列右偏 5px(实测 357..1177 vs 352..1172)。
   做法:
     1) 底部那层宽度 -36px → 右边界收到轨道左边界,不再覆盖轨道;
     2) 输入框右内边距 52 → 26 (= 16 + 滚动条槽 10) → 可见盒与消息列重合;
     3) 「滚动到底」按钮原本靠 right:36 抵消轨道,容器变窄后归零回原位;
     4) 空会话提示行是同款 16/52,一起换。
   注意:26 依赖滚动条槽 = pi-web 自己的 ::-webkit-scrollbar{width:10px}(触屏 6px)。
        想不依赖它 → 第 2 条改回 16px,并给消息滚动容器(带
        scrollbar-gutter:stable 的那个)加 stable both-edges;
        代价是消息列整体右移 5px。 */
@media (min-width: 641px) {
  div:has(> div > div[style*="width: 36px"]) > div:has(> fieldset textarea.chat-input-textarea) {
    width: calc(100% - 36px);
  }
  /* :not(...) 用来避开文件查看器里那个 compact 版输入框 */
  fieldset:has(textarea.chat-input-textarea):not([style*="flex-direction: column"]) {
    padding-right: 26px !important;
  }
  div:has(> button.chat-scroll-to-bottom) {
    right: 0 !important;
  }
}
div.mb-3.w-full[style*="padding-right: 52px"] {
  padding-right: 26px !important;
}

/* ── 6.5b. 聊天输入框:去掉叠层底色,靠描边 + 投影让它显眼 ─────
   输入框外面那层 div(没有 class,是 textarea.chat-input-textarea 的直接父元素)自带
   background: var(--bg);而它底下还有 body 的 --bg —— 两层同色叠起来,等效 alpha
   更高,所以输入区看起来像多了一块“底色”。去掉后就不显眼了,
   于是用「加深描边 + 柔和投影」把框重新画出来(壁纸仍然透出来,不铺底色)。
   想要磨砂底(像侧栏那样更明显):把 background 改成 var(--bg-panel)。
   :not(...) 避开文件查看器里那个 compact 版输入框(它才是 flex-direction: column)。 */
div:has(> textarea.chat-input-textarea):not([style*="flex-direction: column"]) {
  background: transparent !important;
  border-color: color-mix(in srgb, var(--text-dim) 42%, transparent) !important;
  box-shadow: 0 2px 6px rgba(15, 23, 42, 0.06), 0 14px 34px -16px rgba(15, 23, 42, 0.30) !important;
}

/* ── 6.6. 右下侧栏:和左栏同级的「面板」质感(不再强制浮层) ────────────
   老方案是桌面下强制 .right-panel-container 走 position:fixed 盖在聊天区上;
   代价:它底下是聊天文字而不是壁纸 → 只能靠「几乎不透明」来保证可读,
   结果就是一块纯色板子,和左栏那种「透出壁纸」的质感对不上。
   现在按设计需求(左右侧栏 = 磨砂半透 + 透出一点壁纸)改回 pi-web 原生
   flex 占位(< 960px 时它本来就是 fixed 浮层,不受影响),
   只把它的底色对齐左栏 #session-sidebar 用的 var(--bg-panel)(tint-panel)。
   想退回「浮层覆盖」老方案:
     .right-panel-container{position:fixed!important;top:0!important;
       right:env(safe-area-inset-right,0)!important;bottom:0!important;z-index:250!important}
     .right-panel-container.right-panel-closed{transform:translateX(100%)!important;
       pointer-events:none!important}
   但那样它底下是聊天文字,必须回到「接近不透明」(见 7.1)才读得清。 */
.right-panel-container {
  background: var(--bg-panel) !important;
  /* 去掉与聊天区之间的竖线(pi-web inline 的 borderLeft) */
  border-left-color: transparent !important;
}
/* 面板头部(第一个子元素):去掉下边线;背景也去掉 —— 它 inline 又画了一层 --bg-panel,
   叠在面板自己的 --bg-panel 上会更实(0.58),和聊天顶栏(单层 0.35)对不上 */
.right-panel-container > div:first-child {
  background: transparent !important;
  border-bottom-color: transparent !important;
}
/* 头部右侧的「全宽展示 / 隐藏文件面板」按钮:默认透明,仅 hover 显底色;
   选中态(aria-pressed)pi-web 已用 accent 色图标表示,不需要常驻底色 */
.file-panel-expand-button,
.right-panel-container > div:first-child > button,
#file-panel button[style*="background: var(--bg-selected)"] {
  background: transparent !important;
}
/* 图标颜色也和顶栏一致(顶栏用 --text-muted;pi-web 这里默认给的是 --text,偏深) */
.file-panel-expand-button,
.right-panel-container > div:first-child > button {
  color: var(--text-muted) !important;
}
.file-panel-expand-button:hover,
.right-panel-container > div:first-child > button:hover {
  background: var(--bg-hover) !important;
}
/* 注:右栏这里**不加** backdrop-filter ——
   它的头顶就是聊天顶栏,而顶栏没有 backdrop-filter(§6 注释:加了会创建
   stacking context 把顶栏里的下拉困住)。同一块 0.35 玻璃,一边多一层
   blur(20px) saturate(1.7)、一边没有 → 两边接缝处会有色差。
   想右栏也磨砂 → 得同步给聊天顶栏加同样的 backdrop-filter(有层级风险)。 */
@supports ((backdrop-filter: blur(1px)) or (-webkit-backdrop-filter: blur(1px))) {
  .right-panel-container {
    backdrop-filter: var(--piw-backdrop) !important;
    -webkit-backdrop-filter: var(--piw-backdrop) !important;
  }
}

/* ── 6.7. 让右侧 36px 轨道列(装 minimap node 的边栏)和左栏同质感 ──
   轨道(minimap)是消息行里的 flex 子项,它自身 inline 就写了 background: var(--bg-panel);
   而下面又在 .chat-content 上补画了同色的 36px —— 于是轨道那一列被叠了两层
   var(--bg-panel),等效 alpha ≈ 0.87(左栏只有 1 层 0.55):轨道看起来像实心板子,
   而左栏是磨砂半透。且轨道自身没有 backdrop-filter(左栏有)。
   做法:
     1) 真轨道底色透明化 —— 那一列的颜色交回补画层,不再叠层;
     2) 给真轨道的 ::before 补 backdrop-filter(与左栏 6.1 同理:元素自身带 backdrop-filter
        会成为子孙的 backdrop root,把 minimap 展开面板的模糊挡死)—— 轨道列 = 0.55 + 模糊;
     3) 去掉轨道左侧的 1px 竖线(真轨道边线 + 补画层边线都去),只留底色;
     4) 补画层继续负责轨道下方(输入区那一段)的颜色,保证整列贯穿。 */
@media (min-width: 641px) {
  /* :has 里的那个 36px div 就是真轨道;轨道不在时(短会话/窄屏)不画 */
  .chat-content:has(> div > div[style*="width: 36px"]) {
    background-image: linear-gradient(to right,
      transparent     0                 calc(100% - 36px),
      var(--bg-panel) calc(100% - 36px) 100%);
  }
  /* 真轨道:去掉自身底色(否则与上面补画层叠加)及左侧竖线 */
  div[style*="position: relative"][style*="width: 36px"][style*="background: var(--bg-panel)"] {
    background: transparent !important;
    border-left-color: transparent !important;
  }
}
@supports ((backdrop-filter: blur(1px)) or (-webkit-backdrop-filter: blur(1px))) {
  /* 模糊放 ::before,不放轨道自身(backdrop root 的坑,与左栏 6.1 同理)。
     轨道 inline 已有 position: relative,所以 ::before 的 inset: 0 有包含块。 */
  div[style*="position: relative"][style*="width: 36px"][style*="background: var(--bg-panel)"]::before {
    content: "";
    position: absolute;
    inset: 0;
    z-index: 0;
    pointer-events: none;
    backdrop-filter: var(--piw-backdrop);
    -webkit-backdrop-filter: var(--piw-backdrop);
  }
}

/* ── 7. 例外:popover/浮层类容器必须接近不透明,不能套 panel 的低 alpha ──
   这些是"瞬时弹出 + 纯文字"的场景,背景太透会糊掉文字。
   ChatMinimap 类名带 hash,用 [class*=] 避免升级后失配。

   ⚠️ session-info-popover 的坑:pi-web 自己的 @keyframes session-info-pop
   在 100% keyframe 里写死 background: var(--bg-panel),而且
   animation-fill-mode: both 会保留终态——直接覆盖 background: !important
   在某些浏览器实现下压不过 animation origin。
   解决:把 animation-name 指向我们自己的 keyframe(新名字 piw- 前缀),
   并用自己的 100% 终态(用主题对应的 --piw-popover-bg 变量)。 */

/* 5 个主题各定义一个独立 keyframe,完全硬编码 rgba,避免 var 解析问题 */
@keyframes piw-session-info-pop-light {
  0%   { opacity: 0; transform: translateY(-24px); filter: blur(6px); box-shadow: 0 2px 8px rgba(0,0,0,0); }
  100% { opacity: 1; transform: translateY(0);    filter: blur(0); background: rgba(245, 245, 245, $T_POPOVER); box-shadow: 0 10px 28px rgba(0,0,0,0.10); }
}
@keyframes piw-session-info-pop-mist {
  0%   { opacity: 0; transform: translateY(-24px); filter: blur(6px); box-shadow: 0 2px 8px rgba(0,0,0,0); }
  100% { opacity: 1; transform: translateY(0);    filter: blur(0); background: rgba(233, 240, 238, $T_POPOVER); box-shadow: 0 10px 28px rgba(0,0,0,0.10); }
}
@keyframes piw-session-info-pop-rose {
  0%   { opacity: 0; transform: translateY(-24px); filter: blur(6px); box-shadow: 0 2px 8px rgba(0,0,0,0); }
  100% { opacity: 1; transform: translateY(0);    filter: blur(0); background: rgba(243, 237, 239, $T_POPOVER); box-shadow: 0 10px 28px rgba(0,0,0,0.10); }
}
@keyframes piw-session-info-pop-dark {
  0%   { opacity: 0; transform: translateY(-24px); filter: blur(6px); box-shadow: 0 2px 8px rgba(0,0,0,0); }
  100% { opacity: 1; transform: translateY(0);    filter: blur(0); background: rgba(36, 36, 36, $T_POPOVER);    box-shadow: 0 10px 28px rgba(0,0,0,0.10); }
}
@keyframes piw-session-info-pop-pine {
  0%   { opacity: 0; transform: translateY(-24px); filter: blur(6px); box-shadow: 0 2px 8px rgba(0,0,0,0); }
  100% { opacity: 1; transform: translateY(0);    filter: blur(0); background: rgba(33, 43, 40, $T_POPOVER);    box-shadow: 0 10px 28px rgba(0,0,0,0.10); }
}

/* 默认 light;每个主题单独覆盖 animation-name(其他 timing/easing 仍继承 pi-web 的) */
.session-info-popover {
  animation-name: piw-session-info-pop-light !important;
}
html[data-theme="mist"] .session-info-popover {
  animation-name: piw-session-info-pop-mist !important;
}
html[data-theme="rose"] .session-info-popover {
  animation-name: piw-session-info-pop-rose !important;
}
html[data-theme="dark"] .session-info-popover,
html.dark .session-info-popover {
  animation-name: piw-session-info-pop-dark !important;
}
html[data-theme="pine"] .session-info-popover {
  animation-name: piw-session-info-pop-pine !important;
}

/* 7.1 浮层(下拉 / 弹窗 / 浮窗):磨砂(半透 + backdrop 模糊)——
   统一用 --piw-popover-bg(中性面板色 + --tint-popover,默认 0.45),
   和 minimap 预览/边栏同一档浓淡;要整体变透/变实改 --tint-popover。
   必须 !important:pi-web 用 keyframes / 运行时 <style> 写 background,
   普通声明压不过 animation-origin / 注入样式的优先级。
   另有一类弹窗面板既无 className、又无 role、也没写 position(位置在父遮罩上),
   属性选择器全部落空。如「添加 Provider」(oN)、选择目录:用
   「全屏 fixed 遮罩的直接子」命中 —— 遮罩自身是 [position:fixed; inset:0]。
   注:ChatMinimap 展开面板与「筛选项目」下拉在下面单独成节(与左栏同一配方)。
   另注:系统/工具面板的底色是 pi-web 运行时用 <style> 注入的(单个 class),
         选择器命中后 !important 即可压过它。 */
.session-info-popover,
.system-prompt-panel,
.tool-definitions-panel,
[role="listbox"][style*="background: var(--bg-panel)"],
[style*="position: fixed"][style*="background: var(--bg-panel)"] {
  background: var(--piw-popover-bg) !important;
}
.notice-shelf-item,
[role="dialog"][style*="background: var(--bg)"],
button[aria-expanded="false"][style*="background: var(--bg)"],
[style*="position: absolute"][style*="background: var(--bg)"],
[style*="position: fixed"][style*="background: var(--bg)"],
[style*="position: sticky"][style*="background: var(--bg)"] {
  /* 统一用 --piw-popover-bg（= 中性面板色 + --tint-popover），与边栏同一个磨砂档 */
  background: var(--piw-popover-bg) !important;
}
/* (全屏遮罩里的弹窗 —— 添加 Provider / 选择目录 —— 归 7.4 的“模态窗口”一组,
   用与左栏同档的 --bg-panel) */
@supports ((backdrop-filter: blur(1px)) or (-webkit-backdrop-filter: blur(1px))) {
  .session-info-popover,
  .system-prompt-panel,
  .tool-definitions-panel,
  [role="listbox"][style*="background: var(--bg-panel)"],
  [style*="position: fixed"][style*="background: var(--bg-panel)"],
  .notice-shelf-item,
  .settings-dialog-surface,
  .config-panel-root.is-modal > .config-panel-surface,
  .directory-picker-panel,
  [role="dialog"][style*="background: var(--bg)"],
  button[aria-expanded="false"][style*="background: var(--bg)"],
  [style*="position: absolute"][style*="background: var(--bg)"],
  [style*="position: fixed"][style*="background: var(--bg)"],
  [style*="position: sticky"][style*="background: var(--bg)"],
  [style*="position: fixed"][style*="inset: 0"] > div[style*="background: var(--bg)"] {
    backdrop-filter: var(--piw-backdrop) !important;
    -webkit-backdrop-filter: var(--piw-backdrop) !important;
  }
}

/* ── 7.2. minimap 展开面板 + 「筛选项目」下拉:和左栏同一块玻璃 ─────────
   这两个面板原先都“看着没磨砂”:它们自己写了 backdrop-filter,但祖先(轨道 / 左栏)
   也写了 —— 带 backdrop-filter 的祖先会成为子孙的 backdrop root,子孙的模糊
   就只能作用于 root 内部,看不到页面(壁纸)那一层。6.1 / 6.7 已把祖先的模糊
   挪到各自的 ::before,这里再把这两个面板统一成左栏的配方:
   中性面板色 + --piw-backdrop 模糊(色号不再按主题硬编码)。 */

/* minimap 展开面板:默认 --piw-minimap-bg = 左栏的 --bg-panel(要更实传 --tint-minimap) */
[class*="ChatMinimap_preview"] {
  background: var(--piw-minimap-bg, var(--bg-panel)) !important;
  backdrop-filter: var(--piw-backdrop) !important;
  -webkit-backdrop-filter: var(--piw-backdrop) !important;
}

/* 「筛选项目」下拉:左栏里的 div(position:absolute + z-index:100 + background: var(--bg))。
   用「面板里含那个筛选输入框」定位,不依赖 pi-web 的行内写法;
   万一 placeholder 文案变了,它会退回 7.1 的通用浮层样式(--tint-popover)。
   列表项各自又画了一层 background: var(--bg)(0.33),叠上去会比面板更实,故透明化。 */
div:has(> div > input[placeholder*="筛选项目"]) {
  background: var(--bg-panel) !important;
  backdrop-filter: var(--piw-backdrop) !important;
  -webkit-backdrop-filter: var(--piw-backdrop) !important;
}
div:has(> div > input[placeholder*="筛选项目"]) > div > button {
  background: transparent !important;
}

/* ── 7.3. 窗口内部的“区域块”:不要把玻璃叠两遍 ───────────────────
   大窗口(7.4)自己就是一块玻璃;它内部凡是 pi-web 用 --bg-panel 画的**版面区域**,
   都会在窗口的玻璃上再叠一层 —— 那块区域比周围更白、看着“怪”。
   这类“区域块”包括:
     · 侧栏列 .config-sidebar —— 各配置页左边的列表列
     · 通栏条/横幅 .agents-feature-setting —— 设置-子代理页顶「启用内置子代理」
     · .enabled-models-banner —— 模型页顶横幅
     · .config-trust-notice —— 技能/插件页顶的信任提示条
   它们本来就是窗口版面的一部分,直接用窗口的玻璃就行,所以底色透明化;
   分隔交给 pi-web 自己的 border-right / border-bottom: 1px solid var(--border)。
   注:**小的凸起控件**(带边框圆角的行/卡片/输入框)不算区域块,
   它们需要比窗口更“实”才能读成凸起,继续保留 pi-web 的 --bg-panel / --bg。 */
.config-sidebar,
.agents-feature-setting,
.enabled-models-banner,
.config-trust-notice {
  background: transparent !important;
}
/* 扩展请求弹窗(沙箱要授权那种，飘在聊天上、无遮罩遮罩)的底部操作条也是同一个道理:
   pi-web 给它写了 background: var(--bg-panel),叠在 0.6 的弹窗上 ≈0.74
   → 底部一条比面板亮(看着像另一块)。透明化后与信任确认窗的 footer 一致
   (后者本来就没底色,只有 border-top)。 */
[role="dialog"] > div[style*="border-top: 1px solid var(--border)"][style*="background: var(--bg-panel)"] {
  background: transparent !important;
}

/* 嵌入式配置面板(设置里的 模型/技能/Agents/插件 页)自己不是一块玻璃:
   玻璃由外层 .settings-dialog-surface 提供。pi-web 自己对嵌入态的 surface 已去掉
   边框/圆角/阴影(is-embedded),这里把底色与模糊一并去掉 —— 否则那几页会叠两层
   底色 + 两层模糊,比「常规」页明显发白。 */
.config-panel-root.is-embedded > .config-panel-surface {
  background: transparent !important;
  backdrop-filter: none !important;
  -webkit-backdrop-filter: none !important;
}

/* ── 7.4. 模态窗口:和左栏一模一样的玻璃(不要灰) ───────────────────
   属于“窗口”的东西(不是贴在聊天区上的小浮层):
     设置窗口、独立配置面板、目录选择、Provider 选择/添加 Provider、信任确认弹窗。
   两个要点:
     一、遮罩别压黑 —— 全部换成 --piw-scrim-modal(浅色系 = 白雾,深色系 = 深雾),
         否则就是“0.35 白 叠 0.38 黑 = 灰”的泥色。
     二、窗口底色 = --bg-panel(0.35,与左栏同档) + backdrop 模糊;
         不能用浮层档 --tint-popover(0.6):窗口内部的 --bg-panel 侧栏列/卡片
         会叠到 ≈0.74 一列发白(设置里的 config-sidebar 就是这个坑)。
   小浮层(下拉/小弹窗)不受影响,继续走 7.1 的 --tint-popover。

   信任确认弹窗(.project-trust-*)是**类名 + 静态 CSS**画的一族(role 只有 presentation/dialog,
   没有内联底色),所以 7.1 / 7.4 里那些 [style*=...] 选择器一个也命中不到:
    · 遮罩 .project-trust-backdrop:pi-web 写的是 rgba(0,0,0,.4),
      浅色系下就是“白玻璃 + 0.4 黑纱 = 灰扑扑”的泥色(同 7.4 第一条);
    · 窗口 .project-trust-dialog:底色 var(--bg-panel) 本来就对,但没有任何模糊,
      0.35 的平底压在遮罩上,背后的字看得一清二楚。
   两处分别去下面两条名单里;模糊在下方的 @supports 里补。 */
.settings-dialog-backdrop,
.config-panel-root.is-modal,
.directory-picker-backdrop,
.project-trust-backdrop,
[style*="position: fixed"][style*="inset: 0"][style*="background: rgba(0, 0, 0"] {
  background: var(--piw-scrim-modal) !important;
}
.settings-dialog-backdrop > .settings-dialog-surface,
.config-panel-root.is-modal > .config-panel-surface,
.directory-picker-panel,
.project-trust-dialog {
  background: var(--bg-panel) !important;
}
/* 例外:内容密的“表单型”弹窗 —— 目前就是「添加 Provider」(内联全屏遮罩的直接子,
   面板写的是 background: var(--bg))。它里面有搜索框 + provider 卡片 + 底部按钮,
   用 0.35 时背后的聊天文字会透出来(实测“有点太透”),所以用浮层档
   --piw-popover-bg(0.6);要更透/更实直接调 --tint-popover。
   注:7.1 已把同一选择器列进模糊名单,这里只改底色,模糊不受影响。 */
[style*="position: fixed"][style*="inset: 0"] > div[style*="background: var(--bg)"] {
  background: var(--piw-popover-bg) !important;
}
@supports ((backdrop-filter: blur(1px)) or (-webkit-backdrop-filter: blur(1px))) {
  /* 确认弹窗:一类是 inline 的 var(--bg-panel)(7.1 名单里没有它),
     另一类是类名画的 .project-trust-dialog。两者都补上模糊,
     否则只是一块平底、没有磨砂。 */
  [role="dialog"][style*="background: var(--bg-panel)"],
  .project-trust-dialog {
    backdrop-filter: var(--piw-backdrop) !important;
    -webkit-backdrop-filter: var(--piw-backdrop) !important;
  }
}

/* ── 7.5. 左栏的下拉菜单(.sidebar-menu):归入 §7.1 同一档小浮层 ──────
   现象:点左栏项目行的「…」(session-tree-group-action)等按钮弹出的菜单,
   以及左栏其它下拉(会话操作/模型/技能……)全都“透明得像贴纸”——
   背后的左栏文字、聊天文字清晰可见。
   原因:pi-web 给 .sidebar-menu 画的是 background: var(--bg),而 --bg 是
   **内容面**档(--tint,默认 0.56)并且没有 backdrop-filter,它既要压在左栏
   (已有 0.65 的面板)上,又要盖住聊天区文字,所以必须走浮层档。
   配方与 §7.1 完全一致:--piw-popover-bg(0.6)+ --piw-backdrop 模糊;
   要整体更透/更实改 --tint-popover,不要单独动这里。
   注:.sidebar-menu 由 pi-web 挂到 document.body(portal),祖先上没有
   backdrop-filter,模糊能直接作用到壁纸那一层,不存在 §2.1 的 backdrop root 问题。 */
.sidebar-menu {
  background: var(--piw-popover-bg) !important;
  backdrop-filter: var(--piw-backdrop) !important;
  -webkit-backdrop-filter: var(--piw-backdrop) !important;
}

/* minimap 轨道上的小节点:pi-web 画的是 8x8 小方块(borderRadius:2),
   改成圆点,和轨道的“点”语义更配。节点容器 = [data-minimap-node-index]。 */
[data-minimap-node-index] > div {
  border-radius: 50% !important;
}
CSS
}

# ── 输出 + 注入修订号 ────────────────────────────────────────────
# 修订号 = rN(手工)+ 生成物内容 sha256 前 8 位(自动):内容变了它一定变,
# “页面上生效的是哪一版”可以一眼对上(运行时读 --piw-rev)。
# 算 sha 前先把「生成时间」占位化 —— 否则同一份 CSS 每次生成修订号都不同。
TMP0="$(mktemp)"
TMP="$(mktemp)"
TMP_OUT="$(mktemp)"
trap 'rm -f "$TMP0" "$TMP" "$TMP_OUT"' EXIT
emit_css >"$TMP0"
sed 's/__PIW_STAMP__/__STAMP__/g' "$TMP0" >"$TMP"
SHA8="$(sha256sum "$TMP" | cut -c1-8)"
REV_TAG="r${PROJECT_REV}-${SHA8}"
sed -e "s/__PIW_REV__/$REV_TAG/g" -e "s/__PIW_STAMP__/$STAMP/g" "$TMP0" >"$TMP_OUT"
printf '\n/* 运行时修订号(DevTools Console):\n     getComputedStyle(document.documentElement).getPropertyValue("--piw-rev")\n   与本文件头部「修订:」一致 = 页面生效的就是这一版。 */\n:root { --piw-rev: "%s"; }\n' "$REV_TAG" >>"$TMP_OUT"

if [ -n "$OUT" ]; then
	cat "$TMP_OUT" >"$OUT"
	warn "已生成:$OUT"
	warn "修订:$REV_TAG"
	warn "接下来:打开该文件 → 全选复制 → 粘到 Stylus 样式里 → 保存 → 刷新 pi-web(Ctrl+R)。"
	warn "核对:在 pi-web 页面 Console 里执行"
	warn '  getComputedStyle(document.documentElement).getPropertyValue("--piw-rev")'
	warn "返回值与本文件头部「修订:」一致,才说明贴的是新版本。"
else
	cat "$TMP_OUT"
fi
