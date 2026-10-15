// Game đối kháng (đợt 12, phần 2): Ném tuyết, Mô tô ánh sáng, Đấu sumo, Cờ caro, Nối bốn.
// Đợt 15: tường tuyết bằng khối tuyết Kenney, bóng tuyết có bóng đổ + vỡ tung; mô tô Kenney chạy mượt giữa các ô,
// nổ khi đâm; sumo nhìn nghiêng 2.5D trên võ đài đất; cờ caro/nối bốn dùng quân cờ (chip) Kenney rơi có nảy.
import {sfx} from '../audio.js?v=4c51d34a6e';
import {canvasIn, draw, loadAll, loop, pick, rand, ramp, roundRect, theme} from './funcore.js?v=4c51d34a6e';
import {BLUE, RED, buttons, endVs, multi, scoreBar, versus, vsCos, vsIntro} from './funvs1.js?v=4c51d34a6e';
import {drawFigure, drawHead} from './figure.js?v=4c51d34a6e';
import {E, approach, camera, fxb, prerender, shadow, sheetsB, spr, sprA} from './motionb.js?v=4c51d34a6e';

const wait = ms => new Promise(r => setTimeout(r, ms));
const decay = (arr, dt, k = 2.5) => { for (let i = 0; i < arr.length; i++) arr[i] = Math.max(0, arr[i] - dt * k); };

// ---------- 6. Ném tuyết: kéo ngược rồi thả để ném theo đường cong, trúng đối thủ được điểm ----------
export const snowball = versus('☃️ Ném tuyết', async (box, opts, mode) => {
  const lv = opts.level || 0, need = 5;
  await loadAll(['Snowman', 'Evergreen tree', 'Snowflake', 'Glowing star', 'Snow-capped mountain']);
  const SP = await sheetsB(['kenney-platformer/tiles']), TL = SP['kenney-platformer/tiles'];
  const COS = vsCos(opts, mode);
  const {cv, ctx, W, H} = canvasIn(box);
  const S = Math.min(W, H), F = fxb(), C = camera(), M = multi(cv), ground = H * .8, G = S * 1.6;
  const P = [{x: W * .1, hx: W * .1, cd: 0, hurt: 0}, {x: W * .9, hx: W * .9, cd: 0, hurt: 0}];
  const pw = S * .15, bs = Math.max(26, S * .055);
  const walls = [{x: W * .24, h: S * .16, hp: 6, max: 6, sh: 0}, {x: W * .76, h: S * .16, hp: 6, max: 6, sh: 0}];
  if (lv >= 15) walls.push({x: W / 2, h: S * ramp(lv, .12, .3), hp: 99, max: 99, sh: 0});
  const balls = [], pops = [0, 0];
  let a = 0, b = 0, t = 0, end = null, endT = 0, winner = 0, aiT = 1.5;
  const flakes = Array.from({length: 40}, () => ({x: rand(0, W), y: rand(0, H), v: rand(20, 60), s: rand(1.5, 3.5)}));
  const bg = prerender(W, H, g => {
    const gr = g.createLinearGradient(0, 0, 0, H); gr.addColorStop(0, '#74c0fc'); gr.addColorStop(1, '#f1f3f5'); g.fillStyle = gr; g.fillRect(0, 0, W, H);
    draw(g, 'Snow-capped mountain', W * .3, ground - S * .22, S * .5, S * .5, {alpha: .7}); draw(g, 'Snow-capped mountain', W * .72, ground - S * .26, S * .6, S * .6, {alpha: .7});
    draw(g, 'Evergreen tree', W * .38, ground - S * .12, S * .26, S * .26, {alpha: .8}); draw(g, 'Evergreen tree', W * .62, ground - S * .14, S * .3, S * .3, {alpha: .8});
    draw(g, 'Snowman', W * .5, ground - S * .09, S * .18, S * .18);
    g.fillStyle = '#fff'; g.fillRect(0, ground, W, H - ground);
    g.fillStyle = '#e7f5ff'; for (let i = 0; i < 9; i++) { g.beginPath(); g.ellipse((i * 131) % W, ground + 18 + (i % 3) * 22, 60, 10, 0, 0, 7); g.fill(); }
  });
  const throwFrom = (k, vx, vy) => { const p = P[k]; if (p.cd > 0) return; p.cd = .7; p.thr = 0; balls.push({x: p.x + (k ? -1 : 1) * pw * .4, y: ground - pw * .9, vx, vy, k, rot: 0}); sfx('shoot'); };
  M.on('up', p => {
    if (end || t < 2.4) return;
    const k = p.sx < W / 2 ? 0 : 1;
    if (k === 1 && mode !== 'pvp') return;
    const dx = p.sx - p.x, dy = p.sy - p.y, d = Math.hypot(dx, dy);
    if (d < 20) return;
    const pow = Math.min(1, d / (S * .35)) * S * 1.6;
    throwFrom(k, dx / d * pow, dy / d * pow);
  });
  const aiErr = ramp(lv, .3, .05), aiRate = ramp(lv, 2.6, 1.1);
  const splat = (x, y) => { F.burst(x, y, 12, ['#fff', '#e7f5ff', '#d0ebff'], 220, 600); F.ring(x, y, 26, '#fff', 5); };
  return loop({
    update(rdt) {
      t += rdt; C.update(rdt); const dt = rdt * C.scale(rdt); F.update(dt); decay(pops, rdt);
      for (const f of flakes) { f.y += f.v * dt; f.x += Math.sin(t + f.v) * 10 * dt; if (f.y > H) { f.y = -5; f.x = rand(0, W); } }
      for (const w of walls) w.sh = Math.max(0, w.sh - dt);
      P.forEach(p => { p.cd = Math.max(0, p.cd - dt); p.hurt = Math.max(0, p.hurt - dt); p.thr = (p.thr ?? 9) + dt; p.x = approach(p.x, p.hx, 5, dt); });
      if (end) { endT += rdt; return endT > 2.2 ? end : null; }
      if (t < 2.4) return null;
      if (mode === 'bot') {
        aiT -= dt;
        if (aiT <= 0) {
          aiT = aiRate * rand(.8, 1.2);
          const dx = P[0].x - P[1].x, ang = -Math.PI / 4 - rand(0, .25);
          const v = Math.sqrt(Math.abs(dx) * G / Math.sin(-2 * ang)) * (1 + rand(-aiErr, aiErr));
          throwFrom(1, -Math.cos(ang) * v, Math.sin(ang) * v);
        }
      }
      for (let i = balls.length - 1; i >= 0; i--) {
        const s = balls[i]; s.vy += G * dt; s.x += s.vx * dt; s.y += s.vy * dt; s.rot += s.vx * dt * .02;
        if (s.y > ground || s.x < -20 || s.x > W + 20) { if (s.y > ground) splat(s.x, ground); balls.splice(i, 1); continue; }
        const w = walls.find(w => w.hp > 0 && Math.abs(s.x - w.x) < bs * .6 && s.y > ground - w.h * (w.hp / w.max * .5 + .5));
        if (w) { balls.splice(i, 1); splat(s.x, s.y); sfx('pop'); w.hp--; w.sh = .25; C.shake(2); continue; }
        const o = P[1 - s.k];
        if (Math.abs(s.x - o.x) < pw * .45 && s.y > ground - pw * 1.1) {
          balls.splice(i, 1); o.hurt = .5; o.x += (s.k ? -1 : 1) * pw * .35; sfx('hit'); splat(s.x, s.y); C.shake(5); C.stop(.06);
          if (s.k === 0) { a++; pops[0] = 1; } else { b++; pops[1] = 1; }
          F.text(o.x, ground - pw * 1.3, 'TRÚNG!', s.k === 0 ? '#74c0fc' : '#ff8787', 30);
          if (a >= need || b >= need) { winner = a >= need ? 1 : 2; end = {winner, score: a * 5}; }
        }
      }
      return null;
    },
    draw() {
      ctx.drawImage(bg, 0, 0, W, H);
      C.begin(ctx);
      // Tường tuyết xếp bằng khối tuyết, rung khi trúng, thấp dần khi vỡ
      for (const w of walls) {
        if (w.hp <= 0) continue;
        const n = Math.max(1, Math.round(w.h / bs * (w.hp >= 99 ? 1 : .5 + .5 * w.hp / w.max))), jx = Math.sin(t * 60) * w.sh * 10;
        for (let i = 0; i < n; i++) if (!spr(ctx, TL, i === n - 1 ? 'terrain_snow_block_top' : 'terrain_snow_block_center', w.x + jx, ground - bs * (i + .5), bs)) { ctx.fillStyle = '#e7f5ff'; ctx.fillRect(w.x - bs / 2, ground - bs * (i + 1), bs, bs); }
      }
      for (const [k, p] of P.entries()) {
        const aiming = [...M.pts.values()].some(q => (q.sx < W / 2 ? 0 : 1) === k && Math.hypot(q.x - q.sx, q.y - q.sy) > 20);
        const ta = p.thr / .35, pose = end ? (winner === k + 1 ? 'cheer' : 'hurt') : p.hurt > 0 ? 'hurt' : aiming ? 'throw' : ta < 1 ? 'throw' : 'idle';
        drawFigure(ctx, p.x, ground, pw * 1.25, {c: COS[k], pose, act: aiming ? 0 : E.outCubic(ta), t: t + k, face: k ? -1 : 1, team: k ? RED : BLUE});
      }
      for (const p of M.pts.values()) {
        const k = p.sx < W / 2 ? 0 : 1; if (k && mode !== 'pvp') continue;
        const dx = p.sx - p.x, dy = p.sy - p.y, d = Math.hypot(dx, dy); if (d < 20) continue;
        const pow = Math.min(1, d / (S * .35)) * S * 1.6;
        let x = P[k].x + (k ? -1 : 1) * pw * .4, y = ground - pw * .9, vx = dx / d * pow, vy = dy / d * pow;
        ctx.fillStyle = k ? 'rgba(250,82,82,.7)' : 'rgba(51,154,240,.7)';
        for (let i = 0; i < 14; i++) { for (let j = 0; j < 3; j++) { vy += G * .016; x += vx * .016; y += vy * .016; } ctx.beginPath(); ctx.arc(x, y, 5 - i * .25, 0, 7); ctx.fill(); }
      }
      for (const s of balls) {
        shadow(ctx, s.x, ground + 3, 10, ground - s.y, .18);
        ctx.fillStyle = 'rgba(255,255,255,.35)'; ctx.beginPath(); ctx.arc(s.x - s.vx * .02, s.y - s.vy * .02, 8, 0, 7); ctx.fill();
        const gr = ctx.createRadialGradient(s.x - 4, s.y - 4, 2, s.x, s.y, 11); gr.addColorStop(0, '#fff'); gr.addColorStop(1, '#a5d8ff');
        ctx.fillStyle = gr; ctx.beginPath(); ctx.arc(s.x, s.y, 11, 0, 7); ctx.fill();
      }
      F.draw(ctx);
      C.end(ctx);
      ctx.fillStyle = '#fff'; for (const f of flakes) { ctx.beginPath(); ctx.arc(f.x, f.y, f.s, 0, 7); ctx.fill(); }
      scoreBar(ctx, W, a, b, need, ...COS, pops);
      if (t < 2.4) vsIntro(ctx, W, H, lv, mode, `Ném trúng ${need} lần trước`, 'Kéo ngón tay ngược ra sau rồi thả để ném');
      if (end) endVs(ctx, W, H, winner, mode, lv, `${a} : ${b}`);
    }
  }, opts.alive);
});

// ---------- 7. Mô tô ánh sáng: xe để lại vệt sáng, ai đâm vào vệt hay tường trước là thua ván ----------
export const tron = versus('🏍️ Mô tô ánh sáng', async (box, opts, mode) => {
  const lv = opts.level || 0, need = 3;
  await loadAll(['Glowing star']);
  const SP = await sheetsB(['kenney-racing/moto', 'kenney-pirate/ships']), MOTO = SP['kenney-racing/moto'], BOOM = SP['kenney-pirate/ships'];
  const COS = vsCos(opts, mode);
  const {cv, ctx, W, H} = canvasIn(box);
  const F = fxb(), C = camera(), M = multi(cv), top = 96;
  const cs = Math.max(10, Math.floor(Math.min(W, H) / 34)), cols = Math.floor((W - 20) / cs), rows = Math.floor((H - top - 10) / cs);
  const ox = (W - cols * cs) / 2, oy = top;
  const D = {u: [0, -1], d: [0, 1], l: [-1, 0], r: [1, 0]}, OPP = {u: 'd', d: 'u', l: 'r', r: 'l'}, ANG = {u: 0, r: Math.PI / 2, d: Math.PI, l: -Math.PI / 2};
  const bg = prerender(W, H, g => {
    g.fillStyle = '#0b1026'; g.fillRect(0, 0, W, H);
    g.strokeStyle = 'rgba(116,192,252,.12)'; g.lineWidth = 1;
    for (let x = 0; x <= cols; x++) { g.beginPath(); g.moveTo(ox + x * cs, oy); g.lineTo(ox + x * cs, oy + rows * cs); g.stroke(); }
    for (let y = 0; y <= rows; y++) { g.beginPath(); g.moveTo(ox, oy + y * cs); g.lineTo(ox + cols * cs, oy + y * cs); g.stroke(); }
    g.strokeStyle = '#74c0fc'; g.lineWidth = 3; g.strokeRect(ox, oy, cols * cs, rows * cs);
  });
  // Vệt sáng vẽ dần vào canvas phụ (mỗi bước chỉ tô 1 ô), khỏi vẽ lại cả lưới mỗi khung
  const trail = document.createElement('canvas'), dpr = Math.min(2, window.devicePixelRatio || 1);
  trail.width = Math.round(W * dpr); trail.height = Math.round(H * dpr); const tg = trail.getContext('2d'); tg.scale(dpr, dpr);
  const paint = (x, y, k, px, py) => {
    tg.fillStyle = k ? 'rgba(255,107,107,.9)' : 'rgba(77,171,247,.9)';
    const x0 = Math.min(x, px ?? x), y0 = Math.min(y, py ?? y), x1 = Math.max(x, px ?? x), y1 = Math.max(y, py ?? y);
    tg.fillRect(ox + x0 * cs + cs * .25, oy + y0 * cs + cs * .25, (x1 - x0 + .5) * cs, (y1 - y0 + .5) * cs);
    tg.fillStyle = k ? '#ffe3e3' : '#e7f5ff'; tg.fillRect(ox + (x0 + .42) * cs, oy + (y0 + .42) * cs, (x1 - x0 + .16) * cs, (y1 - y0 + .16) * cs);
  };
  let grid, P, a = 0, b = 0, t = 0, step = 0, end = null, endT = 0, winner = 0, roundOver = 0, booms = [];
  const pops = [0, 0];
  const reset = () => {
    grid = Array.from({length: rows}, () => new Uint8Array(cols));
    tg.clearRect(0, 0, W, H);
    const my = Math.floor(rows / 2);
    P = [{x: 3, y: my, px: 3, py: my, dir: 'r', next: 'r', dead: false, ang: ANG.r}, {x: cols - 4, y: my, px: cols - 4, py: my, dir: 'l', next: 'l', dead: false, ang: ANG.l}];
    P.forEach((p, k) => { grid[p.y][p.x] = k + 1; paint(p.x, p.y, k); });
    roundOver = 0; step = 0;
  };
  reset();
  M.on('up', p => {
    const k = p.sx < W / 2 ? 0 : 1; if (k && mode !== 'pvp') return;
    const dx = p.x - p.sx, dy = p.y - p.sy; if (Math.hypot(dx, dy) < 18) return;
    const d = Math.abs(dx) > Math.abs(dy) ? (dx > 0 ? 'r' : 'l') : (dy > 0 ? 'd' : 'u');
    if (d !== OPP[P[k].dir]) { P[k].next = d; sfx('tap'); }
  });
  const free = (x, y) => x >= 0 && y >= 0 && x < cols && y < rows && !grid[y][x];
  const space = (x, y, lim) => { const seen = new Set([x + ',' + y]), q = [[x, y]]; while (q.length && seen.size < lim) { const [cx, cy] = q.shift(); for (const [dx, dy] of Object.values(D)) { const nx = cx + dx, ny = cy + dy, k2 = nx + ',' + ny; if (free(nx, ny) && !seen.has(k2)) { seen.add(k2); q.push([nx, ny]); } } } return seen.size; };
  const look = Math.round(ramp(lv, 12, 160)), aiMiss = ramp(lv, .25, 0);
  const speed = ramp(lv, .11, .055);
  const cx = p => ox + (p.px + (p.x - p.px) * Math.min(1, step / speed) + .5) * cs, cy = p => oy + (p.py + (p.y - p.py) * Math.min(1, step / speed) + .5) * cs;
  return loop({
    update(dt) {
      t += dt; C.update(dt); F.update(dt); decay(pops, dt);
      for (const bm of booms) bm.t += dt; booms = booms.filter(bm => bm.t < .6);
      for (const p of P) { let da = ANG[p.dir] - p.ang; while (da > Math.PI) da -= Math.PI * 2; while (da < -Math.PI) da += Math.PI * 2; p.ang += da * Math.min(1, dt * 18); }
      if (end) { endT += dt; return endT > 2.2 ? end : null; }
      if (t < 2.4) return null;
      if (roundOver > 0) { roundOver -= dt; if (roundOver <= 0) reset(); return null; }
      step += dt; if (step < speed) return null; step = 0;
      if (mode === 'bot') {
        const p = P[1];
        if (Math.random() >= aiMiss) {
          const opts2 = Object.keys(D).filter(d => d !== OPP[p.dir] && free(p.x + D[d][0], p.y + D[d][1]));
          if (opts2.length) {
            let best = opts2[0], bs = -1;
            for (const d of opts2) { const sc = space(p.x + D[d][0], p.y + D[d][1], look) + (d === p.dir ? 2 : 0) + rand(0, 1.5); if (sc > bs) { bs = sc; best = d; } }
            p.next = best;
          }
        }
      }
      for (const p of P) { p.px = p.x; p.py = p.y; p.dir = p.next; p.x += D[p.dir][0]; p.y += D[p.dir][1]; }
      const same = P[0].x === P[1].x && P[0].y === P[1].y;
      P.forEach((p, k) => {
        if (same || !free(p.x, p.y)) { p.dead = true; const X = ox + (p.px + .5) * cs, Y = oy + (p.py + .5) * cs; F.burst(X, Y, 26, [k ? RED : BLUE, '#fff', '#ffd43b'], 320); F.ring(X, Y, cs * 4, k ? '#ff8787' : '#74c0fc', 6); booms.push({x: X, y: Y, t: 0}); }
        else { grid[p.y][p.x] = k + 1; paint(p.x, p.y, k, p.px, p.py); }
      });
      if (P[0].dead || P[1].dead) {
        sfx('boom'); C.shake(12); step = speed;
        if (P[0].dead && !P[1].dead) { b++; pops[1] = 1; } else if (P[1].dead && !P[0].dead) { a++; pops[0] = 1; }
        if (a >= need || b >= need) { winner = a >= need ? 1 : 2; end = {winner, score: a * 5}; } else roundOver = 1.4;
      }
      return null;
    },
    draw() {
      ctx.drawImage(bg, 0, 0, W, H);
      C.begin(ctx);
      ctx.globalAlpha = .35 + Math.sin(t * 6) * .08; ctx.globalCompositeOperation = 'lighter'; ctx.drawImage(trail, -2, -2, W + 4, H + 4); ctx.globalCompositeOperation = 'source-over'; ctx.globalAlpha = 1;
      ctx.drawImage(trail, 0, 0, W, H);
      P.forEach((p, k) => {
        if (p.dead) return;
        const x = cx(p), y = cy(p), hgt = cs * 3.2;
        ctx.fillStyle = k ? 'rgba(255,107,107,.25)' : 'rgba(77,171,247,.25)'; ctx.beginPath(); ctx.arc(x, y, cs * 1.6, 0, 7); ctx.fill();
        if (!spr(ctx, MOTO, k ? 'red' : 'blue', x, y, hgt, {rot: p.ang})) drawHead(ctx, x, y, cs * .85, COS[k]);
      });
      for (const bm of booms) sprA(ctx, BOOM, 'explode', bm.t, bm.x, bm.y, cs * 5 * (1 + bm.t));
      F.draw(ctx);
      C.end(ctx);
      scoreBar(ctx, W, a, b, need, ...COS, pops);
      if (t < 2.4) vsIntro(ctx, W, H, lv, mode, `Thắng ${need} ván trước`, 'Vuốt trong nửa màn hình của mình để rẽ · Đừng đâm vào vệt sáng');
      if (end) endVs(ctx, W, H, winner, mode, lv, `${a} : ${b}`);
    }
  }, opts.alive);
});

// ---------- 8. Đấu sumo: kéo trong nửa của mình để lao đi, đẩy đối thủ ra khỏi vòng tròn ----------
// Vật lý tính trên mặt sàn tròn (nhìn từ trên), vẽ nghiêng 2.5D: y màn = tâm + (y - tâm) * K.
export const sumo = versus('🤼 Đấu sumo', async (box, opts, mode) => {
  const lv = opts.level || 0, th = theme(lv), need = 3;
  await loadAll(['Glowing star']);
  const COS = vsCos(opts, mode);
  const {cv, ctx, W, H} = canvasIn(box);
  const S = Math.min(W, H), F = fxb(), C = camera(), M = multi(cv), K = .55;
  const cx = W / 2, cy = (H + 100) / 2, RING = Math.min(W * .42, (H - 150) / (2 * K) * .9), pr = Math.min(S * .07, RING * .2);
  const sy = y => cy + (y - cy) * K;
  let P, a = 0, b = 0, t = 0, end = null, endT = 0, winner = 0, roundOver = 0;
  const pops = [0, 0];
  const reset = () => { P = [{x: cx - RING * .5, y: cy, vx: 0, vy: 0, m: 1, f: 1, push: 0, out: 0}, {x: cx + RING * .5, y: cy, vx: 0, vy: 0, m: mode === 'bot' ? ramp(lv, .8, 1.25) : 1, f: -1, push: 0, out: 0}]; roundOver = 0; };
  reset();
  const bg = prerender(W, H, g => {
    const gr = g.createLinearGradient(0, 0, 0, H); gr.addColorStop(0, th.sky[0]); gr.addColorStop(.45, th.sky[1]); gr.addColorStop(.45, th.ground); gr.addColorStop(1, th.ground); g.fillStyle = gr; g.fillRect(0, 0, W, H);
    // Bệ đất nâng cao: thành bên + mặt trên
    const pad = RING + pr * 1.4, side = S * .06;
    g.fillStyle = '#b07a3c'; g.beginPath(); g.ellipse(cx, cy + side, pad, pad * K, 0, 0, 7); g.fill(); g.fillRect(cx - pad, cy, pad * 2, side);
    g.fillStyle = '#e9c46a'; g.beginPath(); g.ellipse(cx, cy, pad, pad * K, 0, 0, 7); g.fill();
    g.fillStyle = '#f4dfa6'; g.beginPath(); g.ellipse(cx, cy, RING, RING * K, 0, 0, 7); g.fill();
    // Vòng dây rơm
    g.strokeStyle = '#c9a227'; g.lineWidth = 9; g.beginPath(); g.ellipse(cx, cy, RING, RING * K, 0, 0, 7); g.stroke();
    g.strokeStyle = 'rgba(255,255,255,.5)'; g.lineWidth = 2; g.setLineDash([5, 7]); g.stroke(); g.setLineDash([]);
    g.strokeStyle = '#a0522d'; g.lineWidth = 5; g.lineCap = 'round';
    for (const s of [-1, 1]) { g.beginPath(); g.moveTo(cx + s * RING * .12, cy - RING * K * .2); g.lineTo(cx + s * RING * .12, cy + RING * K * .2); g.stroke(); }
  });
  const stick = k => { for (const p of M.pts.values()) if ((p.sx < W / 2 ? 0 : 1) === k) { const dx = p.x - p.sx, dy = p.y - p.sy, d = Math.hypot(dx, dy); if (d > 6) return [dx / Math.max(d, 60), dy / Math.max(d, 60)]; } return [0, 0]; };
  const ACC = S * 2.4, aiSkill = ramp(lv, .35, 1);
  return loop({
    update(rdt) {
      t += rdt; C.update(rdt); const dt = rdt * C.scale(rdt); F.update(dt); decay(pops, rdt);
      for (const p of P) { p.push = Math.max(0, p.push - dt); if (p.out) { p.out += dt; p.x += p.vx * dt * .6; p.y += p.vy * dt * .6; } }
      if (end) { endT += rdt; return endT > 2.2 ? end : null; }
      if (t < 2.4) return null;
      if (roundOver > 0) { roundOver -= dt; if (roundOver <= 0) reset(); return null; }
      const inp = [stick(0), mode === 'pvp' ? stick(1) : [0, 0]];
      if (mode === 'bot') {
        const me = P[1], o = P[0], dc = Math.hypot(me.x - cx, me.y - cy);
        let tx = o.x + (o.x - cx) * .3 - me.x, ty = o.y + (o.y - cy) * .3 - me.y;
        if (dc > RING * .7 && Math.random() < aiSkill) { tx = cx - me.x; ty = cy - me.y; }
        const d = Math.hypot(tx, ty) || 1; inp[1] = [tx / d * (.55 + aiSkill * .45), ty / d * (.55 + aiSkill * .45)];
      }
      P.forEach((p, k) => {
        p.vx += inp[k][0] * ACC * dt; p.vy += inp[k][1] * ACC * dt; const fr = Math.exp(-dt * 1.6); p.vx *= fr; p.vy *= fr; p.x += p.vx * dt; p.y += p.vy * dt;
        const o = P[1 - k]; p.f = o.x > p.x ? 1 : -1;
        if (Math.hypot(p.vx, p.vy) > S * .5 && Math.random() < dt * 10) F.dust(p.x, sy(p.y), 1, 0, 'rgba(160,82,45,.45)');
      });
      const [p, q] = P, dx = q.x - p.x, dy = q.y - p.y, d = Math.hypot(dx, dy);
      if (d < pr * 2 && d > 0) {
        const nx = dx / d, ny = dy / d, ov = pr * 2 - d;
        p.x -= nx * ov / 2; p.y -= ny * ov / 2; q.x += nx * ov / 2; q.y += ny * ov / 2;
        const rel = (p.vx - q.vx) * nx + (p.vy - q.vy) * ny;
        if (rel > 0) {
          const j = 2.2 * rel / (1 / p.m + 1 / q.m); p.vx -= j / p.m * nx; p.vy -= j / p.m * ny; q.vx += j / q.m * nx; q.vy += j / q.m * ny;
          const pw = Math.min(1, rel / (S * 1.5)); p.push = q.push = .3;
          const mx = (p.x + q.x) / 2, my = sy((p.y + q.y) / 2) - pr * 1.6;
          sfx('pop'); F.ring(mx, my, 20 + pw * 40, '#fff', 5); F.sparks(mx, my, 3 + Math.round(pw * 6), '#fff3bf'); C.shake(1 + pw * 7); if (pw > .5) C.stop(.06);
        }
      }
      const out = P.map(p => Math.hypot(p.x - cx, p.y - cy) > RING + pr * .3);
      if (out[0] || out[1]) {
        sfx('boom'); C.shake(8); P.forEach((p, k) => { if (out[k]) { p.out = .001; F.burst(p.x, sy(p.y), 14, ['#e9c46a', '#a0522d', '#fff']); } });
        if (out[1] && !out[0]) { a++; pops[0] = 1; F.text(cx, sy(cy) - RING * K - 20, mode === 'pvp' ? '+1 XANH' : 'GIỎI QUÁ!', '#74c0fc', 38); } else if (out[0] && !out[1]) { b++; pops[1] = 1; F.text(cx, sy(cy) - RING * K - 20, '+1 ĐỎ', '#ff8787', 38); }
        if (a >= need || b >= need) { winner = a >= need ? 1 : 2; end = {winner, score: a * 5}; } else roundOver = 1.2;
      }
      return null;
    },
    draw() {
      ctx.drawImage(bg, 0, 0, W, H);
      C.begin(ctx);
      const order = P.map((p, k) => [p, k]).sort((u, v) => u[0].y - v[0].y);
      for (const [p, k] of order) {
        const X = p.x, Y = sy(p.y) + (p.out ? E.inCubic(Math.min(1, p.out * 1.5)) * S * .25 : 0), hh = pr * 3.3;
        const sp = Math.hypot(p.vx, p.vy);
        const pose = end ? (winner === k + 1 ? 'cheer' : 'hurt') : p.out ? 'hurt' : p.push > 0 ? 'block' : sp > S * .25 ? 'run' : 'idle';
        if (!p.out) shadow(ctx, X, Y, pr * 1.1, 0, .25);
        ctx.save();
        if (p.out) { ctx.translate(X, Y); ctx.rotate(-p.f * Math.min(1.2, p.out * 3)); ctx.translate(-X, -Y); }
        drawFigure(ctx, X, Y, hh, {c: COS[k], pose, t: t * (sp > S * .25 ? 1.5 : 1) + k, face: p.f, team: k ? RED : BLUE, alpha: p.out ? Math.max(0, 1 - p.out) : 1});
        ctx.restore();
      }
      F.draw(ctx);
      C.end(ctx);
      for (const p of M.pts.values()) { const k = p.sx < W / 2 ? 0 : 1; if (k && mode !== 'pvp') continue; ctx.strokeStyle = k ? 'rgba(250,82,82,.6)' : 'rgba(51,154,240,.6)'; ctx.lineWidth = 4; ctx.beginPath(); ctx.arc(p.sx, p.sy, 50, 0, 7); ctx.stroke(); ctx.fillStyle = ctx.strokeStyle; ctx.beginPath(); ctx.arc(p.sx + Math.max(-50, Math.min(50, p.x - p.sx)), p.sy + Math.max(-50, Math.min(50, p.y - p.sy)), 20, 0, 7); ctx.fill(); }
      scoreBar(ctx, W, a, b, need, ...COS, pops);
      if (t < 2.4) vsIntro(ctx, W, H, lv, mode, `Đẩy đối thủ ra ngoài ${need} lần`, 'Đặt tay ở nửa của mình rồi kéo về hướng muốn lao tới');
      if (end) endVs(ctx, W, H, winner, mode, lv, `${a} : ${b}`);
    }
  }, opts.alive);
});

// Bàn gỗ vẽ sẵn
function woodBoard(g, x, y, w, hh, r) {
  const gr = g.createLinearGradient(x, y, x + w, y + hh); gr.addColorStop(0, '#e8b77a'); gr.addColorStop(1, '#c98f4f');
  g.fillStyle = 'rgba(0,0,0,.18)'; roundRect(g, x + 6, y + 8, w, hh, r); g.fill();
  g.fillStyle = gr; roundRect(g, x, y, w, hh, r); g.fill();
  g.save(); roundRect(g, x, y, w, hh, r); g.clip();
  g.strokeStyle = 'rgba(120,70,30,.18)'; g.lineWidth = 2;
  for (let i = 0; i < 18; i++) { const yy = y + (i + .5) * hh / 18; g.beginPath(); g.moveTo(x, yy); g.bezierCurveTo(x + w * .3, yy + 6, x + w * .6, yy - 6, x + w, yy + 3); g.stroke(); }
  g.restore();
}
// Quân cờ: chip Kenney (xanh / đỏ), rơi xuống bàn có nảy
const CHIP = ['chipBlueWhite_border', 'chipRedWhite_border'];
function chip(ctx, CH, x, y, d, p, alpha = 1) {
  if (!spr(ctx, CH, CHIP[p - 1], x, y, d, {alpha})) { ctx.globalAlpha = alpha; ctx.fillStyle = p === 1 ? BLUE : RED; ctx.beginPath(); ctx.arc(x, y, d / 2, 0, 7); ctx.fill(); ctx.globalAlpha = 1; }
}

// ---------- 9. Cờ caro: cấp thấp 3x3 (3 ô), giữa 6x6 (4 ô), cao 9x9 (5 ô) ----------
export const caro = versus('❌⭕ Cờ caro', async (box, opts, mode) => {
  const lv = opts.level || 0;
  const [N, K] = lv < 10 ? [3, 3] : lv < 30 ? [6, 4] : [9, 5];
  await loadAll(['Glowing star']);
  const SP = await sheetsB(['kenney-board/chips']), CH = SP['kenney-board/chips'];
  const COS = vsCos(opts, mode);
  const {cv, ctx, W, H} = canvasIn(box);
  const F = fxb(), C = camera(), M = multi(cv), top = 100;
  const cs = Math.floor(Math.min((W - 30) / N, (H - top - 20) / N)), ox = (W - N * cs) / 2, oy = top + (H - top - 20 - N * cs) / 2;
  const g = Array.from({length: N}, () => Array(N).fill(0)), at = Array.from({length: N}, () => Array(N).fill(-9));
  let turn = 1, t = 0, end = null, endT = 0, winner = 0, line = null, lineT = 0, busy = false, last = null;
  const board = prerender(W, H, b => {
    b.fillStyle = '#fff9db'; b.fillRect(0, 0, W, H);
    woodBoard(b, ox - 12, oy - 12, N * cs + 24, N * cs + 24, 18);
    b.strokeStyle = 'rgba(90,50,20,.55)'; b.lineWidth = 2;
    for (let i = 1; i < N; i++) { b.beginPath(); b.moveTo(ox + i * cs, oy); b.lineTo(ox + i * cs, oy + N * cs); b.moveTo(ox, oy + i * cs); b.lineTo(ox + N * cs, oy + i * cs); b.stroke(); }
  });
  const lineAt = (x, y, p) => {
    for (const [dx, dy] of [[1, 0], [0, 1], [1, 1], [1, -1]]) {
      const cells = [[x, y]];
      for (const s of [1, -1]) for (let i = 1; i < K; i++) { const a = x + dx * i * s, b2 = y + dy * i * s; if (a < 0 || b2 < 0 || a >= N || b2 >= N || g[b2][a] !== p) break; cells.push([a, b2]); }
      if (cells.length >= K) return cells.sort((u, v) => u[0] - v[0] || u[1] - v[1]);
    }
    return null;
  };
  const full = () => g.every(r => r.every(Boolean));
  const place = (x, y) => {
    g[y][x] = turn; at[y][x] = t; last = [x, y]; sfx(turn === 1 ? 'tap' : 'pop');
    const ln = lineAt(x, y, turn);
    if (ln) { line = ln; lineT = t; winner = turn; end = {winner, score: 20}; sfx(turn === 1 ? 'win' : 'wrong'); setTimeout(() => { for (const [cx2, cy2] of ln) F.burst(ox + (cx2 + .5) * cs, oy + (cy2 + .5) * cs, 8); C.shake(5); }, 450); return; }
    if (full()) { winner = 0; end = {winner: 0, score: 5}; return; }
    turn = 3 - turn;
  };
  const scoreCell = (x, y, p) => { let sc = 0; for (const [dx, dy] of [[1, 0], [0, 1], [1, 1], [1, -1]]) { let n = 1, open = 0; for (const s of [1, -1]) { let i = 1; for (; i < K; i++) { const a = x + dx * i * s, b2 = y + dy * i * s; if (a < 0 || b2 < 0 || a >= N || b2 >= N) break; if (g[b2][a] === p) n++; else { if (!g[b2][a]) open++; break; } } } sc += n >= K ? 1e6 : Math.pow(10, n) * (open + .5); } return sc; };
  const aiRand = ramp(lv, .45, 0);
  const aiMove = () => {
    const empty = []; for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) if (!g[y][x]) empty.push([x, y]);
    if (Math.random() < aiRand) return pick(empty);
    let best = empty[0], bs = -1;
    for (const [x, y] of empty) { const s = scoreCell(x, y, 2) * 1.1 + scoreCell(x, y, 1) + rand(0, 3); if (s > bs) { bs = s; best = [x, y]; } }
    return best;
  };
  M.on('down', async p => {
    if (end || busy || t < 2) return;
    if (mode === 'bot' && turn === 2) return;
    const x = Math.floor((p.x - ox) / cs), y = Math.floor((p.y - oy) / cs);
    if (x < 0 || y < 0 || x >= N || y >= N || g[y][x]) return;
    place(x, y);
    if (!end && mode === 'bot') { busy = true; await wait(550); const [ax, ay] = aiMove(); place(ax, ay); busy = false; }
  });
  return loop({
    update(dt) { t += dt; C.update(dt); F.update(dt); if (end) { endT += dt; return endT > 2.6 ? end : null; } return null; },
    draw() {
      ctx.drawImage(board, 0, 0, W, H);
      C.begin(ctx);
      for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
        const v = g[y][x]; if (!v) continue;
        const X = ox + (x + .5) * cs, Y = oy + (y + .5) * cs, k = Math.min(1, (t - at[y][x]) / .35);
        const s = E.outBack(k), dy = (1 - E.outCubic(k)) * -cs * .5;
        if (last && last[0] === x && last[1] === y && !end) { ctx.fillStyle = `rgba(255,212,59,${.25 + Math.sin(t * 5) * .1})`; ctx.beginPath(); ctx.arc(X, Y, cs * .48, 0, 7); ctx.fill(); }
        shadow(ctx, X + 2, Y + cs * .3, cs * .3 * s, 0, .25);
        const win = line && line.some(c => c[0] === x && c[1] === y), pulse = win ? 1 + Math.sin(t * 8) * .06 : 1;
        chip(ctx, CH, X, Y + dy, cs * .8 * s * pulse, v);
        ctx.strokeStyle = '#fff'; ctx.lineWidth = Math.max(3, cs * .06); ctx.lineCap = 'round'; const r = cs * .12 * s;
        ctx.beginPath(); if (v === 1) { ctx.moveTo(X - r, Y + dy - r); ctx.lineTo(X + r, Y + dy + r); ctx.moveTo(X + r, Y + dy - r); ctx.lineTo(X - r, Y + dy + r); } else ctx.arc(X, Y + dy, r, 0, 7); ctx.stroke();
      }
      if (line) {
        const k = E.outCubic((t - lineT) / .5), s = line[0], e = line[line.length - 1];
        const x0 = ox + (s[0] + .5) * cs, y0 = oy + (s[1] + .5) * cs, x1 = ox + (e[0] + .5) * cs, y1 = oy + (e[1] + .5) * cs;
        ctx.strokeStyle = 'rgba(255,212,59,.95)'; ctx.lineWidth = 10; ctx.lineCap = 'round'; ctx.beginPath(); ctx.moveTo(x0, y0); ctx.lineTo(x0 + (x1 - x0) * k, y0 + (y1 - y0) * k); ctx.stroke();
      }
      F.draw(ctx);
      C.end(ctx);
      ctx.fillStyle = 'rgba(0,0,0,.3)'; roundRect(ctx, W / 2 - 150, 14, 300, 56, 28); ctx.fill();
      drawHead(ctx, W / 2 - 112, 44 - Math.abs(Math.sin(t * 4)) * 4, 18, COS[turn === 1 ? 0 : 1], {t});
      ctx.fillStyle = '#fff'; ctx.textAlign = 'center'; ctx.font = '800 24px "Baloo 2", sans-serif';
      ctx.fillText(end ? '' : turn === 1 ? (mode === 'pvp' ? 'Lượt XANH (✕)' : 'Lượt của bé (✕)') : (mode === 'pvp' ? 'Lượt ĐỎ (○)' : 'Máy đang nghĩ…'), W / 2 + 18, 50);
      if (t < 2) vsIntro(ctx, W, H, lv, mode, `Xếp ${K} ô liền nhau trước`, 'Chạm vào ô trống để đánh');
      if (end && endT > .7) endVs(ctx, W, H, winner, mode, lv, '');
    }
  }, opts.alive);
});

// ---------- 10. Nối bốn: thả quân vào cột, ai có 4 quân liền nhau trước thì thắng ----------
export const connect4 = versus('🔴🟡 Nối bốn', async (box, opts, mode) => {
  const lv = opts.level || 0, C7 = 7, R = 6;
  await loadAll(['Glowing star']);
  const SP = await sheetsB(['kenney-board/chips']), CH = SP['kenney-board/chips'];
  const COS = vsCos(opts, mode);
  const {cv, ctx, W, H} = canvasIn(box);
  const F = fxb(), C = camera(), M = multi(cv), top = 100;
  const cs = Math.floor(Math.min((W - 30) / C7, (H - top - 40) / (R + .6))), ox = (W - C7 * cs) / 2, oy = top + cs * .6;
  const g = Array.from({length: R}, () => Array(C7).fill(0));
  let turn = 1, t = 0, end = null, endT = 0, winner = 0, line = null, busy = false, drop = null, hover = 3, hx = ox + 3.5 * cs;
  // Mặt bàn có lỗ (khoét bằng destination-out) để quân rơi phía sau trông thật
  const front = prerender(W, H, b => {
    b.fillStyle = '#1971c2'; roundRect(b, ox - 10, oy - 10, C7 * cs + 20, R * cs + 20, 18); b.fill();
    b.fillStyle = 'rgba(255,255,255,.12)'; roundRect(b, ox - 10, oy - 10, C7 * cs + 20, cs * .4, 18); b.fill();
    b.globalCompositeOperation = 'destination-out'; b.fillStyle = '#000';
    for (let y = 0; y < R; y++) for (let x = 0; x < C7; x++) { b.beginPath(); b.arc(ox + (x + .5) * cs, oy + (y + .5) * cs, cs * .4, 0, 7); b.fill(); }
    b.globalCompositeOperation = 'source-over';
    b.strokeStyle = 'rgba(0,0,0,.25)'; b.lineWidth = 3;
    for (let y = 0; y < R; y++) for (let x = 0; x < C7; x++) { b.beginPath(); b.arc(ox + (x + .5) * cs, oy + (y + .5) * cs, cs * .4, 0, 7); b.stroke(); }
  });
  const win4 = (gg, p) => {
    for (let y = 0; y < R; y++) for (let x = 0; x < C7; x++) for (const [dx, dy] of [[1, 0], [0, 1], [1, 1], [1, -1]]) {
      const cells = [0, 1, 2, 3].map(i => [x + dx * i, y + dy * i]);
      if (cells.every(([a, b2]) => a >= 0 && b2 >= 0 && a < C7 && b2 < R && gg[b2][a] === p)) return cells;
    }
    return null;
  };
  const rowFor = (gg, c) => { for (let y = R - 1; y >= 0; y--) if (!gg[y][c]) return y; return -1; };
  const evalBoard = gg => { let s = 0; for (let y = 0; y < R; y++) for (let x = 0; x < C7; x++) for (const [dx, dy] of [[1, 0], [0, 1], [1, 1], [1, -1]]) { let m = 0, o = 0; for (let i = 0; i < 4; i++) { const a = x + dx * i, b2 = y + dy * i; if (a >= C7 || b2 < 0 || b2 >= R) { m = -9; break; } if (gg[b2][a] === 2) m++; else if (gg[b2][a] === 1) o++; } if (m < 0) continue; if (!o) s += [0, 1, 6, 40, 1000][m]; if (!m) s -= [0, 1, 6, 50, 1000][o]; } for (let y = 0; y < R; y++) if (gg[y][3] === 2) s += 3; return s; };
  const mm = (gg, d, al, be, maxP) => {
    if (win4(gg, 2)) return 1e5 + d; if (win4(gg, 1)) return -1e5 - d; if (!d) return evalBoard(gg);
    let best = maxP ? -1e9 : 1e9;
    for (const c of [3, 2, 4, 1, 5, 0, 6]) { const y = rowFor(gg, c); if (y < 0) continue; gg[y][c] = maxP ? 2 : 1; const v = mm(gg, d - 1, al, be, !maxP); gg[y][c] = 0; if (maxP) { best = Math.max(best, v); al = Math.max(al, v); } else { best = Math.min(best, v); be = Math.min(be, v); } if (be <= al) break; }
    return best === 1e9 || best === -1e9 ? 0 : best;
  };
  const depth = Math.round(ramp(lv, 1, 6)), aiRand = ramp(lv, .4, 0);
  const aiMove = () => {
    const cols = [...Array(C7).keys()].filter(c => rowFor(g, c) >= 0);
    if (Math.random() < aiRand) return pick(cols);
    let best = cols[0], bs = -1e9;
    for (const c of cols) { const y = rowFor(g, c); g[y][c] = 2; const v = mm(g, depth - 1, -1e9, 1e9, false) + rand(0, 2); g[y][c] = 0; if (v > bs) { bs = v; best = c; } }
    return best;
  };
  // Quân rơi theo trọng lực, nảy 2 lần ở đáy (tính trong update), xong thì gọi done()
  const play = c => new Promise(resolve => {
    const y = rowFor(g, c); if (y < 0) return resolve(false);
    drop = {c, y, p: turn, yy: oy - cs, vy: 0, ty: oy + y * cs, bounces: 0, done: () => {
      g[y][c] = drop.p; drop = null; sfx('pop');
      const ln = win4(g, turn);
      if (ln) { line = ln; winner = turn; end = {winner, score: 20}; sfx(turn === 1 ? 'win' : 'wrong'); for (const [x2, y2] of ln) F.burst(ox + (x2 + .5) * cs, oy + (y2 + .5) * cs, 8); C.shake(6); return resolve(true); }
      if (g[0].every(Boolean)) { end = {winner: 0, score: 5}; return resolve(true); }
      turn = 3 - turn; resolve(true);
    }};
    sfx('tap');
  });
  M.on('move', p => { hover = Math.max(0, Math.min(C7 - 1, Math.floor((p.x - ox) / cs))); });
  M.on('down', async p => {
    if (end || busy || t < 2) return;
    if (mode === 'bot' && turn === 2) return;
    const c = Math.floor((p.x - ox) / cs); if (c < 0 || c >= C7) return;
    hover = c; busy = true;
    if (await play(c) && !end && mode === 'bot') { await wait(300); hover = aiMove(); await wait(260); await play(hover); }
    busy = false;
  });
  return loop({
    update(dt) {
      t += dt; C.update(dt); F.update(dt);
      hx = approach(hx, ox + (hover + .5) * cs, 14, dt);
      if (drop) {
        drop.vy += cs * 60 * dt; drop.yy += drop.vy * dt;
        if (drop.yy >= drop.ty) {
          drop.yy = drop.ty;
          if (drop.bounces < 2 && drop.vy > cs * 4) { drop.vy = -drop.vy * .3; drop.bounces++; C.shake(drop.bounces === 1 ? 2.5 : 1); sfx('tap'); }
          else drop.done();
        }
      }
      if (end) { endT += dt; return endT > 2.6 ? end : null; }
      return null;
    },
    draw() {
      ctx.fillStyle = '#e7f5ff'; ctx.fillRect(0, 0, W, H);
      C.begin(ctx);
      ctx.fillStyle = '#d0ebff'; roundRect(ctx, ox - 10, oy - 10, C7 * cs + 20, R * cs + 20, 18); ctx.fill();
      for (let y = 0; y < R; y++) for (let x = 0; x < C7; x++) if (g[y][x]) {
        const win = line && line.some(c => c[0] === x && c[1] === y);
        chip(ctx, CH, ox + (x + .5) * cs, oy + (y + .5) * cs, cs * .84 * (win ? 1 + Math.sin(t * 8) * .05 : 1), g[y][x]);
      }
      if (drop) chip(ctx, CH, ox + (drop.c + .5) * cs, drop.yy + cs * .5, cs * .84, drop.p);
      ctx.drawImage(front, 0, 0, W, H);
      if (!end && !busy && (mode === 'pvp' || turn === 1)) chip(ctx, CH, hx, oy - cs * .55 + Math.sin(t * 5) * 3, cs * .8, turn, .9);
      if (line) for (const [x, y] of line) { ctx.strokeStyle = '#fff'; ctx.lineWidth = 5; ctx.beginPath(); ctx.arc(ox + (x + .5) * cs, oy + (y + .5) * cs, cs * .44 + Math.sin(t * 8) * 2, 0, 7); ctx.stroke(); }
      F.draw(ctx);
      C.end(ctx);
      ctx.fillStyle = 'rgba(0,0,0,.3)'; roundRect(ctx, W / 2 - 150, 14, 300, 56, 28); ctx.fill();
      drawHead(ctx, W / 2 - 112, 44 - Math.abs(Math.sin(t * 4)) * 4, 18, COS[turn === 1 ? 0 : 1], {t});
      ctx.fillStyle = '#fff'; ctx.textAlign = 'center'; ctx.font = '800 24px "Baloo 2", sans-serif';
      ctx.fillText(end ? '' : turn === 1 ? (mode === 'pvp' ? 'Lượt XANH' : 'Lượt của bé (xanh)') : (mode === 'pvp' ? 'Lượt ĐỎ' : 'Máy đang nghĩ…'), W / 2 + 18, 50);
      if (t < 2) vsIntro(ctx, W, H, lv, mode, 'Nối 4 quân liền nhau trước', 'Chạm vào cột để thả quân');
      if (end && endT > .6) endVs(ctx, W, H, winner, mode, lv, '');
    }
  }, opts.alive);
});
