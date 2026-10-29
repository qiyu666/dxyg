const fs = require('fs');
const path = require('path');
const D = __dirname;
let html = fs.readFileSync(path.join(D, 'index.html'), 'utf8');
const css = fs.readFileSync(path.join(D, 'style.css'), 'utf8');
const js = fs.readFileSync(path.join(D, 'game.js'), 'utf8')
  .replace(/try \{ if \('serviceWorker'[^\n]*\n/, '');

// 去掉 manifest / sw / 外部 css / 外部 js 引用
html = html.replace(/\s*<link rel="manifest"[^>]*>/, '');
html = html.replace(/\s*<link rel="apple-touch-icon"[^>]*>/, '');
html = html.replace(/\s*<link rel="stylesheet"[^>]*>/, `\n<style>\n${css}\n</style>`);
html = html.replace(/\s*<script src="game\.js(?:\?v=\d+)?"><\/script>/, `\n<script>\n${js}\n</script>`);

fs.writeFileSync(path.join(D, 'ant-kingdom.html'), html);
console.log('built ant-kingdom.html', (html.length / 1024).toFixed(1) + 'KB');
