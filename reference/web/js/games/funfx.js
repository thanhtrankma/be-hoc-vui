// Hiệu ứng chuyển động dùng chung cho game Khu vui chơi (nhóm Chuyển động A): sprite sheet an toàn, rung màn mượt,
// nổ/khói bằng sprite, bụi/tia lửa (bể hạt cấp sẵn, không cấp phát mỗi khung), easing, nền cuộn nhiều lớp.
import {loadSheet, drawFrame, frameAt} from './sheets.js?v=4c51d34a6e';

// Tải sheet; lỗi mạng thì trả null (drawFrame bỏ qua sheet null) để game vẫn chạy.
export const sheet = name => loadSheet(name).catch(() => null);
export const sheets = names => Promise.all(names.map(sheet));
// Vẽ khung theo chiều cao h (rộng theo tỉ lệ). opts: {flip, rot, alpha}
export const spr = (ctx, sh, frame, x, y, h, opts) => { if (sh) drawFrame(ctx, sh, frame, x, y, h, opts); };
export const anim = (ctx, sh, name, t, x, y, h, opts) => { if (sh) drawFrame(ctx, sh, frameAt(sh, name, t), x, y, h, opts); };
// Vẽ khung theo bề rộng w.
export function sprW(ctx, sh, frame, x, y, w, opts) {
  const f = sh?.frames?.[frame]; if (!f) return;
  drawFrame(ctx, sh, frame, x, y, w * f[3] / f[2], opts);
}
// Vẽ khung kéo giãn đúng w×h (gạch, thanh đỡ).
export function sprBox(ctx, sh, frame, x, y, w, h, alpha = 1) {
  const f = sh?.frames?.[frame]; if (!f || !sh.img.naturalWidth) return;
  if (alpha !== 1) ctx.globalAlpha = alpha;
  ctx.drawImage(sh.img, f[0], f[1], f[2], f[3], x - w / 2, y - h / 2, w, h);
  if (alpha !== 1) ctx.globalAlpha = 1;
}
// Tỉ lệ rộng/cao của khung.
export const aspect = (sh, frame) => { const f = sh?.frames?.[frame]; return f ? f[2] / f[3] : 1; };

// Easing
export const clamp = (v, a = 0, b = 1) => v < a ? a : v > b ? b : v;
export const lerp = (a, b, k) => a + (b - a) * k;
export const easeOut = k => 1 - (1 - k) * (1 - k) * (1 - k);
export const easeIn = k => k * k * k;
export const easeOutBack = k => { const c = 1.70158; return 1 + (c + 1) * Math.pow(k - 1, 3) + c * Math.pow(k - 1, 2); };
export const easeOutElastic = k => k <= 0 ? 0 : k >= 1 ? 1 : Math.pow(2, -10 * k) * Math.sin((k * 10 - .75) * 2.094) + 1;
// Tiến dần về đích không phụ thuộc FPS (rate: phần trăm còn lại mỗi giây).
export const approach = (v, target, rate, dt) => target + (v - target) * Math.exp(-rate * dt);

// Rung màn: add(lực) cộng dồn, tắt dần mượt, rung theo sóng sin (không nhảy loạn từng khung).
export function shaker() {
  let p = 0, t = 0;
  return {
    add(k) { p = Math.min(18, p + k); },
    update(dt) { t += dt; p = Math.max(0, p - dt * (p * 4 + 8)); },
    apply(ctx) { if (p > .2) ctx.translate(Math.sin(t * 61) * p, Math.cos(t * 47) * p * .8); },
    get power() { return p; }
  };
}

// Hạt bụi/khói/tia lửa: bể N hạt cấp sẵn. kind: 0 tròn mờ dần to ra (khói, bụi), 1 tia (vệt theo vận tốc), 2 vụn rơi theo trọng lực.
export function dust(N = 220) {
  const P = Array.from({length: N}, () => ({on: false, x: 0, y: 0, vx: 0, vy: 0, life: 0, max: 1, r: 4, grow: 0, c: '#fff', k: 0, g: 0, a: 1}));
  let next = 0;
  return {
    emit(x, y, vx, vy, {life = .6, r = 5, grow = 20, c = 'rgba(200,200,200,1)', k = 0, g = 0, a = .7} = {}) {
      const p = P[next]; next = (next + 1) % N;
      p.on = true; p.x = x; p.y = y; p.vx = vx; p.vy = vy; p.life = p.max = life; p.r = r; p.grow = grow; p.c = c; p.k = k; p.g = g; p.a = a;
    },
    // Vòng nổ tia lửa
    sparks(x, y, n = 12, c = '#ffd43b', sp = 260) {
      for (let i = 0; i < n; i++) { const a = Math.random() * 6.283, v = sp * (.4 + Math.random() * .8); this.emit(x, y, Math.cos(a) * v, Math.sin(a) * v, {life: .25 + Math.random() * .3, r: 2.5, grow: 0, c, k: 1, a: 1}); }
    },
    puff(x, y, n = 6, c = 'rgba(230,230,230,1)', sp = 60, r = 8) {
      for (let i = 0; i < n; i++) { const a = Math.random() * 6.283, v = sp * Math.random(); this.emit(x, y, Math.cos(a) * v, Math.sin(a) * v - 20, {life: .5 + Math.random() * .4, r: r * (.6 + Math.random() * .6), grow: r * 3, c, a: .55}); }
    },
    debris(x, y, n = 10, c = '#8d5524', sp = 300) {
      for (let i = 0; i < n; i++) { const a = -Math.random() * 3.14, v = sp * (.4 + Math.random() * .7); this.emit(x, y, Math.cos(a) * v, Math.sin(a) * v, {life: .6 + Math.random() * .4, r: 3 + Math.random() * 3, grow: 0, c, k: 2, g: 900, a: 1}); }
    },
    update(dt) {
      for (const p of P) {
        if (!p.on) continue;
        p.life -= dt; if (p.life <= 0) { p.on = false; continue; }
        p.vy += p.g * dt; p.x += p.vx * dt; p.y += p.vy * dt;
        if (p.k === 0) { p.vx *= 1 - dt * 2; p.vy *= 1 - dt * 2; }
      }
    },
    draw(ctx, ox = 0, oy = 0) {
      for (const p of P) {
        if (!p.on) continue;
        const k = p.life / p.max;
        ctx.globalAlpha = p.a * (p.k === 0 ? k : Math.min(1, k * 2));
        ctx.fillStyle = p.c;
        if (p.k === 1) { ctx.strokeStyle = p.c; ctx.lineWidth = p.r; ctx.beginPath(); ctx.moveTo(p.x - ox, p.y - oy); ctx.lineTo(p.x - ox - p.vx * .04, p.y - oy - p.vy * .04); ctx.stroke(); }
        else { ctx.beginPath(); ctx.arc(p.x - ox, p.y - oy, p.r + p.grow * (1 - k), 0, 6.283); ctx.fill(); }
      }
      ctx.globalAlpha = 1;
    },
    clear() { for (const p of P) p.on = false; }
  };
}

// Nổ bằng sprite (fxa/fx: boom, smoke) — bể cấp sẵn.
export function booms(fxs, N = 24) {
  const B = Array.from({length: N}, () => ({on: false, x: 0, y: 0, s: 0, t: 0, k: 'boom', rot: 0}));
  let next = 0;
  return {
    add(x, y, s = 90, k = 'boom') { const b = B[next]; next = (next + 1) % N; b.on = true; b.x = x; b.y = y; b.s = s; b.t = 0; b.k = k; b.rot = Math.random() * 6.28; },
    update(dt) { for (const b of B) if (b.on) { b.t += dt; if (b.t > .36) b.on = false; } },
    draw(ctx, ox = 0, oy = 0) {
      for (const b of B) if (b.on) {
        const k = b.t / .36;
        anim(ctx, fxs, b.k, b.t, b.x - ox, b.y - oy, b.s * (.7 + easeOut(Math.min(1, k * 1.6)) * .5), {rot: b.rot, alpha: k > .7 ? (1 - k) / .3 : 1});
      }
    }
  };
}

// Dải ảnh lặp ngang (nền cuộn parallax): vẽ khung frame cao h, lặp theo trục x, dịch theo off.
export function stripX(ctx, sh, frame, off, y, h, W, alpha = 1) {
  const f = sh?.frames?.[frame]; if (!f || !sh.img.naturalWidth) return;
  const w = h * f[2] / f[3];
  let x = -(((off % w) + w) % w);
  if (alpha !== 1) ctx.globalAlpha = alpha;
  for (; x < W; x += w - 1) ctx.drawImage(sh.img, f[0], f[1], f[2], f[3], x, y, w, h);
  if (alpha !== 1) ctx.globalAlpha = 1;
}
// Lát kín một vùng bằng ô vuông (nền xe tăng, không gian), dịch theo offX/offY.
export function tile(ctx, sh, frame, size, offX, offY, x0, y0, W, H) {
  const f = sh?.frames?.[frame]; if (!f || !sh.img.naturalWidth) return;
  const sx = -(((offX % size) + size) % size), sy = -(((offY % size) + size) % size);
  for (let y = y0 + sy; y < y0 + H; y += size - .5) for (let x = x0 + sx; x < x0 + W; x += size - .5) ctx.drawImage(sh.img, f[0], f[1], f[2], f[3], x, y, size, size);
}

// Chữ điểm nảy (dùng cùng fx() của funcore): co giãn khi hiện. Ở đây chỉ là tiện ích scale nảy theo tuổi a (0..1).
export const popScale = a => a < .25 ? easeOutBack(a / .25) : 1;

// Dải ảnh lặp ngang, chỉ lấy phần dưới của khung từ tỉ lệ top (0..1) — dùng cho đồi/cây nền mà bỏ phần trời.
export function stripPart(ctx, sh, frame, off, y, h, W, top = 0, alpha = 1) {
  const f = sh?.frames?.[frame]; if (!f || !sh.img.naturalWidth) return;
  const sy = f[1] + f[3] * top, sh2 = f[3] * (1 - top), w = h * f[2] / sh2;
  let x = -(((off % w) + w) % w);
  if (alpha !== 1) ctx.globalAlpha = alpha;
  for (; x < W; x += w - 1) ctx.drawImage(sh.img, f[0], sy, f[2], sh2, x, y, w, h);
  if (alpha !== 1) ctx.globalAlpha = 1;
}
// Nền platformer theo cảnh funcore THEMES (Đồng cỏ, Sa mạc, Xứ tuyết, Thành phố đêm, Rừng kẹo, Núi lửa)
export const PLAT_BG = ['color_hills', 'color_desert', 'color_trees', 'color_trees', 'color_mushrooms', 'color_desert'];
export const PLAT_GROUND = ['grass', 'sand', 'snow', 'stone', 'purple', 'dirt'];
const GROUND_FILL = {grass: '#e0895a', sand: '#e0895a', snow: '#b9c0ca', stone: '#b6bcc6', purple: '#b9c0ca', dirt: '#b9c0ca'};
// Mặt đất lát gạch Kenney: hàng mặt trên + phần đất bên dưới, cuộn theo off.
export function groundTiles(ctx, tiles, lv, off, y, W, H, size = 64) {
  const g = PLAT_GROUND[Math.floor(lv / 10) % PLAT_GROUND.length];
  stripX(ctx, tiles, `terrain_${g}_block_top`, off, y, size, W);
  // Một hàng đất có vân rồi tô phẳng màu đất bên dưới (đỡ rối mắt, ít lệnh vẽ)
  if (y + size < H) stripX(ctx, tiles, `terrain_${g}_block_center`, off, y + size - 1, size, W);
  if (y + size * 2 < H && tiles) { ctx.fillStyle = GROUND_FILL[g]; ctx.fillRect(0, y + size * 2 - 2, W, H - y - size * 2 + 2); }
}
// Đồi/cây xa (parallax) phía sau mặt đất.
export function backHills(ctx, bg, lv, off, groundY, h, W, alpha = 1) {
  stripPart(ctx, bg, PLAT_BG[Math.floor(lv / 10) % PLAT_BG.length], off, groundY - h, h, W, .3, alpha);
}

// Đồng xu xoay (co giãn ngang theo cos, giữ mặt sáng) — fxa/fx khung 'coin'.
export function coin(ctx, fxs, t, x, y, s) {
  const f = fxs?.frames?.coin; if (!f || !fxs.img.naturalWidth) return;
  const k = Math.cos(t * 4), w = s * Math.max(.18, Math.abs(k));
  ctx.drawImage(fxs.img, f[0], f[1], f[2], f[3], x - w / 2, y - s / 2, w, s);
}
