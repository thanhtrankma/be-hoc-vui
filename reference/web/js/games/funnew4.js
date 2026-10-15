// Game mới (đợt 15, phần 2): Tiệm pizza, Nông trại vui vẻ, Lính cứu hoả nhí, Tìm đồ vật.
// Người/con vật là sprite Kenney CC0 có hoạt ảnh (sheets.js), đồ vật là hình Fluent Emoji 3D.
import {sfx} from '../audio.js?v=4c51d34a6e';
import {banner, canvasIn, draw, endText, fx, goalPill, hud, levelBanner, loadAll, loop, pick, rand, ramp, roundRect, theme} from './funcore.js?v=4c51d34a6e';
import {drawAnim, drawFrame} from './sheets.js?v=4c51d34a6e';
import {hearts, kidOf, pill, shadow, sheets, skyFill, taps} from './funnew3.js?v=4c51d34a6e';

const shuffle = a => { for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; };
const inBox = (x, y, b) => x >= b.x && x <= b.x + b.w && y >= b.y && y <= b.y + b.h;
function button(ctx, b, text, color, on = true) {
  ctx.fillStyle = on ? color : 'rgba(0,0,0,.25)'; roundRect(ctx, b.x, b.y, b.w, b.h, b.h / 2); ctx.fill();
  ctx.fillStyle = '#fff'; ctx.textAlign = 'center'; ctx.font = `800 ${Math.round(b.h * .45)}px "Baloo 2", sans-serif`; ctx.fillText(text, b.x + b.w / 2, b.y + b.h * .66);
}

// ---------- 7. Tiệm pizza: khách vào gọi món (mấy cái nấm, mấy quả cà chua...), bé chạm nguyên liệu để rắc lên bánh
// cho ĐỦ SỐ LƯỢNG rồi bấm Giao. Chạm vào miếng trên bánh để bỏ bớt. Rèn đếm số. ----------
const TOPS = ['Mushroom', 'Tomato', 'Olive', 'Bell pepper', 'Cheese wedge', 'Shrimp', 'Pineapple', 'Onion'];
export async function pizza(box, opts) {
  const lv = opts.level || 0, need = Math.min(8, 3 + Math.floor(lv / 10));
  const nT = Math.min(TOPS.length, 4 + Math.floor(lv / 12)), tops = TOPS.slice(0, nT);
  const PEOPLE = ['woman', 'man', 'kidgirl', 'kidboy', 'robot'];
  const SH = await sheets(PEOPLE);
  await loadAll([...TOPS, 'Red heart', 'Coin', 'Cook', 'Pizza', 'Potted plant', 'Thought balloon']);
  const {cv, ctx, W, H} = canvasIn(box);
  const S = Math.min(W, H), F = fx(), bot = opts.bot;
  const counterY = H * .44, ph = Math.min(S * .3, counterY * .62);
  const pz = {x: W / 2, y: H * (W < 640 ? .6 : .64), r: Math.min(W * .3, H * .15)};
  // Khay nguyên liệu: màn hẹp nhiều món thì xếp 2 hàng cho ô đủ to để bé chạm.
  const perRow = W / nT < 72 ? Math.ceil(nT / 2) : nT, tw = Math.min((W - 16) / perRow, 110), trayY = H - 12 - tw * Math.ceil(nT / perRow) / 2;
  const trayB = tops.map((k, i) => { const r = Math.floor(i / perRow), c = i % perRow, n = Math.min(perRow, nT - r * perRow); return {k, x: W / 2 - tw * n / 2 + c * tw, y: trayY - tw * .45 + (r - (Math.ceil(nT / perRow) - 1) / 2) * tw, w: tw, h: tw * .9}; });
  const goB = {x: W - Math.min(170, W * .32) - 14, y: pz.y - 30, w: Math.min(170, W * .32), h: 60};
  if (W < 640) { goB.w = Math.min(150, W * .42); goB.h = 50; goB.x = W - goB.w - 10; goB.y = Math.min(pz.y + pz.r * .66 + 6, Math.min(...trayB.map(b => b.y)) - goB.h - 8); }
  const maxN = Math.round(ramp(lv, 3, 6)), kinds = lv < 6 ? 1 : lv < 25 ? 2 : 3;
  const patience = ramp(lv, 40, 18);
  let served = 0, lives = 3, t = 0, end = null, endT = 0, cust = null, placed = [], botT = 0;
  const newCust = () => {
    const ks = shuffle([...tops]).slice(0, kinds);
    cust = {k: pick(PEOPLE), x: W + 80, tx: W * .5, st: 'in', wait: patience, order: ks.map(k => ({k, n: 1 + Math.floor(Math.random() * maxN)})), mood: 0};
    placed = [];
  };
  newCust();
  const count = k => placed.filter(p => p.k === k).length;
  const addTop = k => {
    if (placed.length >= 18) return;
    const a = rand(0, Math.PI * 2), d = Math.sqrt(Math.random()) * pz.r * .72;
    placed.push({k, x: pz.x + Math.cos(a) * d, y: pz.y + Math.sin(a) * d * .62, r: rand(-.5, .5), pop: .25}); sfx('pop');
  };
  const serve = () => {
    if (!cust || cust.st !== 'wait') return;
    const ok = cust.order.every(o => count(o.k) === o.n) && placed.every(p => cust.order.some(o => o.k === p.k));
    if (ok) { served++; cust.st = 'happy'; cust.mood = 1.2; sfx('correct'); F.burst(pz.x, pz.y, 24); F.text(pz.x, pz.y - pz.r, `${served}/${need}`, '#ffd43b'); if (served >= need) { end = {win: true, score: served * 10 + lives * 5}; sfx('win'); } }
    else { sfx('wrong'); cust.mood = -1; lives--; F.text(pz.x, pz.y - pz.r, 'Chưa đúng số!', '#ff8787'); if (lives <= 0) end = {win: false, score: served * 10}; }
  };
  taps(cv, {onTap: (x, y) => {
    if (t < 2 || end || !cust || cust.st !== 'wait') return;
    const b = trayB.find(b => inBox(x, y, b)); if (b) return addTop(b.k);
    if (inBox(x, y, goB)) return serve();
    for (let i = placed.length - 1; i >= 0; i--) if (Math.hypot(placed[i].x - x, placed[i].y - y) < pz.r * .2) { placed.splice(i, 1); sfx('flip'); return; }
  }});
  return loop({
    update(dt) {
      t += dt; F.update(dt);
      for (const p of placed) p.pop = Math.max(0, p.pop - dt);
      if (end) { endT += dt; if (cust && cust.st === 'happy') cust.x -= 0; return endT > 2 ? end : null; }
      if (t < 2 || !cust) return null;
      if (cust.st === 'in') { cust.x -= S * .5 * dt; if (cust.x <= cust.tx) { cust.x = cust.tx; cust.st = 'wait'; } }
      else if (cust.st === 'wait') {
        cust.wait -= dt; cust.mood = Math.max(-1, cust.mood - dt) * (cust.mood > 0 ? 1 : 1);
        if (cust.mood < 0) cust.mood = Math.min(0, cust.mood + dt);
        if (cust.wait <= 0) { lives--; sfx('wrong'); cust.st = 'out'; cust.sad = true; if (lives <= 0) end = {win: false, score: served * 10}; }
        if (bot && (botT += dt) > .25) {
          botT = 0;
          const o = cust.order.find(o => count(o.k) < o.n); if (o) addTop(o.k); else serve();
        }
      } else if (cust.st === 'happy') { cust.mood -= dt; if (cust.mood <= 0) cust.st = 'out'; }
      else if (cust.st === 'out') { cust.x -= S * .6 * dt; if (cust.x < -80) newCust(); }
      return null;
    },
    draw() {
      // Tường tiệm + quầy
      ctx.fillStyle = '#ffe8cc'; ctx.fillRect(0, 0, W, counterY);
      ctx.fillStyle = '#ffd8a8'; for (let x = 0; x < W; x += 60) ctx.fillRect(x, 0, 30, counterY);
      draw(ctx, 'Potted plant', W * .08, counterY - S * .07, S * .12); draw(ctx, 'Cook', W * .92, counterY - S * .08, S * .12);
      if (cust) {
        const anim = cust.st === 'in' || cust.st === 'out' ? 'walk' : cust.st === 'happy' ? 'cheer' : cust.mood < 0 || cust.wait < patience * .25 ? 'think' : 'idle';
        drawAnim(ctx, SH[cust.k], anim, t, cust.x, counterY + ph * .1, ph, {flip: cust.st === 'in' || cust.st === 'out'});
        if (cust.st === 'wait') {
          // Bóng nói: món gọi. Cấp thấp vẽ đủ từng cái để bé đếm; cấp cao ghi "× số".
          const bw = Math.min(W * .94, 90 + cust.order.length * 190), bh = 92, bx = W / 2 - bw / 2, by = 64 + (W < 640 ? 48 : 0);
          ctx.fillStyle = '#fff'; roundRect(ctx, bx, by, bw, bh, 22); ctx.fill();
          ctx.beginPath(); ctx.moveTo(cust.x - 10, by + bh); ctx.lineTo(cust.x + 10, by + bh); ctx.lineTo(cust.x, by + bh + 16); ctx.fill();
          const seg = bw / cust.order.length;
          cust.order.forEach((o, i) => {
            const cx = bx + seg * (i + .5), have = count(o.k);
            if (lv < 12 && o.n <= 4) for (let j = 0; j < o.n; j++) draw(ctx, o.k, cx + (j - (o.n - 1) / 2) * Math.min(54, seg / (o.n + .3)), by + bh / 2 - 4, Math.min(54, seg / (o.n + .3)), undefined, {alpha: j < have ? .35 : 1});
            else { draw(ctx, o.k, cx - 32, by + bh / 2 - 4, 56); ctx.fillStyle = have === o.n ? '#2f9e44' : '#212529'; ctx.font = '800 32px "Baloo 2", sans-serif'; ctx.textAlign = 'left'; ctx.fillText(`× ${o.n}`, cx, by + bh / 2 + 8); }
          });
          // Thanh kiên nhẫn
          const k = Math.max(0, cust.wait / patience);
          ctx.fillStyle = 'rgba(0,0,0,.15)'; roundRect(ctx, bx + 12, by + bh - 12, bw - 24, 7, 4); ctx.fill();
          ctx.fillStyle = k > .4 ? '#40c057' : k > .2 ? '#fab005' : '#fa5252'; roundRect(ctx, bx + 12, by + bh - 12, (bw - 24) * k, 7, 4); ctx.fill();
        }
      }
      ctx.fillStyle = '#a0522d'; ctx.fillRect(0, counterY, W, H - counterY);
      ctx.fillStyle = '#8b4513'; ctx.fillRect(0, counterY, W, 14);
      // Bánh pizza: đế + sốt + phô mai
      shadow(ctx, pz.x, pz.y + pz.r * .5, pz.r * 2.05, .2);
      ctx.fillStyle = '#e8a75d'; ctx.beginPath(); ctx.ellipse(pz.x, pz.y, pz.r, pz.r * .66, 0, 0, 7); ctx.fill();
      ctx.fillStyle = '#d9480f'; ctx.beginPath(); ctx.ellipse(pz.x, pz.y, pz.r * .86, pz.r * .56, 0, 0, 7); ctx.fill();
      ctx.fillStyle = 'rgba(255,224,102,.75)'; for (let i = 0; i < 7; i++) { ctx.beginPath(); ctx.ellipse(pz.x + Math.cos(i * 2.4) * pz.r * .45, pz.y + Math.sin(i * 2.4) * pz.r * .28, pz.r * .22, pz.r * .13, i, 0, 7); ctx.fill(); }
      for (const p of placed) draw(ctx, p.k, p.x, p.y, pz.r * .32 * (1 + p.pop * 1.5), undefined, {rot: p.r});
      // Khay nguyên liệu
      for (const b of trayB) { ctx.fillStyle = 'rgba(0,0,0,.18)'; ctx.fillRect(b.x, b.y - tw * .05, b.w, tw); }
      for (const b of trayB) { ctx.fillStyle = '#fff4e6'; roundRect(ctx, b.x + 4, b.y, b.w - 8, b.h, 16); ctx.fill(); draw(ctx, b.k, b.x + b.w / 2, b.y + b.h / 2, b.h * .7); }
      button(ctx, goB, '✔ Giao', '#2f9e44', cust && cust.st === 'wait');
      F.draw(ctx);
      hud(ctx, W, {score: served, lives: 0, time: null}); hearts(ctx, W, lives);
      goalPill(ctx, W, served, need, 16);
      if (t < 2) levelBanner(ctx, W, H, lv, `Làm bánh cho ${need} khách`, 'Rắc đúng số nguyên liệu khách gọi rồi bấm Giao');
      if (end) banner(ctx, W, H, end.win ? endText(true, lv) : 'TIỆM ĐÓNG CỬA!', `${served}/${need} khách`);
    }
  }, opts.alive);
}

// ---------- 8. Nông trại vui vẻ: chạm ô đất để bé đi tới gieo hạt → tưới nước → chờ lớn → thu hoạch.
// Chuột, sâu, ốc bò vào ăn cây: chạm vào để đuổi. Thu đủ nông sản trước khi hết giờ. ----------
const CROPS = ['Carrot', 'Ear of corn', 'Tomato', 'Strawberry', 'Eggplant', 'Broccoli', 'Potato'];
export async function farm(box, opts) {
  const lv = opts.level || 0, th = theme(lv), need = Math.round(ramp(lv, 6, 18)), kid = kidOf(opts);
  const crop = CROPS[Math.floor(lv / 3) % CROPS.length];
  const SH = await sheets([kid, 'critters', 'items']);
  await loadAll([...CROPS, 'Seedling', 'Droplet', 'Basket', 'Red heart', 'Coin', 'House', 'Wilted flower', th.sun]);
  const {cv, ctx, W, H} = canvasIn(box);
  const S = Math.min(W, H), F = fx(), bot = opts.bot;
  const cols = lv < 10 ? 3 : 4, rows = lv < 20 ? 2 : 3;
  const fy0 = H * .4, fy1 = H * .94, cw = Math.min((W - 40) / cols, (fy1 - fy0) / rows * 1.25), chh = (fy1 - fy0) / rows;
  const fx0 = W / 2 - cw * cols / 2;
  const plots = [];
  for (let r = 0; r < rows; r++) for (let c = 0; c < cols; c++) plots.push({x: fx0 + (c + .5) * cw, y: fy0 + (r + .5) * chh, st: 0, g: 0, ripe: 0});
  const grow = ramp(lv, 4.5, 6.5), wilt = lv >= 20 ? ramp(lv, 14, 8) : 1e9;
  const ph = Math.min(S * .2, chh * 1.15);
  const me = {x: W / 2, y: fy0 - 10, tx: null, plot: null, work: 0, face: 1};
  const pests = [];
  let time = Math.round(ramp(lv, 80, 95)), got = 0, t = 0, end = null, endT = 0, pestT = rand(6, 9), botT = 0;
  const actOn = p => {
    if (p.st === 0) { p.st = 1; p.g = 0; sfx('pop'); }
    else if (p.st === 1) { p.st = 2; p.g = 0; sfx('splash'); F.burst(p.x, p.y, 10, ['#74c0fc', '#a5d8ff']); }
    else if (p.st === 3) { p.st = 0; got++; sfx('coin'); F.text(p.x, p.y - 40, `${got}/${need}`, '#ffd43b'); F.star(p.x, p.y); if (got >= need) { end = {win: true, score: got * 5 + Math.round(time)}; sfx('win'); } }
    else if (p.st === 4) { p.st = 0; sfx('flip'); }
  };
  const goTo = p => { me.plot = p; me.tx = {x: p.x - cw * .32, y: p.y + chh * .3}; };
  taps(cv, {onTap: (x, y) => {
    if (t < 2 || end) return;
    for (const z of pests) if (!z.run && Math.hypot(z.x - x, z.y - y) < S * .08) { z.run = true; z.vx = (z.x < W / 2 ? -1 : 1) * S * .7; sfx('squeak'); return; }
    const p = plots.find(p => Math.abs(p.x - x) < cw / 2 && Math.abs(p.y - y) < chh / 2);
    if (p && p.st !== 2) goTo(p);
  }});
  return loop({
    update(dt) {
      t += dt; F.update(dt);
      if (end) { endT += dt; return endT > 2 ? end : null; }
      if (t < 2) return null;
      time -= dt;
      for (const p of plots) {
        if (p.st === 2) { p.g += dt / grow; if (p.g >= 1) { p.st = 3; p.ripe = 0; sfx('star'); } }
        else if (p.st === 3) { p.ripe += dt; if (p.ripe > wilt) p.st = 4; }
      }
      if (me.tx) {
        const dx = me.tx.x - me.x, dy = me.tx.y - me.y, d = Math.hypot(dx, dy), sp = S * .9;
        if (Math.abs(dx) > 2) me.face = dx > 0 ? 1 : -1;
        if (d < sp * dt) { me.x = me.tx.x; me.y = me.tx.y; me.tx = null; me.work = .45; }
        else { me.x += dx / d * sp * dt; me.y += dy / d * sp * dt; }
      } else if (me.work > 0) { me.work -= dt; if (me.work <= 0 && me.plot) { actOn(me.plot); me.plot = null; } }
      if (lv >= 6) {
        pestT -= dt;
        if (pestT <= 0) {
          pestT = rand(5, 8) * ramp(lv, 1.3, .55);
          const ok = plots.filter(p => p.st >= 2 && p.st <= 3);
          if (ok.length) { const p = pick(ok), side = Math.random() < .5 ? -1 : 1; pests.push({k: pick(['mouse', 'worm', 'snail']), x: side < 0 ? -40 : W + 40, y: p.y + chh * .15, p, vx: 0, run: false, eat: 0}); }
        }
      }
      for (let i = pests.length - 1; i >= 0; i--) {
        const z = pests[i];
        if (z.run) { z.x += z.vx * dt; if (z.x < -60 || z.x > W + 60) pests.splice(i, 1); continue; }
        if (z.p.st < 2 || z.p.st > 3) { z.run = true; z.vx = (z.x < W / 2 ? -1 : 1) * S * .5; continue; }
        const dx = z.p.x - z.x; z.vx = Math.sign(dx) * S * ramp(lv, .1, .2);
        if (Math.abs(dx) > 8) z.x += z.vx * dt;
        else { z.eat += dt; if (z.eat > 1.6) { z.p.st = 0; sfx('eat'); F.text(z.p.x, z.p.y - 30, 'Bị ăn mất!', '#ff8787'); z.run = true; z.vx = (z.x < W / 2 ? -1 : 1) * S * .5; } }
      }
      if (bot && !me.tx && me.work <= 0 && (botT += dt) > .2) {
        botT = 0;
        for (const z of pests) if (!z.run) { z.run = true; z.vx = S * .7; }
        const p = plots.find(p => p.st === 3 || p.st === 4) || plots.find(p => p.st === 1) || plots.find(p => p.st === 0);
        if (p) goTo(p);
      }
      if (time <= 0 && !end) { time = 0; end = {win: false, score: got * 5}; sfx('wrong'); }
      return null;
    },
    draw() {
      skyFill(ctx, W, H, th);
      draw(ctx, th.sun, W * .88, H * .1, S * .12);
      draw(ctx, 'House', W * .12, fy0 - S * .13, S * .24);
      for (let x = W * .28; x < W; x += S * .1) drawFrame(ctx, SH.items, 'fence', x, fy0 - S * .055, S * .1);
      ctx.fillStyle = '#8ce99a'; ctx.fillRect(0, fy0 - 14, W, H - fy0 + 14);
      draw(ctx, 'Basket', W - 70, fy0 - S * .06, S * .1);
      for (const p of plots) {
        const x = p.x - cw / 2 + 6, y = p.y - chh / 2 + 6, w = cw - 12, h = chh - 12;
        ctx.fillStyle = p.st === 0 ? '#a9714b' : '#7b4a2a'; roundRect(ctx, x, y, w, h, 14); ctx.fill();
        ctx.fillStyle = 'rgba(0,0,0,.12)'; for (let k = 1; k < 4; k++) ctx.fillRect(x + 8, y + h * k / 4, w - 16, 4);
        const s = Math.min(w, h);
        if (p.st === 1) { draw(ctx, 'Seedling', p.x, p.y, s * .35); draw(ctx, 'Droplet', p.x + s * .3, p.y - s * .3 + Math.sin(t * 5) * 4, s * .25); }
        else if (p.st === 2) { draw(ctx, 'Seedling', p.x, p.y + s * .1 * (1 - p.g), s * (.35 + .35 * p.g)); ctx.fillStyle = 'rgba(0,0,0,.25)'; roundRect(ctx, p.x - s * .3, p.y + h * .36, s * .6, 7, 4); ctx.fill(); ctx.fillStyle = '#69db7c'; roundRect(ctx, p.x - s * .3, p.y + h * .36, s * .6 * p.g, 7, 4); ctx.fill(); }
        else if (p.st === 3) draw(ctx, crop, p.x, p.y - Math.abs(Math.sin(t * 4)) * 5, s * .62);
        else if (p.st === 4) draw(ctx, 'Wilted flower', p.x, p.y, s * .5);
      }
      for (const z of pests) drawAnim(ctx, SH.critters, z.k, t, z.x, z.y, S * .075, {flip: z.vx > 0});
      shadow(ctx, me.x, me.y, ph * .45);
      drawAnim(ctx, SH[kid], end?.win ? 'cheer' : me.tx ? 'walk' : me.work > 0 ? 'work' : 'idle', t, me.x, me.y, ph, {flip: me.face < 0});
      F.draw(ctx);
      hud(ctx, W, {score: got, lives: 0, time});
      goalPill(ctx, W, got, need);
      if (t < 2) levelBanner(ctx, W, H, lv, `Thu hoạch ${need} ${crop === 'Ear of corn' ? 'bắp ngô' : 'nông sản'}`, 'Chạm ô đất: gieo hạt → tưới nước → hái · Chạm con vật để đuổi');
      if (end) banner(ctx, W, H, end.win ? endText(true, lv) : 'HẾT GIỜ!', `${got}/${need}`);
    }
  }, opts.alive);
}

// ---------- 9. Lính cứu hoả nhí: lửa bùng ở các ô cửa sổ, chạm vào ô cháy để xe cứu hoả chạy tới phun nước.
// Dập xong thì người trong nhà vẫy tay cảm ơn. Lửa cháy quá lâu là mất một tim. ----------
export async function firefight(box, opts) {
  const lv = opts.level || 0, need = Math.round(ramp(lv, 6, 22)), kid = kidOf(opts);
  const PEOPLE = ['woman', 'man', 'kidgirl', 'kidboy'];
  const SH = await sheets([kid, ...PEOPLE.filter(k => k !== kid), 'items']);
  await loadAll(['Fire', 'Fire engine', 'Droplet', 'Red heart', 'Coin', 'Cloud', 'Deciduous tree']);
  const {cv, ctx, W, H} = canvasIn(box);
  const S = Math.min(W, H), F = fx(), bot = opts.bot;
  const cols = Math.min(5, 3 + Math.floor(lv / 20) + (W > 700 ? 1 : 0)), rows = lv < 12 ? 2 : 3;
  const road = H * .88, bTop = Math.max(H * .2, 150), bw = Math.min(W * .86, cols * 150), bx = W / 2 - bw / 2;
  const cw = bw / cols, chh = (road - S * .26 - bTop) / rows;
  const wins = [];
  for (let r = 0; r < rows; r++) for (let c = 0; c < cols; c++) wins.push({x: bx + (c + .5) * cw, y: bTop + (r + .5) * chh, fire: 0, burn: 0, who: pick(PEOPLE), thanks: 0, black: 0});
  const growR = ramp(lv, .1, .22), dryR = ramp(lv, .75, .55), maxBurn = ramp(lv, 9, 5);
  const truck = {x: W / 2, tx: W / 2, target: null, spray: 0};
  let out = 0, lives = 3, t = 0, end = null, endT = 0, spawnT = 1, drops = [];
  taps(cv, {onTap: (x, y) => {
    if (t < 2 || end) return;
    const w = wins.find(w => Math.abs(w.x - x) < cw / 2 && Math.abs(w.y - y) < chh / 2);
    if (w && w.fire > 0) { truck.target = w; truck.tx = w.x; sfx('tap'); }
    else if (y > road - S * .2) truck.tx = Math.max(60, Math.min(W - 60, x));
  }});
  const nozzle = () => ({x: truck.x - S * .02, y: road - S * .17});
  return loop({
    update(dt) {
      t += dt; F.update(dt);
      for (const w of wins) { w.thanks = Math.max(0, w.thanks - dt); w.black = Math.max(0, w.black - dt); }
      if (end) { endT += dt; return endT > 2 ? end : null; }
      if (t < 2) return null;
      spawnT -= dt;
      const burning = wins.filter(w => w.fire > 0).length;
      if (spawnT <= 0 && burning < Math.min(wins.length - 1, 1 + Math.floor(lv / 12))) {
        spawnT = rand(1.6, 3) * ramp(lv, 1.3, .6);
        const free = wins.filter(w => w.fire <= 0 && w.black <= 0); if (free.length) { const w = pick(free); w.fire = .3; w.burn = 0; }
      }
      if (bot && (!truck.target || truck.target.fire <= 0)) { const w = wins.filter(w => w.fire > 0).sort((a, b) => b.burn - a.burn)[0]; if (w) { truck.target = w; truck.tx = w.x; } }
      const d = truck.tx - truck.x, sp = S * 1.1;
      truck.x += Math.abs(d) < sp * dt ? d : Math.sign(d) * sp * dt;
      const tg = truck.target;
      truck.spray = 0;
      if (tg && tg.fire > 0 && Math.abs(truck.x - truck.tx) < 4) {
        truck.spray = 1;
        tg.fire -= dryR * dt;
        if (Math.random() < dt * 30) { const n = nozzle(); drops.push({x: n.x, y: n.y, t: 0, tx: tg.x + rand(-15, 15), ty: tg.y + rand(-10, 10)}); }
        if (tg.fire <= 0) { tg.fire = 0; out++; tg.thanks = 1.8; sfx('correct'); F.burst(tg.x, tg.y, 16, ['#dee2e6', '#f8f9fa', '#74c0fc']); F.text(tg.x, tg.y - 40, `${out}/${need}`, '#ffd43b'); truck.target = null; if (out >= need) { end = {win: true, score: out * 8 + lives * 5}; sfx('win'); } }
      }
      for (const w of wins) if (w.fire > 0 && w !== (truck.spray ? tg : null)) {
        w.fire = Math.min(1, w.fire + growR * dt); w.burn += dt;
        if (w.burn > maxBurn) { w.fire = 0; w.black = 4; lives--; sfx('hit'); F.burst(w.x, w.y, 14, ['#495057', '#868e96']); if (truck.target === w) truck.target = null; if (lives <= 0) { end = {win: false, score: out * 8}; sfx('wrong'); } }
      }
      for (let i = drops.length - 1; i >= 0; i--) { drops[i].t += dt * 2.2; if (drops[i].t >= 1) drops.splice(i, 1); }
      return null;
    },
    draw() {
      const g = ctx.createLinearGradient(0, 0, 0, H); g.addColorStop(0, '#74c0fc'); g.addColorStop(1, '#e7f5ff'); ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
      draw(ctx, 'Cloud', W * .15, H * .1, S * .18, S * .11); draw(ctx, 'Cloud', W * .8, H * .08, S * .14, S * .09);
      draw(ctx, 'Deciduous tree', bx - S * .07, road - S * .11, S * .22); draw(ctx, 'Deciduous tree', bx + bw + S * .07, road - S * .11, S * .22);
      // Toà nhà
      ctx.fillStyle = '#e0a370'; roundRect(ctx, bx - 14, bTop - chh * .45, bw + 28, road - bTop + chh * .45, 12); ctx.fill();
      ctx.fillStyle = 'rgba(0,0,0,.12)'; for (let y = bTop - chh * .45 + 16; y < road; y += 22) ctx.fillRect(bx - 14, y, bw + 28, 3);
      ctx.fillStyle = '#7b4a2a'; ctx.fillRect(bx - 24, bTop - chh * .5 - 12, bw + 48, 16);
      drawFrame(ctx, SH.items, 'door_open', W / 2, road - S * .1, S * .2);
      const ws = Math.min(cw, chh) * .8;
      for (const w of wins) {
        drawFrame(ctx, SH.items, 'window', w.x, w.y, ws);
        if (w.thanks > 0) drawAnim(ctx, SH[w.who], 'cheer', t, w.x, w.y + ws * .4, ws * .85);  // người trong nhà vẫy tay cảm ơn
        if (w.black > 0) { ctx.fillStyle = `rgba(52,58,64,${Math.min(.8, w.black)})`; roundRect(ctx, w.x - ws * .42, w.y - ws * .42, ws * .84, ws * .84, 8); ctx.fill(); }
        if (w.fire > 0) {
          const s = ws * (.45 + .6 * w.fire);
          for (let k = 0; k < 3; k++) draw(ctx, 'Fire', w.x + (k - 1) * s * .28, w.y + ws * .3 - s * .5 * (1 + .08 * Math.sin(t * 14 + k * 2)), s * (k === 1 ? 1 : .7), undefined, {alpha: .95});
          if (w.burn > maxBurn * .6) { ctx.fillStyle = 'rgba(250,82,82,.9)'; ctx.font = '800 26px "Baloo 2", sans-serif'; ctx.textAlign = 'center'; ctx.fillText('!', w.x + ws * .45, w.y - ws * .3); }
        }
      }
      ctx.fillStyle = '#495057'; ctx.fillRect(0, road, W, H - road);
      ctx.fillStyle = '#fff'; for (let x = 0; x < W; x += 70) ctx.fillRect(x, road + (H - road) / 2, 36, 4);
      // Tia nước
      for (const d of drops) { const k = d.t, x = d.x + (d.tx - d.x) * k, y = d.y + (d.ty - d.y) * k - Math.sin(k * Math.PI) * S * .12; draw(ctx, 'Droplet', x, y, S * .035); }
      const tw = S * .32;
      draw(ctx, 'Fire engine', truck.x, road - tw * .3, tw, tw * .8, {flip: true});
      drawAnim(ctx, SH[kid], truck.spray ? 'hold' : 'idle', t, truck.x - tw * .05, road - tw * .48, S * .14);
      F.draw(ctx);
      hud(ctx, W, {score: out, lives: 0, time: null}); hearts(ctx, W, lives);
      goalPill(ctx, W, out, need);
      if (t < 2) levelBanner(ctx, W, H, lv, `Dập ${need} đám lửa`, 'Chạm vào cửa sổ đang cháy để xe tới phun nước');
      if (end) banner(ctx, W, H, end.win ? endText(true, lv) : 'LỬA LỚN QUÁ!', `${out}/${need} đám lửa`);
    }
  }, opts.alive);
}

// ---------- 10. Tìm đồ vật: căn phòng đầy đồ, tìm đủ các món ở khay dưới. Chạm sai bị trừ 3 giây. ----------
const FIND = ['Teddy bear', 'Kite', 'Umbrella', 'Alarm clock', 'Crayon', 'Basketball', 'Red apple', 'Banana', 'Rocket', 'Bicycle', 'Guitar', 'Drum',
  'Soccer ball', 'Balloon', 'Books', 'Scissors', 'Key', 'Light bulb', 'Glasses', 'Backpack', 'Billed cap', 'Socks', 'Yo-yo', 'Magnet', 'Pencil',
  'Hammer', 'Wrench', 'Paintbrush', 'Bell', 'Candle', 'Teapot', 'Cupcake', 'Lollipop', 'Doughnut', 'Watermelon', 'Grapes', 'Carrot', 'Pear',
  'Snail', 'Butterfly', 'Turtle', 'Octopus', 'Duck', 'Penguin', 'Owl', 'Frog', 'Fish', 'Crab', 'Spiral shell', 'Sunflower', 'Tulip', 'Rose',
  'Mushroom', 'Cactus', 'Crown', 'Ribbon', 'Wrapped gift', 'Game die', 'Puzzle piece', 'Joystick', 'Trumpet', 'Violin', 'Telephone', 'Camera', 'Laptop'];
export async function hidden(box, opts) {
  const lv = opts.level || 0, th = theme(lv), kid = kidOf(opts);
  const nItems = Math.round(ramp(lv, 14, 46)), nFind = Math.min(6, 3 + Math.floor(lv / 15));
  const pool = shuffle([...FIND]).slice(0, nItems), find = pool.slice(0, nFind);
  const SH = await sheets([kid, 'items']);
  await loadAll([...pool, 'Coin', 'Magnifying glass tilted left', th.sun]);
  const {cv, ctx, W, H} = canvasIn(box);
  const S = Math.min(W, H), F = fx(), bot = opts.bot;
  const top = W < 640 ? 112 : 70, trayH = Math.min(110, H * .13), A = {x: 14, y: top, w: W - 28, h: H - top - trayH - 20};
  const sz = Math.sqrt(A.w * A.h / nItems) * ramp(lv, .72, .5);
  // Rải đồ vật: thử nhiều vị trí, tránh chồng nhau quá nhiều (cấp cao cho chồng nhiều hơn).
  const items = [], minD = sz * ramp(lv, .95, .6);
  for (const k of pool) {
    let best = null;
    for (let tries = 0; tries < 40; tries++) {
      const p = {x: A.x + sz / 2 + Math.random() * (A.w - sz), y: A.y + sz / 2 + Math.random() * (A.h - sz)};
      const d = Math.min(...items.map(o => Math.hypot(o.x - p.x, o.y - p.y)), 1e9);
      if (!best || d > best.d) best = {...p, d};
      if (d > minD) break;
    }
    items.push({k, x: best.x, y: best.y, s: sz * rand(.8, 1.15), r: lv >= 10 ? rand(-.6, .6) : rand(-.15, .15), found: false, wig: 0});
  }
  // Món cần tìm vẽ trước để có thể bị che một phần ở cấp cao.
  items.sort((a, b) => (find.includes(b.k) ? 1 : 0) - (find.includes(a.k) ? 1 : 0));
  const bushes = lv >= 20 ? Array.from({length: Math.round(ramp(lv, 3, 8))}, () => ({x: A.x + Math.random() * A.w, y: A.y + Math.random() * A.h, s: sz * rand(.8, 1.2)})) : [];
  let time = Math.round(ramp(lv, 75, 60)), t = 0, end = null, endT = 0, gotN = 0, idle = 0, cheer = 0, botT = 0, miss = 0;
  const tap = (x, y) => {
    const hitIt = [...items].reverse().find(o => !o.found && Math.hypot(o.x - x, o.y - y) < o.s * .5);
    if (hitIt && find.includes(hitIt.k)) {
      hitIt.found = true; gotN++; idle = 0; cheer = 1; sfx('correct'); F.burst(hitIt.x, hitIt.y, 16); F.star(hitIt.x, hitIt.y);
      if (gotN >= nFind) { end = {win: true, score: gotN * 10 + Math.round(time)}; sfx('win'); }
    } else { time = Math.max(0, time - 3); miss++; sfx('wrong'); F.text(x, y, '-3 giây', '#ff8787'); }
  };
  taps(cv, {onTap: (x, y) => { if (t >= 2 && !end) tap(x, y); }});
  return loop({
    update(dt) {
      t += dt; F.update(dt); cheer = Math.max(0, cheer - dt);
      if (end) { endT += dt; return endT > 2 ? end : null; }
      if (t < 2) return null;
      time -= dt; idle += dt;
      for (const o of items) o.wig = idle > 14 && !o.found && find.includes(o.k) ? Math.sin(t * 12) * .25 : 0;  // gợi ý: món cần tìm lắc nhẹ
      if (bot && (botT += dt) > 1) { botT = 0; const o = items.find(o => !o.found && find.includes(o.k)); if (o) tap(o.x, o.y); }
      if (time <= 0 && !end) { time = 0; end = {win: false, score: gotN * 10}; sfx('wrong'); }
      return null;
    },
    draw() {
      skyFill(ctx, W, H, th);
      ctx.fillStyle = 'rgba(255,255,255,.55)'; roundRect(ctx, A.x, A.y, A.w, A.h, 22); ctx.fill();
      ctx.fillStyle = 'rgba(0,0,0,.04)'; for (let y = A.y + 30; y < A.y + A.h; y += 60) ctx.fillRect(A.x, y, A.w, 30);
      for (const o of items) if (!o.found) draw(ctx, o.k, o.x, o.y, o.s, o.s, {rot: o.r + o.wig});
      for (const b of bushes) drawFrame(ctx, SH.items, 'bush', b.x, b.y, b.s * .8, {alpha: .92});
      // Khay: món cần tìm
      const ty = H - trayH - 8, slot = Math.min(trayH, (W - 150) / nFind);
      ctx.fillStyle = 'rgba(0,0,0,.25)'; roundRect(ctx, 10, ty, W - 20, trayH, 20); ctx.fill();
      find.forEach((k, i) => {
        const x = 20 + (i + .5) * slot, done = items.some(o => o.k === k && o.found);
        ctx.fillStyle = done ? 'rgba(64,192,87,.85)' : 'rgba(255,255,255,.9)'; roundRect(ctx, x - slot * .45, ty + 8, slot * .9, trayH - 16, 14); ctx.fill();
        draw(ctx, k, x, ty + trayH / 2, Math.min(slot, trayH) * .62, undefined, {alpha: done ? .5 : 1});
        if (done) { ctx.fillStyle = '#fff'; ctx.font = '800 28px "Baloo 2", sans-serif'; ctx.textAlign = 'center'; ctx.fillText('✔', x + slot * .28, ty + 34); }
      });
      const kh = Math.min(trayH * 1.25, S * .2);
      drawAnim(ctx, SH[kid], end?.win || cheer > 0 ? 'cheer' : 'think', t, W - 60, H - 8, kh);
      F.draw(ctx);
      hud(ctx, W, {score: gotN, lives: 0, time});
      if (t < 2) levelBanner(ctx, W, H, lv, `Tìm ${nFind} món đồ ở khay dưới`, 'Nhìn kỹ rồi chạm vào món đồ · Chạm sai trừ 3 giây');
      if (end) banner(ctx, W, H, end.win ? endText(true, lv) : 'HẾT GIỜ!', `${gotN}/${nFind} món`);
    }
  }, opts.alive);
}
