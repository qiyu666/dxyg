const fs = require('fs');
const path = require('path');
const D = __dirname;
let html = fs.readFileSync(path.join(D, 'index.html'), 'utf8');
const css = fs.readFileSync(path.join(D, 'style.css'), 'utf8');
const js = fs.readFileSync(path.join(D, 'game.js'), 'utf8')
  .replace(/try \{ if \('serviceWorker'[^\n]*\n/, '');

// 去掉 manifest / sw / 外部 css 引用
html = html.replace(/\s*<link rel="manifest"[^>]*>/, '');
html = html.replace(/\s*<link rel="apple-touch-icon"[^>]*>/, '');
html = html.replace(/\s*<link rel="stylesheet"[^>]*>/, `\n<style>\n${css}\n</style>`);

// 逐个内联外部 <script src="...">（maps/ 各专属地图 + game.js，保持文档顺序）
html = html.replace(/<script src="([^"]+)"><\/script>/g, (m, src) => {
  const clean = src.replace(/\?v=\d+/, '');
  let body = null;
  if (clean === 'game.js') body = js;
  else if (clean.startsWith('maps/')) {
    try { body = fs.readFileSync(path.join(D, clean), 'utf8'); }
    catch (e) { throw new Error('缺少地图文件：' + clean); }
  }
  if (body == null) return m;   // 非本地脚本，保持原样
  return `\n<script>\n${body}\n</script>`;
});

fs.writeFileSync(path.join(D, 'ant-kingdom.html'), html);
console.log('built ant-kingdom.html', (html.length / 1024).toFixed(1) + 'KB');
