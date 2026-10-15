// Lõi chung cho các game ở Khu vui chơi: hình, canvas, hiệu ứng, HUD, vòng lặp.
import {src} from '../ui.js?v=4c51d34a6e';
import {sfx} from '../audio.js?v=4c51d34a6e';

// ---------- Lõi chung ----------
export const imgCache = {};
export function sprite(name) {
  if (!imgCache[name]) { const im = new Image(); im.decoding = 'async'; im.src = src(name); imgCache[name] = im; }
  return imgCache[name];
}
// addEventListener (không gán onload) để nhiều lần chờ cùng một hình không đè nhau.
// preloads: các module khác (figure.js nạp sprite nhân vật) thêm promise vào đây để game chờ trước khi bắt đầu.
export const preloads = new Set();
export const loadAll = names => Promise.all([...preloads, ...[...new Set(names)].map(n => { const im = sprite(n); return im.complete ? null : new Promise(r => { im.addEventListener('load', r, {once: true}); im.addEventListener('error', r, {once: true}); }); })]);
export const LIVES = 5;
export const rand = (a, b) => a + Math.random() * (b - a);
export const pick = a => a[Math.floor(Math.random() * a.length)];
export const hit = (a, b, s = .7) => Math.abs(a.x - b.x) < (a.w + b.w) / 2 * s && Math.abs(a.y - b.y) < (a.h + b.h) / 2 * s;

export function canvasIn(box) {
  const cv = document.createElement('canvas');
  cv.className = 'funcv';
  box.append(cv);
  const dpr = Math.min(2, window.devicePixelRatio || 1);
  const r = box.getBoundingClientRect();
  const W = Math.max(320, r.width), H = Math.max(320, r.height);
  cv.width = Math.round(W * dpr); cv.height = Math.round(H * dpr);
  cv.style.width = W + 'px'; cv.style.height = H + 'px';
  const ctx = cv.getContext('2d');
  ctx.scale(dpr, dpr);
  return {cv, ctx, W, H};
}

export function draw(ctx, name, x, y, w, h = w, {flip = false, rot = 0, alpha = 1} = {}) {
  const im = sprite(name);
  if (!im.complete || !im.naturalWidth) return;
  ctx.save();
  ctx.globalAlpha = alpha;
  ctx.translate(x, y);
  if (rot) ctx.rotate(rot);
  if (flip) ctx.scale(-1, 1);
  ctx.drawImage(im, -w / 2, -h / 2, w, h);
  ctx.restore();
}

// Hạt lấp lánh + chữ bay lên.
export function fx() {
  const parts = [];
  return {
    burst(x, y, n = 14, colors = ['#ffd43b', '#ff922b', '#ff6b6b', '#74c0fc', '#b197fc']) {
      for (let i = 0; i < n; i++) {
        const a = Math.random() * Math.PI * 2, v = rand(120, 320);
        parts.push({x, y, vx: Math.cos(a) * v, vy: Math.sin(a) * v, life: rand(.4, .8), c: pick(colors), r: rand(3, 7)});
      }
    },
    text(x, y, s, c = '#fff') { parts.push({x, y, vx: 0, vy: -70, life: .9, text: s, c}); },
    star(x, y) { parts.push({x, y, vx: rand(-40, 40), vy: -160, life: .9, star: true}); },
    update(dt) {
      for (let i = parts.length - 1; i >= 0; i--) {
        const p = parts[i];
        p.x += p.vx * dt; p.y += p.vy * dt; p.vy += (p.text || p.star ? 0 : 300) * dt; p.life -= dt;
        if (p.life <= 0) parts.splice(i, 1);
      }
    },
    draw(ctx) {
      for (const p of parts) {
        ctx.globalAlpha = Math.max(0, Math.min(1, p.life * 1.6));
        if (p.text) { ctx.fillStyle = p.c; ctx.font = '800 26px "Baloo 2", sans-serif'; ctx.textAlign = 'center'; ctx.strokeStyle = 'rgba(0,0,0,.35)'; ctx.lineWidth = 4; ctx.strokeText(p.text, p.x, p.y); ctx.fillText(p.text, p.x, p.y); }
        else if (p.star) draw(ctx, 'Glowing star', p.x, p.y, 34);
        else { ctx.fillStyle = p.c; ctx.beginPath(); ctx.arc(p.x, p.y, p.r, 0, 7); ctx.fill(); }
      }
      ctx.globalAlpha = 1;
    }
  };
}

export function hud(ctx, W, {score, lives, time, boss}) {
  ctx.font = '800 28px "Baloo 2", sans-serif';
  ctx.textAlign = 'left';
  // Màn hẹp (điện thoại): thu nhỏ ô điểm, tim, đồng hồ để không đè nhau.
  const narrow = W < 520, hs = narrow ? 22 : 30, hg = narrow ? 25 : 36, tw = narrow ? 90 : 100;
  ctx.fillStyle = 'rgba(0,0,0,.28)';
  roundRect(ctx, 12, 10, narrow ? 112 : 150, 44, 22); ctx.fill();
  draw(ctx, 'Coin', 38, 32, 30);
  ctx.fillStyle = '#fff'; ctx.fillText(String(score), 60, 42);
  if (lives) for (let i = 0; i < LIVES; i++) draw(ctx, 'Red heart', W - (narrow ? 30 : 40) - i * hg, 32, hs, hs, {alpha: i < lives ? 1 : .22});
  if (time != null) {
    ctx.fillStyle = 'rgba(0,0,0,.28)'; roundRect(ctx, W / 2 - tw / 2, 10, tw, 44, 22); ctx.fill();
    ctx.fillStyle = '#fff'; ctx.textAlign = 'center'; ctx.fillText(`⏱ ${Math.ceil(time)}`, W / 2, 42);
  }
  if (boss) {
    const bw = Math.min(360, W * .5);
    ctx.fillStyle = 'rgba(0,0,0,.35)'; roundRect(ctx, W / 2 - bw / 2, 62, bw, 18, 9); ctx.fill();
    ctx.fillStyle = '#ff6b6b'; roundRect(ctx, W / 2 - bw / 2 + 3, 65, (bw - 6) * Math.max(0, boss.hp / boss.max), 12, 6); ctx.fill();
  }
}

export function roundRect(ctx, x, y, w, h, r) {
  ctx.beginPath(); ctx.moveTo(x + r, y); ctx.arcTo(x + w, y, x + w, y + h, r); ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r); ctx.arcTo(x, y, x + w, y, r); ctx.closePath();
}

export function banner(ctx, W, H, text, sub) {
  ctx.fillStyle = 'rgba(0,0,0,.35)'; ctx.fillRect(0, H / 2 - 70, W, 140);
  ctx.textAlign = 'center'; ctx.fillStyle = '#fff'; ctx.font = '800 54px "Baloo 2", sans-serif';
  ctx.fillText(text, W / 2, H / 2 + (sub ? 0 : 18));
  if (sub) { ctx.font = '700 26px "Baloo 2", sans-serif'; ctx.fillText(sub, W / 2, H / 2 + 42); }
}

// Vòng lặp chung: update(dt) trả về {done, win} khi kết thúc.
export function loop(game, isAlive) {
  return new Promise(resolve => {
    let last = performance.now(), paused = false;
    const onVis = () => { paused = document.hidden; last = performance.now(); };
    document.addEventListener('visibilitychange', onVis);
    const frame = now => {
      if (!isAlive()) { document.removeEventListener('visibilitychange', onVis); return resolve(null); }
      const dt = Math.min(.05, (now - last) / 1000); last = now;
      if (!paused) {
        const r = game.update(dt);
        game.draw();
        if (r) { document.removeEventListener('visibilitychange', onVis); return resolve(r); }
      }
      requestAnimationFrame(frame);
    };
    requestAnimationFrame(frame);
  });
}


// ---------- Cấp độ ----------
// Mỗi game có MAX_LV cấp. Cứ 10 cấp đổi một cảnh; độ khó tăng dần theo ramp().
export const MAX_LV = 60;
export const THEMES = [
  {vi: 'Đồng cỏ', sky: ['#74c0fc', '#e7f5ff'], ground: '#8ce99a', edge: '#69db7c', sun: 'Sun with face', deco: ['Deciduous tree', 'Evergreen tree', 'Sunflower', 'House']},
  {vi: 'Sa mạc', sky: ['#ffa94d', '#fff3bf'], ground: '#ffd8a8', edge: '#fab005', sun: 'Sun with face', deco: ['Cactus', 'Palm tree', 'Camel', 'Rock']},
  {vi: 'Xứ tuyết', sky: ['#a5d8ff', '#f8f9fa'], ground: '#f1f3f5', edge: '#ced4da', sun: 'Snowflake', deco: ['Snowman', 'Evergreen tree', 'Christmas tree', 'Snow-capped mountain']},
  {vi: 'Thành phố đêm', sky: ['#1c2a5a', '#5c7cfa'], ground: '#868e96', edge: '#495057', sun: 'Crescent moon', deco: ['Office building', 'House', 'Cityscape', 'Evergreen tree']},
  {vi: 'Rừng kẹo', sky: ['#f783ac', '#fff0f6'], ground: '#fcc2d7', edge: '#f06595', sun: 'Rainbow', deco: ['Lollipop', 'Candy', 'Doughnut', 'Mushroom']},
  {vi: 'Núi lửa', sky: ['#c92a2a', '#ffc078'], ground: '#8d5524', edge: '#e8590c', sun: 'Volcano', deco: ['Volcano', 'Rock', 'Fire', 'Mountain']}
];
export const theme = lv => THEMES[Math.floor(lv / 10) % THEMES.length];
export const themeImgs = lv => { const th = theme(lv); return [th.sun, ...th.deco]; };
// Giá trị đi từ a (cấp 1) tới b (cấp MAX_LV), tuyến tính.
export const ramp = (lv, a, b) => a + (b - a) * Math.min(1, Math.max(0, lv) / (MAX_LV - 1));

// Màn mở đầu: cấp + cảnh, mục tiêu, dòng hướng dẫn nhỏ.
export function levelBanner(ctx, W, H, lv, goal, hint) {
  ctx.fillStyle = 'rgba(0,0,0,.4)'; ctx.fillRect(0, H / 2 - 90, W, 180);
  ctx.textAlign = 'center'; ctx.fillStyle = '#ffd43b'; ctx.font = '800 50px "Baloo 2", sans-serif';
  ctx.fillText(`CẤP ${lv + 1}`, W / 2, H / 2 - 22);
  // Chữ dài (điện thoại): thu nhỏ cho vừa bề ngang
  const fit = (txt, size, weight) => { let px = size; do { ctx.font = `${weight} ${px}px "Baloo 2", sans-serif`; px -= 1; } while (px > 11 && ctx.measureText(txt).width > W - 24); };
  ctx.fillStyle = '#fff'; fit(`🎯 ${goal}`, 28, 800);
  ctx.fillText(`🎯 ${goal}`, W / 2, H / 2 + 20);
  if (hint) { fit(hint, 20, 700); ctx.fillStyle = 'rgba(255,255,255,.85)'; ctx.fillText(hint, W / 2, H / 2 + 58); }
}

// Ô mục tiêu điểm trên HUD (giữa, dưới đồng hồ).
export function goalPill(ctx, W, now, need, y = 62) {
  if (W < 640) y = Math.max(y, 62);  // màn hẹp: xuống dòng dưới, không đè ô điểm
  const ok = now >= need;
  ctx.fillStyle = ok ? 'rgba(47,158,68,.85)' : 'rgba(0,0,0,.28)'; roundRect(ctx, W / 2 - 70, y, 140, 36, 18); ctx.fill();
  ctx.fillStyle = '#fff'; ctx.textAlign = 'center'; ctx.font = '800 22px "Baloo 2", sans-serif';
  ctx.fillText(ok ? `🎯 ${need} ✔` : `🎯 ${now}/${need}`, W / 2, y + 26);
}

// Kết thúc: thắng = đạt mục tiêu cấp.
export const endText = (win, lv) => win ? (lv + 1 >= MAX_LV ? '🏆 CẤP CAO NHẤT!' : `⭐ LÊN CẤP ${lv + 2}!`) : 'CHƯA QUA CẤP';
