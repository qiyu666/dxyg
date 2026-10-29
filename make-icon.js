// 生成应用图标 PNG（纯 Node，无第三方依赖）
const fs = require('fs');
const zlib = require('zlib');
const path = require('path');

function png(w, h, rgba) {
  function chunk(type, data) {
    const len = Buffer.alloc(4); len.writeUInt32BE(data.length, 0);
    const t = Buffer.from(type, 'ascii');
    const body = Buffer.concat([t, data]);
    const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(body) >>> 0, 0);
    return Buffer.concat([len, body, crc]);
  }
  const sig = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8; ihdr[9] = 6; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  // raw with filter byte 0 per row
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (w * 4 + 1)] = 0;
    rgba.copy(raw, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4);
  }
  const idat = zlib.deflateSync(raw, { level: 9 });
  return Buffer.concat([sig, chunk('IHDR', ihdr), chunk('IDAT', idat), chunk('IEND', Buffer.alloc(0))]);
}
function crc32(buf) {
  let c, crc = 0xffffffff;
  for (let n = 0; n < buf.length; n++) {
    c = (crc ^ buf[n]) & 0xff;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    crc = (crc >>> 8) ^ c;
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function render(S) {
  const SS = 3, W = S * SS, H = S * SS;
  const px = Buffer.alloc(W * H * 4);
  function set(x, y, r, g, b, a) {
    if (x < 0 || y < 0 || x >= W || y >= H) return;
    const i = (y * W + x) * 4;
    const sa = a / 255;
    px[i] = px[i] * (1 - sa) + r * sa;
    px[i + 1] = px[i + 1] * (1 - sa) + g * sa;
    px[i + 2] = px[i + 2] * (1 - sa) + b * sa;
    px[i + 3] = Math.min(255, px[i + 3] + a);
  }
  // 背景圆角矩形渐变
  const rad = 0.22 * W;
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      // 圆角遮罩
      let dx = Math.max(rad - x, 0, x - (W - rad));
      let dy = Math.max(rad - y, 0, y - (H - rad));
      if (dx * dx + dy * dy > rad * rad) continue;
      const t = y / H;
      const r = 26 + (10 - 26) * t, g = 18 + (8 - 18) * t, b = 11 + (6 - 11) * t;
      set(x, y, r, g, b, 255);
    }
  }
  // 暗角/光晕
  const cx = W / 2, cy = H / 2;
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    if (px[(y * W + x) * 4 + 3] === 0) continue;
    const d = Math.hypot(x - cx, y - cy) / (W * 0.6);
    const glow = Math.max(0, 1 - d);
    const g = glow * glow;
    set(x, y, 200 * g, 150 * g, 40 * g, Math.min(120, g * 160));
  }
  function ellipse(cx, cy, rx, ry, rot, r, g, b) {
    const cos = Math.cos(rot), sin = Math.sin(rot);
    const m = Math.max(rx, ry) * 1.05;
    for (let y = -m; y <= m; y++) for (let x = -m; x <= m; x++) {
      const xr = x * cos + y * sin, yr = -x * sin + y * cos;
      if ((xr / rx) ** 2 + (yr / ry) ** 2 <= 1) set(Math.round(cx + x), Math.round(cy + y), r, g, b, 255);
    }
  }
  function line(x0, y0, x1, y1, wdt, r, g, b) {
    const steps = Math.ceil(Math.hypot(x1 - x0, y1 - y0) * 2);
    for (let i = 0; i <= steps; i++) {
      const x = x0 + (x1 - x0) * i / steps, y = y0 + (y1 - y0) * i / steps;
      for (let a = -wdt; a <= wdt; a += 0.7) for (let b2 = -wdt; b2 <= wdt; b2 += 0.7) {
        if (a * a + b2 * b2 <= wdt * wdt) set(Math.round(x + a), Math.round(y + b2), r, g, b, 255);
      }
    }
  }
  const s = S / 512;
  const ox = W / 2 + 0.02 * W, oy = H / 2;
  const A = (v) => v * s * SS;
  // 琥珀六边形光环
  ctxRing(cx, cy, A(150), A(165), 240, 180, 60);
  // 腿
  const legc = [70, 42, 22];
  for (let i = -1; i <= 1; i++) {
    const lx = ox + A(i * 26);
    line(lx, oy, lx - A(30), oy - A(64), A(4), ...legc);
    line(lx, oy, lx - A(30), oy + A(64), A(4), ...legc);
  }
  // 腹部
  ellipse(ox - A(58), oy, A(54), A(42), 0, 60, 36, 18);
  ellipse(ox - A(58), oy, A(40), A(30), 0, 84, 52, 26);
  // 胸
  ellipse(ox, oy, A(30), A(24), 0, 78, 46, 22);
  // 头
  ellipse(ox + A(46), oy, A(32), A(30), 0, 92, 58, 30);
  // 触角
  const anc = [235, 180, 70];
  line(ox + A(64), oy - A(10), ox + A(110), oy - A(58), A(4), ...anc);
  line(ox + A(64), oy + A(10), ox + A(110), oy + A(58), A(4), ...anc);
  // 眼睛
  ellipse(ox + A(58), oy - A(12), A(6), A(6), 0, 20, 10, 5);
  ellipse(ox + A(58), oy + A(12), A(6), A(6), 0, 20, 10, 5);

  function ctxRing(cx, cy, r0, r1, R, G, B) {
    for (let y = -r1 - 6; y <= r1 + 6; y++) for (let x = -r1 - 6; x <= r1 + 6; x++) {
      const d = Math.hypot(x, y);
      if (d >= r0 && d <= r1) {
        const a = 60 + 40 * Math.sin(Math.atan2(y, x) * 6);
        set(Math.round(cx + x), Math.round(cy + y), R, G, B, a);
      }
    }
  }

  // 下采样 SS→S
  const out = Buffer.alloc(S * S * 4);
  for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
    let r = 0, g = 0, b = 0, a = 0, n = 0;
    for (let dy = 0; dy < SS; dy++) for (let dx = 0; dx < SS; dx++) {
      const i = ((y * SS + dy) * W + (x * SS + dx)) * 4;
      r += px[i]; g += px[i + 1]; b += px[i + 2]; a += px[i + 3]; n++;
    }
    const o = (y * S + x) * 4;
    out[o] = r / n; out[o + 1] = g / n; out[o + 2] = b / n; out[o + 3] = a / n;
  }
  return out;
}

const dir = path.join(__dirname, 'assets');
fs.mkdirSync(dir, { recursive: true });
for (const size of [512, 192]) {
  const buf = render(size);
  fs.writeFileSync(path.join(dir, `icon-${size}.png`), png(size, size, buf));
  console.log('wrote icon-' + size + '.png');
}
