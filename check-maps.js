#!/usr/bin/env node
/* ============================================================
 * check-maps.js —— maps/ 地图文件校验
 *
 * 用法：
 *   node check-maps.js            校验 maps/ 下所有地图文件
 *   node check-maps.js 1-1       校验指定地图（可多个：1-1,1-2）
 *
 * 校验项（与引擎 plantLayout 一致）：
 *   1) layout 是行数组；行可不等长（j≥行长 = void）
 *   2) 蚁后落点 = 所有 Q 的质心（无 Q 则取矩形中心，会标 ⚠）；蚁后 7 格不能被基岩盖/被埋藏占
 *   3) 以蚁后为中心 BFS：所有埋藏（s/b/B/w/u/f）必须可挖到（不被基岩围死/隔断）
 *   4) l = 空室：l 连通块围住的内部（土/埋藏）在该室任一 l 被挖到后一次释放（校验 l 格可挖）
 *
 * 字符：# 基岩  . 土  s 蜘蛛 b 甲虫 B 成年甲虫 w 面包虫 u 鼠妇 f 食物  Q 蚁后参考  l 空室(被围内部挖到即释放)  (空格) void
 *
 * 视觉核对请开 maps_preview.html（浏览器，用游戏真实画布渲染）。
 * ============================================================ */
const fs = require('fs');
const path = require('path');
const D = __dirname;
const DIRS = [[1, 0], [1, -1], [0, -1], [-1, 0], [-1, 1], [0, 1]];
const CONTENT = new Set(['s', 'b', 'B', 'w', 'u', 'f']);
const QUEEN_7 = [[0, 0], [1, 0], [1, -1], [0, -1], [-1, 0], [-1, 1], [0, 1]];
function hdist(q, r) { return (Math.abs(q) + Math.abs(r) + Math.abs(q + r)) / 2; }

function loadMaps(filter) {
  const sandbox = { window: {} };
  for (const f of fs.readdirSync(path.join(D, 'maps')).filter(f => f.endsWith('.js'))) {
    new Function('window', fs.readFileSync(path.join(D, 'maps', f), 'utf8'))(sandbox.window);
  }
  const all = sandbox.window.ANT_MAPS || {};
  if (filter && filter.length) { const keep = {}; for (const id of filter) if (all[id]) keep[id] = all[id]; return keep; }
  return all;
}

function check(name, m) {
  const L = m.layout;
  if (!Array.isArray(L) || L.length < 3) { console.log(`  ✗ [${name}] layout 不是有效的行数组`); return false; }
  const R = L.length;
  const issues = [];
  // 蚁后落点 = 所有 Q 的质心（无 Q 取矩形中心）——与引擎 plantLayout 一致
  let si = 0, sj = 0, sq = 0;
  for (let i = 0; i < R; i++) for (let j = 0; j < L[i].length; j++) if (L[i][j] === 'Q') { si += i; sj += j; sq++; }
  const rowQ = sq ? Math.round(si / sq) : Math.floor(R / 2);
  const colQ = sq ? Math.round(sj / sq) : Math.floor(Math.max(...L.map(r => r.length)) / 2);
  // 地图格集合（非空格）
  const mapCells = new Set();
  for (let i = 0; i < R; i++) for (let j = 0; j < L[i].length; j++) {
    const ch = L[i][j];
    if (ch === ' ') continue;
    mapCells.add((j - colQ) + ',' + (i - rowQ));
  }
  // 蚁后 7 格不能被基岩盖
  for (const [dq, dr] of QUEEN_7) {
    const q = dq, r = dr;
    const li = r + rowQ, lj = q + colQ;
    const c = L[li] && lj < L[li].length ? L[li][lj] : undefined;
    if (c === '#') issues.push(`蚁后 7 格 (q=${q},r=${r}) 被基岩盖住`);
    else if (c !== undefined && CONTENT.has(c)) issues.push(`蚁后 7 格 (q=${q},r=${r}) 被埋藏 '${c}' 占用`);
  }
  // 可走格 = 非基岩的地图格；蚁后(0,0) BFS 验证埋藏可达
  const walkable = (q, r) => { const k = q + ',' + r; return mapCells.has(k) && L[r + rowQ] && L[r + rowQ][q + colQ] !== '#'; };
  const seen = new Set();
  if (walkable(0, 0)) {
    const queue = [[0, 0]];
    while (queue.length) {
      const [q, r] = queue.shift(); const k = q + ',' + r; if (seen.has(k)) continue; seen.add(k);
      for (const [dq, dr] of DIRS) { const nq = q + dq, nr = r + dr; if (walkable(nq, nr) && !seen.has(nq + ',' + nr)) queue.push([nq, nr]); }
    }
  } else issues.push('蚁后落点不是可挖土格（被基岩盖或为 void），开局无法向外挖');
  let unreach = [];
  for (const k of mapCells) {
    const [q, r] = k.split(',').map(Number);
    const c = L[r + rowQ] && L[r + rowQ][q + colQ];
    if (c && CONTENT.has(c) && !seen.has(k)) unreach.push(`${c}@(${q},${r})`);
  }
  if (unreach.length) issues.push(`有 ${unreach.length} 个埋藏挖不到（被基岩围死/隔断）：` + unreach.slice(0, 8).join(' ') + (unreach.length > 8 ? ' …' : ''));
  // 统计
  const cnt = {};
  for (const k of mapCells) { const [q, r] = k.split(',').map(Number); const c = L[r + rowQ][q + colQ]; cnt[c] = (cnt[c] || 0) + 1; }
  const stat = '#基岩×' + (cnt['#'] || 0) + ' 土×' + (cnt['.'] || 0)
    + ' 蜘蛛×' + (cnt['s'] || 0) + ' 甲虫×' + (cnt['b'] || 0) + ' 成虫×' + (cnt['B'] || 0)
    + ' 食物×' + (cnt['f'] || 0) + ' 面包虫×' + (cnt['w'] || 0) + ' 鼠妇×' + (cnt['u'] || 0)
    + (cnt['l'] ? (' 空室×' + cnt['l']) : '')
    + (sq ? '' : '  ⚠无Q标记(蚁后默认居矩形中心)');
  if (issues.length) { console.log(`  ✗ [${name}] ${R}行`); issues.forEach(x => console.log('    - ' + x)); return false; }
  console.log(`  ✓ [${name}] ${R}行×${Math.max(...L.map(r => r.length))}列(可不等长) ${stat}  蚁后@质心、埋藏连通可达`);
  return true;
}

const args = process.argv.slice(2);
const filter = args.filter(a => a && a !== 'shot');
let maps;
try { maps = loadMaps(filter); } catch (e) { console.error('地图文件加载失败：' + e.message); process.exit(1); }
if (!Object.keys(maps).length) { console.error(filter && filter.length ? '没有匹配 ' + filter.join(',') + '（现有：' + Object.keys(loadMaps()).join(',') + '）' : 'maps/ 为空'); process.exit(1); }
console.log('校验地图：' + Object.keys(maps).join(', '));
let ok = true;
for (const id of Object.keys(maps)) ok = check(id, maps[id]) && ok;
process.exit(ok ? 0 : 1);
