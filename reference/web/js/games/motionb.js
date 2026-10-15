// Chuyển động dùng chung cho game đối kháng (funvs1/2) và Thế giới phiêu lưu (rpg*) — đợt 15.
// Easing, rung màn, dừng hình khi trúng đòn, hạt bụi/tia lửa/vòng sóng, số sát thương nảy lên,
// vẽ quái từ hình tĩnh có hoạt ảnh thủ tục (đi nhún, lấy đà, lao, choáng, chết) và vẽ sprite Kenney.
import {draw} from './funcore.js?v=4c51d34a6e';
import {loadSheet, drawFrame, frameAt} from './sheets.js?v=4c51d34a6e';

export const clamp01 = v => v < 0 ? 0 : v > 1 ? 1 : v;
export const lerp = (a, b, k) => a + (b - a) * k;
// Tiến tới đích theo hàm mũ, không phụ thuộc FPS (k = tốc độ / giây)
export const approach = (a, b, k, dt) => b + (a - b) * Math.exp(-k * dt);
export const E = {
  outCubic: t => 1 - Math.pow(1 - clamp01(t), 3),
  inCubic: t => Math.pow(clamp01(t), 3),
  inOut: t => { t = clamp01(t); return t < .5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2; },
  outBack: t => { t = clamp01(t); const c = 1.70158; return 1 + (c + 1) * Math.pow(t - 1, 3) + c * Math.pow(t - 1, 2); },
  outElastic: t => { t = clamp01(t); return t === 0 || t === 1 ? t : Math.pow(2, -10 * t) * Math.sin((t * 10 - .75) * 2.0944) + 1; },
  bump: t => Math.sin(clamp01(t) * Math.PI)
};

// Rung màn: add(lực), update(dt), begin(ctx)/end(ctx) bọc phần vẽ cảnh. Dừng hình: stop(giây) -> scale(dt) trả 0 khi đang dừng.
export function camera() {
  let mag = 0, ox = 0, oy = 0, hold = 0, ph = 0;
  return {
    shake(v) { mag = Math.min(22, mag + v); },
    stop(s) { hold = Math.max(hold, s); },
    scale(dt) { if (hold > 0) { hold -= dt; return .08; } return 1; },
    update(dt) { ph += dt * 60; mag *= Math.exp(-dt * 9); if (mag < .25) mag = 0; ox = Math.sin(ph * 1.7) * mag; oy = Math.cos(ph * 2.3) * mag * .8; },
    begin(ctx) { ctx.save(); if (mag) ctx.translate(ox, oy); },
    end(ctx) { ctx.restore(); },
    get mag() { return mag; }
  };
}

// Lớp hiệu ứng: hạt có trọng lực, bụi, tia, vòng sóng, chữ/số nảy (scale outBack). Số lượng giới hạn để không tốn bộ nhớ.
export function fxb() {
  const P = [];
  const add = p => { if (P.length > 260) P.shift(); P.push(p); };
  const rnd = (a, b) => a + Math.random() * (b - a);
  return {
    burst(x, y, n = 12, colors = ['#ffd43b', '#ff922b', '#ff6b6b', '#74c0fc'], sp = 260, g = 500) {
      for (let i = 0; i < n; i++) { const a = Math.random() * 6.283, v = rnd(.35, 1) * sp; add({k: 0, x, y, vx: Math.cos(a) * v, vy: Math.sin(a) * v - sp * .25, g, life: rnd(.35, .75), l0: .75, c: colors[i % colors.length], r: rnd(2.5, 6)}); }
    },
    // Bụi dưới chân: tròn mờ lớn dần
    dust(x, y, n = 5, dir = 0, c = 'rgba(255,255,255,.75)') {
      for (let i = 0; i < n; i++) add({k: 1, x: x + rnd(-8, 8), y: y - rnd(0, 6), vx: (dir || rnd(-1, 1)) * rnd(30, 110), vy: -rnd(10, 50), g: -20, life: rnd(.35, .6), l0: .6, c, r: rnd(5, 10)});
    },
    // Tia sáng lúc đánh trúng
    sparks(x, y, n = 8, c = '#fff3bf', dir = null) {
      for (let i = 0; i < n; i++) { const a = dir == null ? Math.random() * 6.283 : dir + rnd(-.9, .9), v = rnd(280, 560); add({k: 2, x, y, vx: Math.cos(a) * v, vy: Math.sin(a) * v, g: 0, life: rnd(.12, .25), l0: .25, c}); }
    },
    ring(x, y, r = 40, c = '#fff', w = 6, life = .35) { add({k: 3, x, y, r, c, w, life, l0: life}); },
    // Số sát thương: nảy to rồi bay lên, chí mạng to + vàng
    num(x, y, v, {crit = false, c = '#fff', size = 26} = {}) { add({k: 4, x: x + rnd(-10, 10), y, vx: rnd(-30, 30), vy: -150, g: 260, life: .9, l0: .9, s: String(v), c: crit ? '#ffd43b' : c, size: crit ? size * 1.35 : size}); },
    text(x, y, s, c = '#fff', size = 30) { add({k: 4, x, y, vx: 0, vy: -70, g: 0, life: 1.1, l0: 1.1, s, c, size}); },
    // Vệt chém hình cung
    slash(x, y, r, a0, face = 1, c = 'rgba(255,255,255,.95)') { add({k: 5, x, y, r, a0, face, c, life: .2, l0: .2}); },
    update(dt) {
      for (let i = P.length - 1; i >= 0; i--) {
        const p = P[i]; p.life -= dt;
        if (p.life <= 0) { P.splice(i, 1); continue; }
        if (p.vx !== undefined) { p.vy += (p.g || 0) * dt; p.x += p.vx * dt; p.y += p.vy * dt; if (p.k === 1) { p.vx *= 1 - dt * 3; p.r += dt * 14; } }
      }
    },
    draw(ctx) {
      for (const p of P) {
        const k = p.life / p.l0;
        ctx.globalAlpha = Math.min(1, k * 1.8);
        if (p.k === 0) { ctx.fillStyle = p.c; ctx.beginPath(); ctx.arc(p.x, p.y, p.r * (.4 + k * .6), 0, 6.283); ctx.fill(); }
        else if (p.k === 1) { ctx.globalAlpha = k * .7; ctx.fillStyle = p.c; ctx.beginPath(); ctx.arc(p.x, p.y, p.r, 0, 6.283); ctx.fill(); }
        else if (p.k === 2) { ctx.strokeStyle = p.c; ctx.lineWidth = 3; ctx.lineCap = 'round'; ctx.beginPath(); ctx.moveTo(p.x, p.y); ctx.lineTo(p.x - p.vx * .04, p.y - p.vy * .04); ctx.stroke(); }
        else if (p.k === 3) { const e = E.outCubic(1 - k); ctx.strokeStyle = p.c; ctx.lineWidth = p.w * k + .5; ctx.beginPath(); ctx.arc(p.x, p.y, p.r * (.3 + e), 0, 6.283); ctx.stroke(); }
        else if (p.k === 4) {
          const age = (p.l0 - p.life) / .25, sc = age < 1 ? .3 + E.outBack(age) * .7 : 1;
          ctx.font = `900 ${Math.round(p.size * sc)}px "Baloo 2", sans-serif`; ctx.textAlign = 'center'; ctx.lineJoin = 'round';
          ctx.lineWidth = 5; ctx.strokeStyle = 'rgba(0,0,0,.55)'; ctx.strokeText(p.s, p.x, p.y); ctx.fillStyle = p.c; ctx.fillText(p.s, p.x, p.y);
        } else if (p.k === 5) {
          const e = E.outCubic(1 - k), a1 = p.a0 + (-1.9 + e * 3.2) * p.face, a0 = a1 - 1.4 * p.face;
          ctx.strokeStyle = p.c; ctx.lineCap = 'round'; ctx.lineWidth = 10 * k + 2;
          ctx.beginPath(); ctx.arc(p.x, p.y, p.r, Math.min(a0, a1), Math.max(a0, a1)); ctx.stroke();
        }
      }
      ctx.globalAlpha = 1;
    },
    get n() { return P.length; }
  };
}

// Bóng đổ elip dưới chân (nhỏ lại khi vật ở trên cao)
export function shadow(ctx, x, y, w, lift = 0, a = .22) {
  const k = 1 / (1 + Math.max(0, lift) / 120);
  ctx.fillStyle = `rgba(0,0,0,${a * k})`; ctx.beginPath(); ctx.ellipse(x, y, w * k, w * .28 * k, 0, 0, 6.283); ctx.fill();
}

// ---------- Quái từ hình tĩnh, có hoạt ảnh thủ tục ----------
// f: {x, y, size, t, hurt, flip, vx?, atk (0..1 đòn), wind (0..1 lấy đà), dieT (0..1 đang chết), fly, stun}
// Đi: nhún + nghiêng theo bước; lấy đà: co người lùi lại; ra đòn: vươn tới; trúng đòn: dẹt + nháy sáng; chết: bật lên, xoay, nhỏ dần.
export function drawMob(ctx, img, f, {sheet = null, anim = null, frame = null, pixel = false, alpha = 1} = {}) {
  const s = f.size, t = f.t || 0, face = f.flip ? 1 : -1;
  let sx = 1, sy = 1, rot = 0, dx = 0, dy = 0, a = alpha;
  if (f.dieT != null) {
    const k = clamp01(f.dieT);
    dy = -Math.sin(k * Math.PI) * s * .35; rot = k * 2.4 * face; sx = sy = 1 - k * .7; a *= 1 - k;
  } else {
    const mv = f.moving ?? true;
    if (f.fly) { dy = Math.sin(t * 5) * s * .06; rot = Math.sin(t * 2.5) * .08; }
    else if (mv) { const st = Math.sin(t * 9); sy = 1 + st * .06; sx = 1 - st * .05; dy = -Math.abs(Math.sin(t * 9)) * s * .05; rot = Math.sin(t * 9) * .07; }
    else { const b = Math.sin(t * 3); sy = 1 + b * .03; sx = 1 - b * .02; }
    if (f.wind > 0) { const w = E.outCubic(f.wind); sx *= 1 + w * .12; sy *= 1 - w * .14; dx -= face * w * s * .12; rot -= face * w * .2; }
    if (f.atk > 0) { const k = E.bump(f.atk); dx += face * k * s * .28; sx *= 1 + k * .1; rot += face * k * .15; }
    if (f.hurt > 0) { const k = Math.min(1, f.hurt / .15); sx *= 1 + k * .18; sy *= 1 - k * .16; dx -= face * k * s * .06; }
    if (f.stun) rot += Math.sin(t * 14) * .12;
  }
  shadow(ctx, f.x, f.y + s * .44, s * .34, f.fly ? s * .5 - dy : -dy);
  ctx.save();
  ctx.globalAlpha = a;
  ctx.translate(f.x + dx, f.y + s * .45 + dy);
  if (rot) ctx.rotate(rot);
  ctx.scale(sx * (f.flip ? -1 : 1), sy);
  const fr = sheet ? frame || frameAt(sheet, anim, t) : null;
  if (pixel) ctx.imageSmoothingEnabled = false;
  if (sheet) drawFrame(ctx, sheet, fr, 0, sheet.anchor[1] < .9 ? -s * .45 : 0, s * .9);
  else draw(ctx, img, 0, -s * .45, s, s);
  // Nháy sáng khi trúng đòn: vẽ chồng chế độ 'lighter' (không dùng ctx.filter)
  if (f.hurt > 0 && f.dieT == null) {
    ctx.globalCompositeOperation = 'lighter'; ctx.globalAlpha = a * Math.min(.85, f.hurt * 6);
    if (sheet) drawFrame(ctx, sheet, fr, 0, sheet.anchor[1] < .9 ? -s * .45 : 0, s * .9); else draw(ctx, img, 0, -s * .45, s, s);
    ctx.globalCompositeOperation = 'source-over';
  }
  if (pixel) ctx.imageSmoothingEnabled = true;
  ctx.restore();
}

// ---------- Sprite Kenney ----------
// Tải nhiều sheet một lần: const SP = await sheetsB(['kenney-platformer/tiles', ...]) -> SP['kenney-platformer/tiles']
export async function sheetsB(names) { const arr = await Promise.all(names.map(n => loadSheet(n).catch(() => null))); return Object.fromEntries(names.map((n, i) => [n, arr[i]])); }
// Vẽ một khung theo tâm (anchor của sheet), cao h. pixel = tắt làm mịn cho ô pixel art.
export function spr(ctx, sheet, frame, x, y, h, opts = {}) {
  if (!sheet) return false;
  if (opts.pixel) ctx.imageSmoothingEnabled = false;
  drawFrame(ctx, sheet, frame, x, y, h, opts);
  if (opts.pixel) ctx.imageSmoothingEnabled = true;
  return true;
}
export const sprA = (ctx, sheet, anim, t, x, y, h, opts) => spr(ctx, sheet, frameAt(sheet, anim, t), x, y, h, opts);
// Lát kín một vùng bằng một ô (vẽ trước vào canvas phụ rồi dùng làm pattern cho nhẹ)
export function tilePattern(ctx, sheet, frame, size, {pixel = false} = {}) {
  const f = sheet?.frames?.[frame]; if (!f || !sheet.img.naturalWidth) return null;
  const c = document.createElement('canvas'); c.width = c.height = Math.max(4, Math.round(size));
  const g = c.getContext('2d'); g.imageSmoothingEnabled = !pixel; g.drawImage(sheet.img, f[0], f[1], f[2], f[3], 0, 0, c.width, c.height);
  return ctx.createPattern(c, 'repeat');
}
// Vẽ sẵn cảnh tĩnh (nền) vào canvas phụ một lần, mỗi khung chỉ drawImage
export function prerender(W, H, fn) {
  const dpr = Math.min(2, window.devicePixelRatio || 1);
  const c = document.createElement('canvas'); c.width = Math.round(W * dpr); c.height = Math.round(H * dpr);
  const g = c.getContext('2d'); g.scale(dpr, dpr); fn(g);
  return c;
}
