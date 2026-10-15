// Game mới (đợt 15): Chạy 3 làn, Cá con đại dương, Ném bóng rổ, Chạy vượt rào, Nhảy theo nhạc, Golf mini.
// Nhân vật/con vật là sprite Kenney CC0 có khung hoạt ảnh (src/sprites/play, tools/sprites_new.py), vẽ bằng sheets.js.
// Mỗi lượt một cấp (opts.level 0..59), bọc leveled() trong fun.js. opts.bot = tự chơi (chỉ dùng khi test).
import {note, sfx} from '../audio.js?v=4c51d34a6e';
import {banner, canvasIn, draw, endText, fx, goalPill, hud, levelBanner, loadAll, loop, pick, rand, ramp, roundRect, theme, themeImgs} from './funcore.js?v=4c51d34a6e';
import {drawAnim, drawFrame, loadSheets} from './sheets.js?v=4c51d34a6e';

// ---------- Dùng chung cho funnew3/4/5 ----------
export async function sheets(names) {
  const a = await loadSheets(names.map(n => 'play/' + n));
  return Object.fromEntries(names.map((n, i) => [n, a[i]]));
}
// Nhân vật của bé theo linh vật: bạn gái / bạn trai / robot.
export const kidOf = opts => /Woman|Princess|Unicorn|fairy|Cat face|Rabbit face/.test(opts.hero || '') ? 'kidgirl' : opts.hero === 'Robot' ? 'robot' : 'kidboy';
export const local = (cv, e) => { const r = cv.getBoundingClientRect(); return [e.clientX - r.left, e.clientY - r.top]; };
export function skyFill(ctx, W, H, th) { const g = ctx.createLinearGradient(0, 0, 0, H); g.addColorStop(0, th.sky[0]); g.addColorStop(1, th.sky[1]); ctx.fillStyle = g; ctx.fillRect(0, 0, W, H); }
export const hearts = (ctx, W, n, max = 3) => { for (let i = 0; i < max; i++) draw(ctx, 'Red heart', W - 40 - i * 36, 32, 30, 30, {alpha: i < n ? 1 : .22}); };
// Ô giữa trên cùng: chữ tiến độ (vd "🏃 120/300 m").
export function pill(ctx, W, text, y = 10, w = 190) {
  ctx.fillStyle = 'rgba(0,0,0,.28)'; roundRect(ctx, W / 2 - w / 2, y, w, 44, 22); ctx.fill();
  ctx.fillStyle = '#fff'; ctx.textAlign = 'center'; ctx.font = '800 25px "Baloo 2", sans-serif'; ctx.fillText(text, W / 2, y + 32);
}
// Chạm/vuốt: onTap(x, y), onSwipe(dx, dy, x0, y0). Vuốt khi đi quá 28px.
export function taps(cv, {onTap, onSwipe, onDown, onMove, onUp}) {
  let st = null;
  cv.addEventListener('pointerdown', e => { const [x, y] = local(cv, e); st = {x, y}; try { cv.setPointerCapture(e.pointerId); } catch (_) { /* bỏ qua */ } onDown?.(x, y); });
  cv.addEventListener('pointermove', e => { if (!st) return; const [x, y] = local(cv, e); onMove?.(x, y, st); });
  const up = e => {
    if (!st) return;
    const [x, y] = local(cv, e), dx = x - st.x, dy = y - st.y, s = st; st = null;
    onUp?.(x, y, s);
    if (Math.hypot(dx, dy) > 28) onSwipe?.(dx, dy, s.x, s.y); else onTap?.(x, y);
  };
  cv.addEventListener('pointerup', up);
  cv.addEventListener('pointercancel', () => { st = null; });
}
// Đổ bóng hình bầu dục dưới chân.
export function shadow(ctx, x, y, w, a = .18) { ctx.fillStyle = `rgba(0,0,0,${a})`; ctx.beginPath(); ctx.ellipse(x, y, w / 2, w / 7, 0, 0, 7); ctx.fill(); }

// ---------- 1. Chạy 3 làn: bé chạy trên 3 làn đường, vuốt lên/xuống (hoặc chạm làn) để đổi làn, chạm vào bé để nhảy.
// Sên, bọ rùa, chuột thì nhảy qua được; thùng gỗ và ong thì phải đổi làn. Ăn xu, chạy đủ số mét. ----------
export async function lanes(box, opts) {
  const lv = opts.level || 0, th = theme(lv), need = Math.round(ramp(lv, 250, 1100)), kid = kidOf(opts);
  const SH = await sheets([kid, 'critters', 'items']);
  await loadAll(['Red heart', 'Coin', ...themeImgs(lv)]);
  const {cv, ctx, W, H} = canvasIn(box);
  const S = Math.min(W, H), F = fx(), bot = opts.bot;
  const LY = [H * .58, H * .73, H * .88], LS = [.8, .9, 1], ph = Math.min(S * .32, H * .17);
  const me = {lane: 1, lf: 1, z: 0, vz: 0, inv: 0, hurt: 0, x: W * .24};
  const G = ph * 9, JV = Math.sqrt(2 * G * ph * .62);
  const obs = [], coins = [], deco = Array.from({length: 6}, (_, i) => ({x: i * W / 5 + rand(0, 60), k: pick(th.deco), s: rand(.7, 1.1)}));
  let dist = 0, lives = 3, t = 0, spawn = 1.4, end = null, endT = 0, coinN = 0;
  const GROUND = ['slime', 'snail', 'ladybug', 'mouse'];
  const laneAt = y => { let b = 0; for (let i = 1; i < 3; i++) if (Math.abs(y - (LY[i] - ph * .4)) < Math.abs(y - (LY[b] - ph * .4))) b = i; return b; };
  const jump = () => { if (me.z <= 0 && !end) { me.vz = JV; sfx('jump'); } };
  const toLane = d => { const n = Math.max(0, Math.min(2, me.lane + d)); if (n !== me.lane) { me.lane = n; sfx('flip'); } };
  taps(cv, {
    onTap: (x, y) => { if (t < 2 || end) return; const l = laneAt(y); if (l === me.lane) jump(); else toLane(l > me.lane ? 1 : -1); },
    onSwipe: (dx, dy) => { if (t < 2 || end) return; if (Math.abs(dy) > Math.abs(dx)) toLane(dy > 0 ? 1 : -1); else jump(); }
  });
  return loop({
    update(dt) {
      t += dt; F.update(dt);
      if (end) { endT += dt; return endT > 2 ? end : null; }
      if (t < 2) return null;
      const v = S * ramp(lv, .62, 1.0) * (1 + Math.min(.2, dist / 4000));
      dist += v * dt / (S * .1);
      me.lf += (me.lane - me.lf) * Math.min(1, dt * 14);
      if (me.z > 0 || me.vz > 0) { me.vz -= G * dt; me.z += me.vz * dt; if (me.z <= 0) { me.z = 0; me.vz = 0; } }
      me.inv = Math.max(0, me.inv - dt); me.hurt = Math.max(0, me.hurt - dt);
      spawn -= dt;
      if (spawn <= 0) {
        spawn = rand(.9, 1.4) * ramp(lv, 1.35, .72);
        // Làn chặn cứng (thùng/ong) tối đa 2 làn, luôn chừa 1 làn đi được.
        const hard = lv >= 6 ? (Math.random() < ramp(lv, .35, .6) ? (lv >= 30 && Math.random() < .4 ? 2 : 1) : 0) : 0;
        const ls = [0, 1, 2].sort(() => Math.random() - .5);
        if (hard === 2) spawn += .55;  // chặn 2 làn thì chừa thời gian đổi làn
        for (let i = 0; i < hard; i++) obs.push(lv >= 15 && Math.random() < .4 ? {lane: ls[i], x: W + 80, k: 'bee', hard: true, ph: rand(0, 6)} : {lane: ls[i], x: W + 80, k: 'crate', hard: true});
        const soft = Math.random() < ramp(lv, .55, .9) ? 1 : 0;
        if (soft && hard < 3) obs.push({lane: hard === 0 && Math.random() < .5 ? me.lane : ls[hard], x: W + 80 + rand(0, S * .3), k: pick(GROUND.slice(0, 2 + Math.min(2, Math.floor(lv / 8))))});
        if (Math.random() < .55) { const l = ls[2]; for (let i = 0; i < 5; i++) coins.push({lane: l, x: W + S * .5 + i * S * .09, z: lv >= 10 && i > 0 && i < 4 ? ph * .35 : 0}); }
      }
      const cur = Math.round(me.lf);
      for (let i = obs.length - 1; i >= 0; i--) {
        const o = obs[i]; o.x -= v * dt * (o.k === 'snail' ? .9 : o.k === 'mouse' ? 1.15 : 1);
        if (o.x < -100) { obs.splice(i, 1); continue; }
        if (me.inv <= 0 && o.lane === cur && Math.abs(o.x - me.x) < ph * .28 * LS[o.lane] && (o.hard || me.z < ph * .2)) {
          lives--; me.inv = 1.5; me.hurt = .5; sfx('hit'); F.burst(me.x, LY[cur] - ph * .5, 14, ['#ff6b6b', '#ffd43b']);
          if (lives <= 0) { end = {win: false, score: Math.round(dist / 10) + coinN}; sfx('wrong'); }
        }
      }
      for (let i = coins.length - 1; i >= 0; i--) {
        const c = coins[i]; c.x -= v * dt;
        if (c.x < -40) { coins.splice(i, 1); continue; }
        if (c.lane === cur && Math.abs(c.x - me.x) < ph * .25 && Math.abs(c.z - me.z) < ph * .4) { coins.splice(i, 1); coinN++; sfx('coin'); F.text(me.x, LY[cur] - ph * 1.1, '+1', '#ffd43b'); }
      }
      for (const d of deco) { d.x -= v * dt * .25; if (d.x < -120) { d.x = W + 120; d.k = pick(th.deco); } }
      if (bot) {  // tự chơi khi test: né thùng/ong bằng đổi làn, nhảy qua sên
        for (const o of obs) if (o.lane === me.lane && o.x > me.x && o.x - me.x < ph * (o.hard ? 2.6 : .7)) {
          if (o.hard) { const free = [0, 1, 2].filter(l => !obs.some(p => p.hard && p.lane === l && Math.abs(p.x - o.x) < ph * 1.5)); const l = free.sort((a, b) => Math.abs(a - me.lane) - Math.abs(b - me.lane))[0]; if (l != null) toLane(Math.sign(l - me.lane)); } else jump();
        }
      }
      if (dist >= need && !end) { end = {win: true, score: Math.round(need / 10) + coinN * 2 + lives * 5}; sfx('win'); }
      return null;
    },
    draw() {
      skyFill(ctx, W, H, th);
      draw(ctx, th.sun, W * .86, H * .12, S * .12);
      const top = LY[0] - ph * .95;
      for (const d of deco) draw(ctx, d.k, d.x, top - S * .1 * d.s, S * .22 * d.s, S * .22 * d.s, {alpha: .8});
      // Mặt đường 3 làn
      ctx.fillStyle = th.edge; ctx.fillRect(0, top, W, H - top);
      const band = (LY[1] - LY[0]);
      for (let i = 0; i < 3; i++) {
        ctx.fillStyle = i % 2 ? th.ground : 'rgba(255,255,255,.18)';
        ctx.fillRect(0, LY[i] - band * .78, W, band * .9);
        ctx.fillStyle = 'rgba(255,255,255,.55)';
        const off = (dist * S * .1) % 80;
        for (let x = -off; x < W; x += 80) ctx.fillRect(x, LY[i] + band * .1, 40, 4);
      }
      const cur = Math.round(me.lf);
      for (let l = 0; l < 3; l++) {
        const sc = LS[l];
        for (const c of coins) if (c.lane === l) drawAnim(ctx, SH.items, 'coin', t + c.x * .002, c.x, LY[l] - ph * .22 * sc - c.z, ph * .26 * sc);
        for (const o of obs) {
          if (o.lane !== l) continue;
          const y = LY[l];
          shadow(ctx, o.x, y, ph * .4 * sc);
          if (o.k === 'crate') { drawFrame(ctx, SH.items, 'block_planks', o.x, y - ph * .2 * sc, ph * .4 * sc); drawFrame(ctx, SH.items, 'block_planks', o.x, y - ph * .6 * sc, ph * .4 * sc); }
          else if (o.k === 'bee') drawAnim(ctx, SH.critters, 'bee', t, o.x, y - ph * .55 * sc + Math.sin(t * 6 + o.ph) * 6, ph * .38 * sc);
          else drawAnim(ctx, SH.critters, o.k, t, o.x, y - ph * .16 * sc, ph * (o.k === 'mouse' ? .3 : .34) * sc);
        }
        if (l === cur) {
          const sc2 = LS[0] + (LS[2] - LS[0]) * me.lf / 2, y = LY[0] + (LY[2] - LY[0]) * me.lf / 2;
          shadow(ctx, me.x, y, ph * .45 * sc2 * (1 - Math.min(.5, me.z / ph)));
          const blink = me.inv > 0 && Math.floor(me.inv * 10) % 2;
          const anim = end?.win ? 'cheer' : me.hurt > 0 ? 'hurt' : me.z > 0 ? (me.vz > 0 ? 'jump' : 'fall') : 'run';
          if (!blink) drawAnim(ctx, SH[kid], anim, t, me.x, y - me.z, ph * sc2);
        }
      }
      F.draw(ctx);
      hud(ctx, W, {score: coinN, lives: 0, time: null}); hearts(ctx, W, lives);
      pill(ctx, W, `🏃 ${Math.min(need, Math.floor(dist))}/${need} m`, W < 640 ? 62 : 10);
      if (t < 2) levelBanner(ctx, W, H, lv, `Chạy ${need} mét`, 'Vuốt lên/xuống đổi làn · Chạm vào bé để nhảy');
      if (end) banner(ctx, W, H, end.win ? endText(true, lv) : 'VẤP NGÃ RỒI!', `${Math.min(need, Math.floor(dist))}/${need} mét`);
    }
  }, opts.alive);
}

// ---------- 2. Cá con đại dương: kéo ngón tay để cá vàng bơi theo, nhặt ngọc, né cá gai, lươn, cá nóc, cá đỏ to ----------
export async function swim(box, opts) {
  const lv = opts.level || 0, need = Math.round(ramp(lv, 10, 26));
  const SH = await sheets(['critters', 'sea', 'items']);
  await loadAll(['Red heart', 'Coin']);
  const {cv, ctx, W, H} = canvasIn(box);
  const S = Math.min(W, H), F = fx(), bot = opts.bot, fs = S * .13;
  const me = {x: W * .3, y: H * .5, vx: 0, vy: 0, face: 1, inv: 0};
  let target = null, got = 0, lives = 3, t = 0, end = null, endT = 0;
  const GEMS = ['gem_blue', 'gem_green', 'gem_red', 'gem_yellow', 'star'];
  const gems = [], foes = [];
  const addGem = () => gems.push({x: rand(W * .08, W * .92), y: rand(H * .2, H * .82), k: pick(GEMS), ph: rand(0, 6)});
  for (let i = 0; i < 4; i++) addGem();
  const nP = Math.min(4, 1 + Math.floor(lv / 12));
  for (let i = 0; i < nP; i++) foes.push({k: 'fishP', x: rand(W * .55, W * .95), y: rand(H * .2, H * .85), vx: 0, vy: 0, ph: rand(0, 6), s: fs * .9});
  if (lv >= 8) foes.push({k: 'eel', x: -200, y: rand(H * .3, H * .8), vx: S * ramp(lv, .3, .55), vy: 0, s: fs * 1.3, wait: rand(1, 3)});
  if (lv >= 15) foes.push({k: 'puffer', x: rand(W * .4, W * .8), y: rand(H * .3, H * .7), vx: 0, vy: 0, ph: 0, s: fs});
  if (lv >= 25) foes.push({k: 'big', x: W + 150, y: H * .5, vx: 0, vy: 0, s: fs * 1.8});
  const friends = Array.from({length: 5}, () => ({k: pick(['fish_blue', 'fish_pink', 'fish_orange', 'fish_green']), x: rand(0, W), y: rand(H * .15, H * .7), v: rand(20, 50) * (Math.random() < .5 ? 1 : -1), s: rand(.5, .8)}));
  const bubbles = Array.from({length: 14}, () => ({x: rand(0, W), y: rand(0, H), v: rand(30, 70), k: pick(['bubble_a', 'bubble_b', 'bubble_c']), s: rand(.15, .35)}));
  const weeds = Array.from({length: Math.ceil(W / 70)}, (_, i) => ({x: i * 70 + rand(-10, 10), k: pick(['seaweed_green_a', 'seaweed_green_b', 'seaweed_pink_a', 'seaweed_orange_a', 'seaweed_grass_a']), s: rand(.8, 1.4), ph: rand(0, 6)}));
  const SP = S * ramp(lv, .75, .95);
  taps(cv, {onDown: (x, y) => { target = {x, y}; }, onMove: (x, y) => { target = {x, y}; }, onUp: () => { target = null; }});
  const hitR = (a, r) => Math.hypot(a.x - me.x, a.y - me.y) < r;
  return loop({
    update(dt) {
      t += dt; F.update(dt);
      for (const b of bubbles) { b.y -= b.v * dt; if (b.y < -20) { b.y = H + 20; b.x = rand(0, W); } }
      for (const f of friends) { f.x += f.v * dt; if (f.x < -80) f.x = W + 80; if (f.x > W + 80) f.x = -80; }
      if (end) { endT += dt; return endT > 2 ? end : null; }
      if (t < 2) return null;
      if (bot) {  // tự chơi khi test: bơi tới ngọc gần nhất, né cá dữ ở gần
        const g = gems.reduce((a, b) => Math.hypot(b.x - me.x, b.y - me.y) < Math.hypot(a.x - me.x, a.y - me.y) ? b : a, gems[0]);
        let tx = g.x - me.x, ty = g.y - me.y; const d0 = Math.hypot(tx, ty) || 1; tx /= d0; ty /= d0;
        for (const f of foes) { if (f.wait > 0) continue; const dx = me.x - f.x, dy = me.y - f.y, d = Math.hypot(dx, dy) || 1, R = (f.cur || f.s) + fs * 1.6; if (d < R) { tx += dx / d * 2.5 * (R - d) / R * 2; ty += dy / d * 2.5 * (R - d) / R * 2; } }
        target = {x: me.x + tx * 100, y: me.y + ty * 100};
      }
      if (target) {
        const dx = target.x - me.x, dy = target.y - me.y, d = Math.hypot(dx, dy);
        if (d > 6) { me.vx += (dx / d * SP - me.vx) * Math.min(1, dt * 5); me.vy += (dy / d * SP - me.vy) * Math.min(1, dt * 5); }
        if (d < 30) { me.vx *= .9; me.vy *= .9; }
      } else { me.vx *= Math.pow(.2, dt); me.vy *= Math.pow(.2, dt); }
      me.x = Math.max(fs / 2, Math.min(W - fs / 2, me.x + me.vx * dt)); me.y = Math.max(fs / 2 + 60, Math.min(H - fs / 2, me.y + me.vy * dt));
      if (Math.abs(me.vx) > 20) me.face = me.vx > 0 ? 1 : -1;
      me.inv = Math.max(0, me.inv - dt);
      for (let i = gems.length - 1; i >= 0; i--) {
        const g = gems[i]; g.ph += dt;
        if (hitR(g, fs * .55)) { gems.splice(i, 1); got++; sfx('coin'); F.burst(g.x, g.y, 10, ['#ffd43b', '#74c0fc', '#fff']); F.text(g.x, g.y - 30, `${got}/${need}`, '#ffd43b'); addGem(); if (got >= need) { end = {win: true, score: got * 5 + lives * 5}; sfx('win'); } }
      }
      const sp = ramp(lv, .14, .28) * S;
      for (const f of foes) {
        if (f.k === 'fishP') { f.ph += dt * .7; f.vx = Math.cos(f.ph) * sp; f.vy = Math.sin(f.ph * 1.3) * sp * .7; }
        else if (f.k === 'eel') { if (f.wait > 0) { f.wait -= dt; continue; } f.x += f.vx * dt; if (f.x > W + 200) { f.x = -200; f.y = rand(H * .25, H * .85); f.wait = rand(1.5, 4); } continue; }
        else if (f.k === 'puffer') { f.ph += dt; f.vx = Math.cos(f.ph * .5) * sp * .5; f.vy = Math.sin(f.ph * .4) * sp * .4; }
        else if (f.k === 'big') {  // cá đỏ to: đuổi 3 giây rồi nghỉ (bơi chậm ra xa) 3 giây, cắn trúng thì lùi ra xa
          f.cd = (f.cd || 0) - dt; if (f.cd < -3) f.cd = 3;
          const dx = me.x - f.x, dy = me.y - f.y, d = Math.hypot(dx, dy) || 1, k = f.cd > 0 ? -.25 : ramp(lv, .3, .45);
          f.vx = dx / d * SP * k; f.vy = dy / d * SP * k; }
        f.x = Math.max(f.s / 2, Math.min(W - f.s / 2, f.x + f.vx * dt)); f.y = Math.max(80, Math.min(H - f.s / 2, f.y + f.vy * dt));
        if (f.k === 'puffer') f.cur = f.s * (1 + .35 * Math.max(0, Math.sin(t * 1.6)));
      }
      if (me.inv <= 0) for (const f of foes) {
        const r = (f.cur || f.s) * (f.k === 'eel' ? .3 : .32) + fs * .25;
        const hx = f.k === 'eel' ? Math.abs(f.x - me.x) < f.s * .5 && Math.abs(f.y - me.y) < f.s * .2 : Math.hypot(f.x - me.x, f.y - me.y) < r;
        if (hx) { lives--; me.inv = 2; for (const b of foes) if (b.k === 'big') b.cd = 3; sfx('hit'); F.burst(me.x, me.y, 12, ['#ff8787', '#fff']); if (lives <= 0) { end = {win: false, score: got * 5}; sfx('wrong'); } break; }
      }
      return null;
    },
    draw() {
      const g = ctx.createLinearGradient(0, 0, 0, H); g.addColorStop(0, '#4dabf7'); g.addColorStop(.55, '#1c7ed6'); g.addColorStop(1, '#0b4f8a');
      ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
      ctx.fillStyle = 'rgba(255,255,255,.07)';
      for (let i = 0; i < 5; i++) { const x = (i * W / 4 + Math.sin(t * .3 + i) * 40); ctx.beginPath(); ctx.moveTo(x - 30, 0); ctx.lineTo(x + 30, 0); ctx.lineTo(x + 140, H); ctx.lineTo(x + 40, H); ctx.fill(); }
      for (const f of friends) drawFrame(ctx, SH.sea, f.k, f.x, f.y, fs * f.s, {flip: f.v < 0, alpha: .45});
      ctx.fillStyle = '#f1d9a6'; ctx.fillRect(0, H - 26, W, 26);
      for (const w of weeds) { ctx.save(); ctx.translate(w.x, H - 18); ctx.rotate(Math.sin(t * 1.5 + w.ph) * .12); drawFrame(ctx, SH.sea, w.k, 0, -fs * .45 * w.s, fs * .9 * w.s); ctx.restore(); }
      drawFrame(ctx, SH.sea, 'rock_a', W * .15, H - 40, fs * .9); drawFrame(ctx, SH.sea, 'rock_b', W * .72, H - 36, fs * .8);
      for (const b of bubbles) drawFrame(ctx, SH.sea, b.k, b.x, b.y, fs * b.s, {alpha: .7});
      for (const gm of gems) { const s = fs * .5 * (1 + Math.sin(gm.ph * 4) * .08); drawFrame(ctx, SH.items, gm.k, gm.x, gm.y + Math.sin(gm.ph * 2) * 6, s); }
      for (const f of foes) {
        if (f.k === 'fishP') drawAnim(ctx, SH.critters, 'fishP', t, f.x, f.y, f.s);
        else if (f.k === 'eel') { if (f.wait <= 0) drawAnim(ctx, SH.sea, 'eel', t, f.x, f.y, f.s); }
        else if (f.k === 'puffer') drawFrame(ctx, SH.sea, 'fish_brown', f.x, f.y, f.cur || f.s, {flip: f.vx < 0});
        else if (f.k === 'big') drawFrame(ctx, SH.sea, 'fish_red', f.x, f.y + Math.sin(t * 3) * 4, f.s, {flip: f.vx < 0});
      }
      const blink = me.inv > 0 && Math.floor(me.inv * 10) % 2;
      if (!blink) drawAnim(ctx, SH.critters, 'fishY', t * (1 + Math.hypot(me.vx, me.vy) / SP), me.x, me.y, fs, {flip: me.face > 0, rot: Math.max(-.4, Math.min(.4, me.vy / SP * .5)) * me.face});
      F.draw(ctx);
      hud(ctx, W, {score: got, lives: 0, time: null}); hearts(ctx, W, lives);
      goalPill(ctx, W, got, need, 16);
      if (t < 2) levelBanner(ctx, W, H, lv, `Nhặt ${need} viên ngọc`, 'Giữ và kéo ngón tay, cá con bơi theo · Né cá gai');
      if (end) banner(ctx, W, H, end.win ? endText(true, lv) : 'HẾT LƯỢT BƠI!', `${got}/${need} viên ngọc`);
    }
  }, opts.alive);
}

// ---------- 3. Ném bóng rổ: vuốt từ quả bóng về phía rổ (vuốt dài = ném mạnh). Rổ di chuyển ở cấp cao. ----------
export async function hoops(box, opts) {
  const lv = opts.level || 0, th = theme(lv), need = Math.min(12, 3 + Math.floor(lv / 7)), kid = kidOf(opts);
  const SH = await sheets([kid]);
  await loadAll(['Basketball', 'Red heart', 'Coin', ...themeImgs(lv)]);
  const {cv, ctx, W, H} = canvasIn(box);
  const S = Math.min(W, H), F = fx(), bot = opts.bot;
  const ground = H * .86, ph = Math.min(S * .3, H * .26), kx = W * .16, G = S * 2.4, br = S * .042;
  const rr = S * ramp(lv, .085, .062);
  const hoop = {x0: W * rand(.62, .8), y0: H * rand(.36, .5), x: 0, y: 0, ph: rand(0, 6), net: 0};
  const mvY = lv >= 8 ? S * ramp(lv, .05, .14) : 0, mvX = lv >= 28 ? S * ramp(lv, .03, .12) : 0, mvSp = ramp(lv, .8, 1.6);
  let time = Math.round(ramp(lv, 70, 55)), score = 0, t = 0, end = null, endT = 0, ball = null, drag = null, throwT = 9, cheerT = 0, shots = 0;
  const hand = () => ({x: kx + ph * .2, y: ground - ph * .78});
  const rest = () => { const h = hand(); ball = {x: h.x, y: h.y, vx: 0, vy: 0, fly: false, life: 0, scored: false, rot: 0}; };
  rest();
  const placeHoop = () => { hoop.x = hoop.x0 + Math.cos(hoop.ph * mvSp * .7) * mvX; hoop.y = hoop.y0 + Math.sin(hoop.ph * mvSp) * mvY; };
  placeHoop();
  const shoot = (vx, vy) => { ball.vx = vx; ball.vy = vy; ball.fly = true; ball.life = 0; throwT = 0; shots++; sfx('shoot'); };
  const maxV = S * 3.2;
  const velOf = (dx, dy) => { let vx = dx * 4.2, vy = dy * 4.2; const m = Math.hypot(vx, vy); if (m > maxV) { vx *= maxV / m; vy *= maxV / m; } return [vx, vy]; };
  taps(cv, {
    onDown: (x, y) => { if (!ball.fly && !end && t >= 2) drag = {x0: x, y0: y, x, y}; },
    onMove: (x, y) => { if (drag) { drag.x = x; drag.y = y; } },
    onUp: (x, y) => {
      if (!drag) return;
      const dx = x - drag.x0, dy = y - drag.y0; drag = null;
      if (Math.hypot(dx, dy) < 25 || dy > 0) return;
      shoot(...velOf(dx, dy));
    }
  });
  const rimPts = () => [{x: hoop.x - rr, y: hoop.y}, {x: hoop.x + rr, y: hoop.y}];
  return loop({
    update(dt) {
      t += dt; F.update(dt); throwT += dt; cheerT = Math.max(0, cheerT - dt); hoop.net = Math.max(0, hoop.net - dt);
      if (end) { endT += dt; return endT > 2 ? end : null; }
      if (t < 2) return null;
      time -= dt; hoop.ph += dt; placeHoop();
      if (bot && !ball.fly && throwT > .5) {
        const T = .95, h = hand();
        shoot((hoop.x - h.x) / T, (hoop.y - br * 1.2 - h.y - .5 * G * T * T) / T);
      }
      if (ball.fly) {
        for (let k = 0; k < 3; k++) {
          const d = dt / 3, py = ball.y;
          ball.vy += G * d; ball.x += ball.vx * d; ball.y += ball.vy * d; ball.rot += ball.vx * d * .02;
          for (const p of rimPts()) {
            const dx = ball.x - p.x, dy = ball.y - p.y, dd = Math.hypot(dx, dy);
            if (dd < br && dd > 0) { const nx = dx / dd, ny = dy / dd, vn = ball.vx * nx + ball.vy * ny; if (vn < 0) { ball.vx -= 1.6 * vn * nx; ball.vy -= 1.6 * vn * ny; sfx('pop'); } ball.x = p.x + nx * br; ball.y = p.y + ny * br; }
          }
          const bx = hoop.x + rr + S * .03;
          if (ball.x + br > bx && ball.x < bx + 10 && ball.y > hoop.y - S * .22 && ball.y < hoop.y + S * .04 && ball.vx > 0) { ball.vx = -Math.abs(ball.vx) * .55; ball.x = bx - br; sfx('pop'); }
          if (!ball.scored && py < hoop.y && ball.y >= hoop.y && ball.vy > 0 && Math.abs(ball.x - hoop.x) < rr - br * .4) {
            ball.scored = true; score++; hoop.net = .6; cheerT = 1.2; sfx('coin'); F.burst(hoop.x, hoop.y + 20, 18); F.text(hoop.x, hoop.y - 40, `${score}/${need}`, '#ffd43b');
            ball.vx *= .3;
            if (score >= need) { end = {win: true, score: score * 10 + Math.round(time)}; sfx('win'); }
          }
          if (ball.y + br > ground) { ball.y = ground - br; ball.vy = -Math.abs(ball.vy) * .5; ball.vx *= .7; }
        }
        ball.life += dt;
        if (ball.life > 3.2 || (ball.scored && ball.life > 1.5) || ball.x > W + 80 || ball.x < -80) rest();
      } else { const h = hand(); ball.x = h.x; ball.y = h.y + Math.sin(t * 3) * 2; }
      if (time <= 0 && !end) { time = 0; end = {win: false, score: score * 10}; sfx('wrong'); }
      return null;
    },
    draw() {
      skyFill(ctx, W, H, th);
      draw(ctx, th.sun, W * .5, H * .12, S * .1);
      ctx.fillStyle = 'rgba(255,255,255,.3)'; for (let i = 0; i < 3; i++) draw(ctx, th.deco[i], W * (.3 + i * .22), ground - S * .12, S * .22, S * .22, {alpha: .45});
      ctx.fillStyle = '#d9a066'; ctx.fillRect(0, ground, W, H - ground);
      ctx.fillStyle = '#c08552'; for (let x = 0; x < W; x += 46) ctx.fillRect(x, ground, 3, H - ground);
      ctx.fillStyle = '#fff'; ctx.fillRect(0, ground, W, 4);
      // Cột + bảng rổ
      const bx = hoop.x + rr + S * .03;
      ctx.fillStyle = '#868e96'; ctx.fillRect(bx + 14, hoop.y - S * .1, 12, ground - hoop.y + S * .1);
      ctx.fillStyle = '#495057'; roundRect(ctx, bx + 6, ground - 14, 28, 14, 4); ctx.fill();
      ctx.fillStyle = '#f8f9fa'; ctx.strokeStyle = '#495057'; ctx.lineWidth = 3; roundRect(ctx, bx, hoop.y - S * .22, 12, S * .26, 4); ctx.fill(); ctx.stroke();
      // Lưới
      const sway = Math.sin(hoop.net * 20) * hoop.net * 6;
      ctx.strokeStyle = 'rgba(255,255,255,.95)'; ctx.lineWidth = 2;
      const nh = S * .09;
      for (let i = 0; i <= 4; i++) { const x0 = hoop.x - rr + i * rr / 2; ctx.beginPath(); ctx.moveTo(x0, hoop.y); ctx.lineTo(hoop.x - rr * .55 + i * rr * .275 + sway, hoop.y + nh + hoop.net * 10); ctx.stroke(); }
      for (let j = 1; j <= 2; j++) { const f = j / 2.5; ctx.beginPath(); ctx.moveTo(hoop.x - rr * (1 - f * .45) + sway * f, hoop.y + nh * f); ctx.lineTo(hoop.x + rr * (1 - f * .45) + sway * f, hoop.y + nh * f); ctx.stroke(); }
      // Bé ném bóng
      shadow(ctx, kx, ground, ph * .5);
      const anim = end?.win || cheerT > 0 ? 'cheer' : throwT < .35 ? 'throw' : drag || !ball.fly ? 'hold' : 'idle';
      drawAnim(ctx, SH[kid], anim, anim === 'throw' ? throwT : t, kx, ground, ph);
      if (drag) {
        const [vx0, vy0] = velOf(drag.x - drag.x0, drag.y - drag.y0);
        if (drag.y < drag.y0 - 10) {
          let px = ball.x, py = ball.y, vx = vx0, vy = vy0;
          const dots = Math.round(Math.max(5, 26 - lv * .35));
          ctx.fillStyle = 'rgba(255,255,255,.95)';
          for (let i = 0; i < dots; i++) { for (let k = 0; k < 3; k++) { vy += G * .014; px += vx * .014; py += vy * .014; } ctx.beginPath(); ctx.arc(px, py, Math.max(2, 6 - i * .18), 0, 7); ctx.fill(); }
        }
      }
      // Bóng: khi rơi qua vành thì vẽ sau vành trước để như lọt rổ
      draw(ctx, 'Basketball', ball.x, ball.y, br * 2.2, br * 2.2, {rot: ball.rot});
      ctx.strokeStyle = '#f03e3e'; ctx.lineWidth = 6; ctx.lineCap = 'round';
      ctx.beginPath(); ctx.moveTo(hoop.x - rr, hoop.y); ctx.lineTo(hoop.x + rr, hoop.y); ctx.lineTo(bx, hoop.y); ctx.stroke();
      F.draw(ctx);
      hud(ctx, W, {score, lives: 0, time});
      goalPill(ctx, W, score, need);
      if (t < 2) levelBanner(ctx, W, H, lv, `Ném vào rổ ${need} quả`, 'Vuốt từ dưới lên về phía rổ · Vuốt dài ném xa');
      if (end) banner(ctx, W, H, end.win ? endText(true, lv) : 'HẾT GIỜ!', `${score}/${need} quả`);
    }
  }, opts.alive);
}

// ---------- 4. Chạy vượt rào: 4 bạn chạy đua, bé tự chạy, chạm để nhảy qua rào; nhảy sát rào được tăng tốc.
// Vấp rào thì chậm lại. Cấp thấp về nhì/ba vẫn qua, cấp cao phải về nhất. ----------
export async function hurdles(box, opts) {
  const lv = opts.level || 0, th = theme(lv), kid = kidOf(opts);
  const others = ['kidgirl', 'kidboy', 'robot', 'woman', 'man'].filter(k => k !== kid).slice(0, 3);
  const SH = await sheets([kid, ...others, 'items']);
  await loadAll(['Red heart', 'Coin', 'Chequered flag', ...themeImgs(lv)]);
  const {cv, ctx, W, H} = canvasIn(box);
  const S = Math.min(W, H), F = fx(), bot = opts.bot;
  const L = Math.round(ramp(lv, 50, 130)), U = S * .14, gap = Math.max(7, ramp(lv, 12, 8));
  const placeNeed = lv < 15 ? 3 : lv < 35 ? 2 : 1;
  const hs = []; for (let m = 10; m < L - 4; m += gap * rand(.85, 1.15)) hs.push(m);
  const port = H > W * 1.2, LY = port ? [H * .42, H * .58, H * .74, H * .9] : [H * .5, H * .63, H * .76, H * .89], LS = [.78, .86, .94, 1], ph = Math.min(S * (port ? .32 : .22), (LY[1] - LY[0]) * 1.4);
  const base = 6.2, G = 34;
  const racers = [kid, ...others].map((k, i) => ({k, me: i === 0, lane: [3, 0, 1, 2][i], x: 0, v: 0, z: 0, vz: 0, trip: 0, boost: 0, next: 0, done: 0,
    skill: i === 0 ? 1 : ramp(lv, .86, 1.02) * rand(.96, 1.04), miss: ramp(lv, .3, .06)}));
  const me = racers[0];
  let t = 0, end = null, endT = 0, place = 0, finishOrder = [];
  const jump = r => { if (r.z <= 0 && r.trip <= 0) { r.vz = 9.5; r.z = .001; if (r.me) sfx('jump');
    const h = hs[r.next]; if (r.me && h != null && h - r.x > 0 && h - r.x < 1.6) { r.boost = 1; F.text(W * .3, LY[r.lane] - ph * 1.2, 'Tuyệt!', '#ffd43b'); } } };
  taps(cv, {onTap: () => { if (t >= 2.5 && !end) jump(me); }, onSwipe: () => { if (t >= 2.5 && !end) jump(me); }});
  return loop({
    update(dt) {
      t += dt; F.update(dt);
      if (end) { endT += dt; for (const r of racers) if (r.x < L + 6) r.x += Math.max(2, r.v) * dt; return endT > 2.5 ? end : null; }
      if (t < 2.5) return null;
      for (const r of racers) {
        if (r.done) { r.x += r.v * .5 * dt; continue; }
        const target = r.trip > 0 ? base * .3 : base * r.skill * (1 + (r.boost > 0 ? .25 : 0)) * (r.me ? ramp(lv, 1.02, 1) : 1);
        r.v += (target - r.v) * Math.min(1, dt * 2.5);
        r.x += r.v * dt; r.trip = Math.max(0, r.trip - dt); r.boost = Math.max(0, r.boost - dt);
        if (r.z > 0) { r.vz -= G * dt; r.z += r.vz * dt; if (r.z <= 0) { r.z = 0; r.vz = 0; } }
        while (r.next < hs.length && hs[r.next] < r.x - .5) { r.next++; r.decided = false; r.hitH = false; }
        const h = hs[r.next];
        if (h != null) {
          if (!r.me || bot) { const d = h - r.x; if (d > 0 && d < .9 + (r.me ? .3 : 0) && r.z <= 0 && !r.decided) { r.decided = true; if (r.me || Math.random() > r.miss) jump(r); } }
          if (Math.abs(h - r.x) < .35 && r.z < .45 && r.trip <= 0 && !r.hitH) { r.trip = .8; r.hitH = true; r.v *= .4; if (r.me) { sfx('hit'); F.burst(W * .3, LY[r.lane] - ph * .3, 10, ['#ff8787', '#ffd43b']); } }
        }
        if (r.x >= L && !r.done) { r.done = finishOrder.push(r); if (r.me) { place = r.done; const win = place <= placeNeed; end = {win, score: Math.max(0, 50 - place * 10) + Math.round(ramp(lv, 10, 40)), pos: place}; sfx(win ? 'win' : 'wrong'); } }
      }
      return null;
    },
    draw() {
      skyFill(ctx, W, H, th);
      const camX = me.x * U - W * .3, top = LY[0] - (LY[1] - LY[0]) * .9;
      // Khán đài + cảnh xa
      for (let i = 0; i < 7; i++) { const x = ((i * W / 5 - camX * .3) % (W * 1.4) + W * 1.4) % (W * 1.4) - W * .2; draw(ctx, th.deco[i % 4], x, top - S * .09, S * .2, S * .2, {alpha: .85}); }
      ctx.fillStyle = '#c2410c'; ctx.fillRect(0, top, W, H - top);
      for (let i = 0; i < 4; i++) { ctx.fillStyle = i % 2 ? '#e8590c' : '#d9480f'; ctx.fillRect(0, LY[i] - (LY[1] - LY[0]) * .82, W, (LY[1] - LY[0]) * .82); ctx.fillStyle = '#fff'; ctx.fillRect(0, LY[i] + 1, W, 3); }
      // Vạch mét + đích
      ctx.fillStyle = 'rgba(255,255,255,.5)'; ctx.font = '700 16px "Baloo 2", sans-serif'; ctx.textAlign = 'center';
      for (let m = Math.ceil(camX / U / 10) * 10; m * U - camX < W + 20; m += 10) if (m > 0 && m < L) ctx.fillText(m + ' m', m * U - camX, top + 18);
      const fx0 = L * U - camX;
      if (fx0 < W + 40) { for (let y = top; y < H; y += 14) for (let k = 0; k < 2; k++) { ctx.fillStyle = (Math.floor((y - top) / 14) + k) % 2 ? '#fff' : '#212529'; ctx.fillRect(fx0 + k * 10, y, 10, 14); } draw(ctx, 'Chequered flag', fx0 + 10, top - S * .07, S * .12); }
      for (let l = 0; l < 4; l++) {
        const sc = LS[l];
        for (const h of hs) { const x = h * U - camX; if (x > -60 && x < W + 60) drawFrame(ctx, SH.items, 'fence', x, LY[l] - ph * .17 * sc, ph * .36 * sc); }
        for (const r of racers) if (r.lane === l) {
          const x = r.x * U - camX, zz = r.z * U * .55;
          shadow(ctx, x, LY[l], ph * .45 * sc);
          const anim = end && r.done ? (r.done === 1 ? 'cheer' : 'idle') : r.trip > .3 ? 'hurt' : r.z > 0 ? (r.vz > 0 ? 'jump' : 'fall') : t < 2.5 ? 'idle' : 'run';
          drawAnim(ctx, SH[r.k], anim, t * (.6 + r.v / base * .6), x, LY[l] - zz, ph * sc);
          if (r.me) { ctx.fillStyle = '#ffd43b'; ctx.beginPath(); const ay = LY[l] - zz - ph * sc - 8; ctx.moveTo(x - 10, ay - 14); ctx.lineTo(x + 10, ay - 14); ctx.lineTo(x, ay); ctx.fill(); }
        }
      }
      F.draw(ctx);
      // Bảng xếp hạng nhỏ: thứ tự hiện tại
      const order = [...racers].sort((a, b) => (a.done || 99) - (b.done || 99) || b.x - a.x), myPos = order.indexOf(me) + 1;
      // Thanh tiến độ cuộc đua: mỗi bạn một hình nhỏ, cờ đích bên phải
      const py = W < 640 ? 128 : 84, px0 = 30, px1 = W - 60;
      ctx.fillStyle = 'rgba(255,255,255,.75)'; roundRect(ctx, px0 - 10, py - 4, px1 - px0 + 50, 8, 4); ctx.fill();
      draw(ctx, 'Chequered flag', px1 + 22, py - 16, 34);
      for (const r of [...racers].reverse()) drawAnim(ctx, SH[r.k], 'run', t, px0 + (px1 - px0) * Math.min(1, r.x / L), py + 4, r.me ? 52 : 40);
      hud(ctx, W, {score: Math.min(L, Math.floor(me.x)), lives: 0, time: null});
      pill(ctx, W, `🏁 Hạng ${myPos} · cần ${placeNeed === 1 ? 'nhất' : 'top ' + placeNeed}`, W < 640 ? 62 : 10, 260);
      if (t < 2.5) levelBanner(ctx, W, H, lv, `Về ${placeNeed === 1 ? 'nhất' : 'top ' + placeNeed} · ${L} mét`, 'Chạm để nhảy qua rào · Nhảy sát rào được chạy nhanh');
      if (end) banner(ctx, W, H, end.win ? endText(true, lv) : 'CHƯA ĐƯỢC HẠNG!', `Bé về hạng ${place}`);
    }
  }, opts.alive);
}

// ---------- 5. Nhảy theo nhạc: viên ngọc rơi theo bài hát, chạm đúng cột khi ngọc chạm vạch, bạn nhỏ nhảy múa. ----------
const SONGS = [
  [0, 0, 4, 4, 5, 5, 4, 3, 3, 2, 2, 1, 1, 0, 4, 4, 3, 3, 2, 2, 1, 4, 4, 3, 3, 2, 2, 1, 0, 0, 4, 4, 5, 5, 4, 3, 3, 2, 2, 1, 1, 0],  // Sao lấp lánh
  [0, 1, 2, 0, 0, 1, 2, 0, 2, 3, 4, 2, 3, 4, 4, 5, 4, 3, 2, 0, 4, 5, 4, 3, 2, 0, 0, 4, 0, 0, 4, 0],  // Kìa con bướm vàng
  [2, 1, 0, 1, 2, 2, 2, 1, 1, 1, 2, 4, 4, 2, 1, 0, 1, 2, 2, 2, 2, 1, 1, 2, 1, 0]  // Mary có chú cừu non
];
export async function dance(box, opts) {
  const lv = opts.level || 0, kid = kidOf(opts), nc = lv < 20 ? 3 : 4;
  const crew = ['robot', kid === 'kidgirl' ? 'kidboy' : 'kidgirl'];
  const SH = await sheets([kid, ...crew, 'items']);
  await loadAll(['Red heart', 'Coin', 'Musical notes', 'Glowing star']);
  const {cv, ctx, W, H} = canvasIn(box);
  const S = Math.min(W, H), F = fx(), bot = opts.bot;
  const song = SONGS[lv % SONGS.length], beat = ramp(lv, .62, .34), win = ramp(lv, .24, .13), fallT = ramp(lv, 2.2, 1.3);
  const GEMS = ['gem_red', 'gem_blue', 'gem_green', 'gem_yellow'], COLS = ['#fa5252', '#339af0', '#40c057', '#fab005'];
  // Cấp cao: thêm nốt đôi (2 cột cùng lúc).
  const notes = song.map((p, i) => ({p, c: p % nc, at: 2.6 + i * beat, hit: false, miss: false}));
  if (lv >= 40) for (let i = 4; i < song.length; i += 6) notes.push({p: song[i] + 2, c: (song[i] + 1) % nc, at: notes[i].at, hit: false, miss: false, dbl: true});
  const allowed = Math.round(ramp(lv, 10, 4));
  const top = H * .4, hitY = H * .88, colW = Math.min(W / nc, 190), x0 = W / 2 - colW * nc / 2;
  let t = 0, hits = 0, miss = 0, combo = 0, best = 0, pose = 'idle', poseT = 0, end = null, endT = 0, flash = Array(nc).fill(0);
  const POSES = ['cheer0', 'wide', 'kick', 'cheer1', 'show', 'jump', 'switch1', 'attack1'];
  const press = c => {
    flash[c] = .15;
    let bestN = null;
    for (const n of notes) if (!n.hit && !n.miss && n.c === c && Math.abs(n.at - t) < win && (!bestN || Math.abs(n.at - t) < Math.abs(bestN.at - t))) bestN = n;
    if (bestN) {
      bestN.hit = true; hits++; combo++; best = Math.max(best, combo); note(bestN.p, .5);
      pose = POSES[hits % POSES.length]; poseT = .4;
      const x = x0 + (c + .5) * colW; F.burst(x, hitY, 10, [COLS[c], '#fff']); if (Math.abs(bestN.at - t) < win * .4) F.text(x, hitY - 50, 'Tuyệt!', '#ffd43b');
    } else { combo = 0; }
  };
  taps(cv, {onDown: x => { if (t < 2 || end) return; const c = Math.floor((x - x0) / colW); if (c >= 0 && c < nc) press(c); }});
  return loop({
    update(dt) {
      t += dt; F.update(dt); poseT = Math.max(0, poseT - dt); for (let i = 0; i < nc; i++) flash[i] = Math.max(0, flash[i] - dt);
      if (end) { endT += dt; return endT > 2.2 ? end : null; }
      if (bot) for (const n of notes) if (!n.hit && !n.miss && t >= n.at - .02) press(n.c);
      for (const n of notes) if (!n.hit && !n.miss && t - n.at > win) { n.miss = true; miss++; combo = 0; pose = 'hurt'; poseT = .3; }
      if (miss > allowed && !end) { end = {win: false, score: hits * 5}; sfx('wrong'); }
      else if (!end && notes.every(n => n.hit || n.miss)) { end = {win: true, score: hits * 5 + best * 2}; sfx('win'); }
      return null;
    },
    draw() {
      // Sân khấu
      const g = ctx.createLinearGradient(0, 0, 0, H); g.addColorStop(0, '#3b1d6e'); g.addColorStop(1, '#14082b');
      ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
      for (let i = 0; i < 3; i++) { const a = Math.sin(t * .8 + i * 2) * .35; ctx.save(); ctx.translate(W * (.25 + i * .25), 0); ctx.rotate(a); ctx.fillStyle = `rgba(${['255,212,59', '116,192,252', '247,131,172'][i]},.12)`; ctx.beginPath(); ctx.moveTo(-10, 0); ctx.lineTo(10, 0); ctx.lineTo(90, top); ctx.lineTo(-90, top); ctx.fill(); ctx.restore(); }
      ctx.fillStyle = '#7c4a1e'; ctx.fillRect(0, top - 14, W, 14);
      const dh = Math.min(top * .7, S * .3);
      if (combo >= 5) drawAnim(ctx, SH[crew[0]], 'dance', t + .3, W * .25, top - 14, dh * .8, {flip: true});
      if (combo >= 10) drawAnim(ctx, SH[crew[1]], 'dance', t + .7, W * .75, top - 14, dh * .8);
      shadow(ctx, W / 2, top - 14, dh * .5, .3);
      if (end?.win) drawAnim(ctx, SH[kid], 'cheer', t, W / 2, top - 14, dh);
      else if (poseT > 0) drawFrame(ctx, SH[kid], pose === 'hurt' ? 'hurt' : pose, W / 2, top - 14, dh, {flip: hits % 2 === 1});
      else drawAnim(ctx, SH[kid], 'idle', t, W / 2, top - 14 - Math.abs(Math.sin(t * Math.PI / beat)) * 6, dh);
      // Cột nốt
      for (let c = 0; c < nc; c++) {
        const x = x0 + c * colW;
        ctx.fillStyle = c % 2 ? 'rgba(255,255,255,.06)' : 'rgba(255,255,255,.1)'; ctx.fillRect(x + 3, top, colW - 6, H - top);
        ctx.fillStyle = flash[c] > 0 ? COLS[c] : 'rgba(255,255,255,.18)'; roundRect(ctx, x + 8, hitY - colW * .3, colW - 16, colW * .6, 18); ctx.fill();
        drawFrame(ctx, SH.items, GEMS[c], x + colW / 2, hitY, colW * .32, {alpha: .45});
      }
      for (const n of notes) {
        if (n.hit || n.miss) continue;
        const k = 1 - (n.at - t) / fallT; if (k < 0) continue;
        const y = top + (hitY - top) * k, x = x0 + (n.c + .5) * colW;
        drawFrame(ctx, SH.items, GEMS[n.c], x, y, colW * .44);
      }
      F.draw(ctx);
      hud(ctx, W, {score: hits, lives: 0, time: null});
      for (let i = 0; i < Math.min(allowed, 12); i++) draw(ctx, 'Red heart', W - 30 - i * 22, 30, 20, 20, {alpha: i < allowed - miss ? 1 : .2});
      if (combo >= 3) pill(ctx, W, `🔥 ${combo} liên tiếp`, W < 640 ? 62 : 10, 200);
      if (t < 2) levelBanner(ctx, W, H, lv, `Chạm đúng ${notes.length} nốt nhạc`, 'Ngọc rơi tới ô sáng thì chạm vào cột đó');
      if (end) banner(ctx, W, H, end.win ? endText(true, lv) : 'LỠ NHỊP RỒI!', `${hits}/${notes.length} nốt`);
    }
  }, opts.alive);
}

// ---------- 6. Golf mini: kéo ngược từ bóng để ngắm (như ná), thả để đánh, đưa bóng vào lỗ cờ trong số gậy cho phép. ----------
export async function golf(box, opts) {
  const lv = opts.level || 0, kid = kidOf(opts);
  const SH = await sheets([kid, 'items', 'critters']);
  await loadAll(['Red heart', 'Coin', 'Flag in hole']);
  const {cv, ctx, W, H} = canvasIn(box);
  const S = Math.min(W, H), F = fx(), bot = opts.bot;
  const top = W < 640 ? 112 : 70, M = 16, A = {x: M, y: top, w: W - M * 2, h: H - top - M};
  const br = S * .022, hr = S * .036;
  const port = A.h > A.w;
  const startP = port ? {x: A.x + A.w * rand(.3, .7), y: A.y + A.h * .88} : {x: A.x + A.w * .1, y: A.y + A.h * rand(.3, .7)};
  const hole = port ? {x: A.x + A.w * rand(.25, .75), y: A.y + A.h * .12} : {x: A.x + A.w * .9, y: A.y + A.h * rand(.2, .8)};
  // Tường so le (như mê cung đơn giản), luôn chừa khe ở một đầu.
  const walls = [], nW = Math.min(4, Math.floor(lv / 12) + (lv >= 2 ? 1 : 0)), th = S * .045;
  for (let i = 0; i < nW; i++) {
    const f = (i + 1) / (nW + 1), len = (port ? A.w : A.h) * ramp(lv, .45, .62), left = i % 2 === 0;
    // gap: tâm khe hở của tường (để bot test ngắm), passed(b): bóng đã qua tường này chưa
    if (port) { const y = A.y + A.h * (.88 - .76 * f) - th / 2; const gx = left ? A.x + (len + A.w) / 2 : A.x + (A.w - len) / 2, gr = (A.w - len) / 2 - br * 3; walls.push({x: left ? A.x : A.x + A.w - len, y, w: len, h: th, gap: {x: gx, y: y - th * 1.5}, under: {x: gx, y: y + th * 2.5}, inGap: b => Math.abs(b.x - gx) < gr, passed: b => b.y < y - th * .5}); }
    else { const x = A.x + A.w * (.1 + .8 * f) - th / 2; const gy = left ? A.y + (len + A.h) / 2 : A.y + (A.h - len) / 2, gr = (A.h - len) / 2 - br * 3; walls.push({x, y: left ? A.y : A.y + A.h - len, w: th, h: len, gap: {x: x + th * 2.5, y: gy}, under: {x: x - th * 2.5, y: gy}, inGap: b => Math.abs(b.y - gy) < gr, passed: b => b.x > x + th * 1.5}); }
  }
  const sands = lv >= 20 ? Array.from({length: Math.min(3, 1 + Math.floor((lv - 20) / 15))}, () => ({x: A.x + A.w * rand(.2, .8), y: A.y + A.h * rand(.25, .75), r: S * rand(.06, .09)})) : [];
  const bugs = lv >= 10 ? Array.from({length: Math.min(3, 1 + Math.floor((lv - 10) / 16))}, (_, i) => ({k: pick(['slime', 'ladybug', 'snail']), x: A.x + A.w * rand(.3, .7), y: A.y + A.h * (.3 + .4 * i / 3), vx: S * ramp(lv, .12, .3) * (Math.random() < .5 ? -1 : 1), s: S * .07})) : [];
  const par = 1 + nW, allowed = par + Math.round(ramp(lv, 5, 3));
  let ball = {x: startP.x, y: startP.y, vx: 0, vy: 0}, strokes = 0, drag = null, t = 0, end = null, endT = 0, sink = 0, swingT = 9;
  const maxPull = S * .26, POW = 7.5;
  const moving = () => Math.hypot(ball.vx, ball.vy) > 4;
  const hitWall = (w) => {
    const cx = Math.max(w.x, Math.min(ball.x, w.x + w.w)), cy = Math.max(w.y, Math.min(ball.y, w.y + w.h)), dx = ball.x - cx, dy = ball.y - cy, d = Math.hypot(dx, dy);
    if (d < br) { const nx = d ? dx / d : 0, ny = d ? dy / d : -1, vn = ball.vx * nx + ball.vy * ny; if (vn < 0) { ball.vx -= 1.8 * vn * nx; ball.vy -= 1.8 * vn * ny; sfx('pop'); } ball.x = cx + nx * br; ball.y = cy + ny * br; }
  };
  const hitBall = (vx, vy) => { ball.vx = vx; ball.vy = vy; strokes++; swingT = 0; sfx('shoot'); };
  taps(cv, {
    onDown: (x, y) => { if (!moving() && !end && t >= 2 && !sink) drag = {x, y}; },
    onMove: (x, y) => { if (drag) { drag.x = x; drag.y = y; } },
    onUp: () => {
      if (!drag) return;
      let dx = ball.x - drag.x, dy = ball.y - drag.y; drag = null;
      const d = Math.hypot(dx, dy); if (d < 14) return;
      if (d > maxPull) { dx *= maxPull / d; dy *= maxPull / d; }
      hitBall(dx * POW, dy * POW);
    }
  });
  return loop({
    update(dt) {
      t += dt; F.update(dt); swingT += dt;
      for (const b of bugs) { b.x += b.vx * dt; if (b.x < A.x + b.s || b.x > A.x + A.w - b.s) b.vx *= -1; }
      if (end) { endT += dt; return endT > 2 ? end : null; }
      if (t < 2) return null;
      if (sink) { sink += dt; if (sink > .7) { end = {win: true, score: Math.max(5, (allowed - strokes + 1) * 10)}; sfx('win'); } return null; }
      if (bot && !moving() && swingT > .8) { const w = walls.find(w => !w.passed(ball)), g = w ? (w.inGap(ball) ? w.gap : w.under) : hole, dx = g.x - ball.x, dy = g.y - ball.y, d = Math.hypot(dx, dy); const sp = Math.min(maxPull * POW, d * 1.3 + 60); hitBall(dx / d * sp, dy / d * sp); }
      for (let k = 0; k < 4; k++) {
        const d = dt / 4;
        ball.x += ball.vx * d; ball.y += ball.vy * d;
        const inSand = sands.some(s => Math.hypot(ball.x - s.x, ball.y - s.y) < s.r);
        const fr = Math.exp(-(inSand ? 2.2 : 1.05) * d); ball.vx *= fr; ball.vy *= fr;
        const sp = Math.hypot(ball.vx, ball.vy); if (sp < 18) { ball.vx = 0; ball.vy = 0; }
        if (ball.x < A.x + br) { ball.x = A.x + br; ball.vx = Math.abs(ball.vx) * .8; }
        if (ball.x > A.x + A.w - br) { ball.x = A.x + A.w - br; ball.vx = -Math.abs(ball.vx) * .8; }
        if (ball.y < A.y + br) { ball.y = A.y + br; ball.vy = Math.abs(ball.vy) * .8; }
        if (ball.y > A.y + A.h - br) { ball.y = A.y + A.h - br; ball.vy = -Math.abs(ball.vy) * .8; }
        for (const w of walls) hitWall(w);
        for (const b of bugs) { const dx = ball.x - b.x, dy = ball.y - b.y, dd = Math.hypot(dx, dy); if (dd < b.s * .45 + br) { const nx = dx / dd, ny = dy / dd, vn = ball.vx * nx + ball.vy * ny; if (vn < 0) { ball.vx -= 2 * vn * nx; ball.vy -= 2 * vn * ny; } ball.x = b.x + nx * (b.s * .45 + br); ball.y = b.y + ny * (b.s * .45 + br); sfx('squeak'); } }
        const dh = Math.hypot(ball.x - hole.x, ball.y - hole.y);
        if (dh < hr * .8 && sp < S * 1.6) { sink = .001; ball.vx = ball.vy = 0; sfx('coin'); F.burst(hole.x, hole.y, 22); F.star(hole.x, hole.y); break; }
        if (dh < hr * 1.6 && dh > 0) { ball.vx += (hole.x - ball.x) / dh * S * .9 * d; ball.vy += (hole.y - ball.y) / dh * S * .9 * d; }  // lỗ hút nhẹ
      }
      if (!moving() && !sink && strokes >= allowed && !end) { end = {win: false, score: 0}; sfx('wrong'); }
      return null;
    },
    draw() {
      ctx.fillStyle = '#2b8a3e'; ctx.fillRect(0, 0, W, H);
      ctx.fillStyle = '#69db7c'; roundRect(ctx, A.x, A.y, A.w, A.h, 24); ctx.fill();
      ctx.fillStyle = 'rgba(255,255,255,.08)'; for (let x = A.x; x < A.x + A.w; x += 60) ctx.fillRect(x, A.y, 30, A.h);
      for (const s of sands) { ctx.fillStyle = '#ffe8a3'; ctx.beginPath(); ctx.ellipse(s.x, s.y, s.r * 1.2, s.r, 0, 0, 7); ctx.fill(); }
      for (const w of walls) {
        const n = Math.max(1, Math.round(Math.max(w.w, w.h) / th)), hz = w.w > w.h;
        for (let i = 0; i < n; i++) drawFrame(ctx, SH.items, 'block_planks', hz ? w.x + (i + .5) * w.w / n : w.x + w.w / 2, hz ? w.y + w.h / 2 : w.y + (i + .5) * w.h / n, th * 1.05);
      }
      ctx.fillStyle = '#1b4332'; ctx.beginPath(); ctx.arc(hole.x, hole.y, hr, 0, 7); ctx.fill();
      drawAnim(ctx, SH.items, 'flagR', t, hole.x + S * .028, hole.y - S * .045, S * .1);
      for (const b of bugs) drawAnim(ctx, SH.critters, b.k, t, b.x, b.y, b.s, {flip: b.vx > 0});
      if (drag) {
        let dx = ball.x - drag.x, dy = ball.y - drag.y; const d = Math.hypot(dx, dy);
        if (d > maxPull) { dx *= maxPull / d; dy *= maxPull / d; }
        const len = Math.round(Math.max(3, 12 - lv * .15));
        for (let i = 1; i <= len; i++) { ctx.fillStyle = `rgba(255,255,255,${1 - i / (len + 2)})`; ctx.beginPath(); ctx.arc(ball.x + dx * i * .28, ball.y + dy * i * .28, 5, 0, 7); ctx.fill(); }
        ctx.strokeStyle = 'rgba(0,0,0,.25)'; ctx.lineWidth = 3; ctx.beginPath(); ctx.moveTo(ball.x, ball.y); ctx.lineTo(ball.x - dx * .5, ball.y - dy * .5); ctx.stroke();
      }
      // Bé cầm gậy đứng cạnh bóng khi bóng dừng
      const ph = S * .17;
      if (!moving() && !sink) drawAnim(ctx, SH[kid], end && !end.win ? 'hurt' : swingT < .3 ? 'throw' : 'hold', swingT < .3 ? swingT : t, ball.x - ph * .32, ball.y + br, ph, {alpha: .95});
      if (sink && !end) drawAnim(ctx, SH[kid], 'cheer', t, ball.x - ph * .32, ball.y + br, ph);
      if (end?.win) drawAnim(ctx, SH[kid], 'cheer', t, hole.x - ph * .4, hole.y + ph * .5, ph);
      if (!sink) { shadow(ctx, ball.x + 3, ball.y + br * .8, br * 2.4, .25); ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.arc(ball.x, ball.y, br, 0, 7); ctx.fill(); ctx.fillStyle = 'rgba(0,0,0,.12)'; ctx.beginPath(); ctx.arc(ball.x + br * .3, ball.y + br * .3, br * .6, 0, 7); ctx.fill(); }
      F.draw(ctx);
      hud(ctx, W, {score: strokes, lives: 0, time: null});
      pill(ctx, W, `⛳ Gậy ${strokes}/${allowed}`, W < 640 ? 62 : 10, 190);
      if (t < 2) levelBanner(ctx, W, H, lv, `Đưa bóng vào lỗ trong ${allowed} gậy`, 'Kéo ngược từ quả bóng rồi thả tay');
      if (end) banner(ctx, W, H, end.win ? endText(true, lv) : 'HẾT LƯỢT ĐÁNH!', `${strokes} gậy`);
    }
  }, opts.alive);
}
