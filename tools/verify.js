/* pi-web Stylus 主题 · 浏览器自检片段
 *
 * 用法:pi-web 页面 → F12 → Console → 整段粘贴 → 回车
 * 作用:① 确认页面生效的是哪一版(--piw-rev)
 *       ② 各浮层的不透明度/模糊/层叠是否按设计生效
 *       ③ §6.5 输入框与消息列是否逐像素对齐、§6.6 底部层有没有压住轨道
 *
 * 面板只在展开时才会出现在 DOM 里:想检查哪个就先展开哪个。
 */
(() => {
  const ok = b => (b ? '✓' : '✗');

  // ── ① 修订号 ────────────────────────────────────────────────
  const rev = getComputedStyle(document.documentElement).getPropertyValue('--piw-rev').trim();
  console.log('%c修订号 --piw-rev = ' + (rev || '(空 → Stylus 里这份 CSS 是旧的或没生效)'),
    'font-weight:700;color:' + (rev ? '#0a0' : '#c00'));

  // ── ② 浮层 ──────────────────────────────────────────────────
  const layers = el => getComputedStyle(el).backgroundImage.split('linear-gradient').length - 1;
  const GROUPS = {
    '面板类 --bg-panel(期望 3 层)': [
      ['.right-panel-container', '右栏容器'],
      ['.session-info-popover', '顶栏·会话'],
      ['.system-prompt-panel', '顶栏·系统'],
      ['.tool-definitions-panel', '顶栏·工具'],
      ['[role="listbox"][style*="background: var(--bg-panel)"]', '顶栏·子会话'],
      ['[style*="position: fixed"][style*="background: var(--bg-panel)"]', '顶栏·分支'],
    ],
    '浮层类 --bg(期望 6 层)': [
      ['.notice-shelf-item', '右上角 toast'],
      ['[role="dialog"][style*="background: var(--bg)"]', '扩展待确认窗'],
      ['.settings-dialog-surface', '设置面板'],
      ['.directory-picker-panel', '选择目录弹窗'],
      ['[style*="position: fixed"][style*="inset: 0"] > div[style*="background: var(--bg)"]', '添加 Provider 弹窗(无类名/无 role)'],
      ['[style*="position: fixed"][style*="background: var(--bg)"]', '下拉(fixed)'],
      ['[style*="position: absolute"][style*="background: var(--bg)"]', '下拉(absolute)'],
    ],
  };
  for (const [title, list] of Object.entries(GROUPS)) {
    console.group(title);
    for (const [sel, label] of list) {
      const el = document.querySelector(sel);
      if (!el) { console.log(`  ${label} → 没打开`); continue; }
      const cs = getComputedStyle(el);
      const r = el.getBoundingClientRect();
      const at = document.elementFromPoint(r.left + r.width / 2, r.top + r.height / 2);
      const onTop = at === el || el.contains(at);
      console.log(`  ${label} → ${layers(el)} 层 | ${cs.backdropFilter} | 底色 ${cs.backgroundColor}` +
        ` | 层叠 ${ok(onTop)}${onTop ? '' : ' 被 ' + at.tagName + '.' + at.className + ' 盖住(会被要求改 §6 选择器)'}`);
    }
    console.groupEnd();
  }

  // ── ③ §6.5 输入框对齐 ───────────────────────────────────────
  const fs = document.querySelector('fieldset:has(textarea.chat-input-textarea)');
  const col = document.querySelector('.scrollbar-subtle.min-w-0.flex-1 > div > div');
  if (fs && col) {
    const b = fs.querySelector('textarea.chat-input-textarea').parentElement.getBoundingClientRect();
    const c = col.getBoundingClientRect();
    const aligned = Math.abs(b.left - c.left) <= 1 && Math.abs(b.right - c.right) <= 1;
    console.log(`§6.5 输入框 ${ok(aligned)} 输入框盒 ${Math.round(b.left)}..${Math.round(b.right)}` +
      ` | 消息列 ${Math.round(c.left)}..${Math.round(c.right)}`);
  }

  // ── ④ §6.6 底部层不覆盖轨道 ────────────────────────────────
  const rail = document.querySelector('div[style*="width: 36px"]');
  const bottom = document.querySelector('div.relative.shrink-0:has(> fieldset textarea.chat-input-textarea)');
  if (rail && bottom) {
    const rb = rail.getBoundingClientRect(), bb = bottom.getBoundingClientRect();
    const clear = bb.right <= rb.left + 1;
    console.log(`§6.6 让出轨道 ${ok(clear)} 底部层右边界 ${Math.round(bb.right)} | 轨道左边界 ${Math.round(rb.left)}`);
  }

  // ── ⑤ §6.7 轨道列与左栏同质感 ───────────────────
  const cc = document.querySelector('.chat-content');
  if (cc) {
    const hasStripe = getComputedStyle(cc).backgroundImage.includes('linear-gradient');
    console.log(`§6.7 轨道补画 ${ok(hasStripe)} .chat-content 的 background-image ${hasStripe ? '含渐变' : '不含'}` +
      `${rail ? '' : '(轨道未显示,短会话时属正常)'}`);
  }
  if (rail) {
    const rc = getComputedStyle(rail);
    const transparent = /rgba?\(0, 0, 0, 0\)|transparent/.test(rc.backgroundColor);
    const frost = rc.backdropFilter && rc.backdropFilter !== 'none';
    console.log(`§6.7 轨道不与补画层叠色 ${ok(transparent)} 轨道底色 ${rc.backgroundColor}`);
    console.log(`§6.7 轨道磨砂 ${ok(frost)} backdrop-filter ${rc.backdropFilter}`);
  }

  // ── ⑥ §6.1 面板分隔线已去掉 ─────────────────────────
  const none = v => /rgba?\(0, 0, 0, 0\)|transparent/.test(v);
  const sb = document.querySelector('#session-sidebar');
  if (sb) {
    const b = getComputedStyle(sb).borderRightColor;
    console.log(`§6.1 左栏右边线已去 ${ok(none(b))} border-right-color ${b}`);
  }
  const top = document.querySelector('div:has(> div > .chat-content) > div[style*="background: var(--bg-panel)"][style*="flex-shrink: 0"] > div:first-child');
  if (top) {
    const b = getComputedStyle(top).borderBottomColor;
    console.log(`§6.1 顶栏下边线已去 ${ok(none(b))} border-bottom-color ${b}`);
  }
  const topbar = document.querySelector('div:has(> div > .chat-content) > div[style*="background: var(--bg-panel)"][style*="flex-shrink: 0"]');
  if (topbar) {
    console.log(`§6   顶栏已抬升 ${ok(getComputedStyle(topbar).zIndex === '50')} z-index ${getComputedStyle(topbar).zIndex}`);
  }
  const tabBtn = document.querySelector('div:has(> div > .chat-content) > div[style*="background: var(--bg-panel)"][style*="flex-shrink: 0"] > div:first-child button');
  if (tabBtn) {
    const cs = getComputedStyle(tabBtn);
    console.log(`§6.1 顶栏按钮圆角 ${ok(parseFloat(cs.borderRadius) > 0)} ${cs.borderRadius}` +
      ` | 右边线 ${none(cs.borderRightColor) ? '已去 ✓' : cs.borderRightColor}`);
  }
  if (cc) {
    const noLine = !getComputedStyle(cc).backgroundImage.includes('var(--border)');
    console.log(`§6.1 轨道左竖线已去 ${ok(noLine)} .chat-content 渐变 ${noLine ? '不含 --border' : '仍含 --border'}`);
  }
  const node = document.querySelector('[data-minimap-node-index] > div');
  if (node) {
    console.log(`§6.8 minimap 节点圆点 ${ok(getComputedStyle(node).borderRadius.includes('%'))} ${getComputedStyle(node).borderRadius}`);
  }
  const composer = document.querySelector('div:has(> textarea.chat-input-textarea)');
  if (composer) {
    const cs = getComputedStyle(composer);
    console.log(`§6.5b 输入框外层底色已去 ${ok(none(cs.backgroundColor))} ${cs.backgroundColor}` +
      ` | 描边 ${cs.borderTopColor} | 投影 ${cs.boxShadow === 'none' ? '无' : '有'}`);
  }
  const ta = document.querySelector('textarea.chat-input-textarea');
  if (ta) {
    const bd = getComputedStyle(ta).backdropFilter;
    console.log(`§6.5b 输入框 textarea 无 backdrop ${ok(!bd || bd === 'none')} ${bd}`);
  }
  const fp = document.querySelector('#file-panel');  if (fp && fp.getBoundingClientRect().width > 0) {
    console.log(`§6.6 文件面板左边线已去 ${ok(none(getComputedStyle(fp).borderLeftColor))} ${getComputedStyle(fp).borderLeftColor}`);
    const fh = fp.firstElementChild;
    if (fh) console.log(`§6.6 文件面板头部下边线已去 ${ok(none(getComputedStyle(fh).borderBottomColor))} ${getComputedStyle(fh).borderBottomColor}`);
    const fb = fp.querySelector(':scope > div:first-child > button');
    if (fb) console.log(`§6.6 文件面板按钮默认底色 ${ok(none(getComputedStyle(fb).backgroundColor))} ${getComputedStyle(fb).backgroundColor}`);
  } else {
    console.log('§6.6 文件面板未展开,跳过其边线/按钮检查');
  }
})();
