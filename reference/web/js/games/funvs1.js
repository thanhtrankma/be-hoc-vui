// Game đối kháng (đợt 12): chọn "Đấu với máy" (60 cấp, máy giỏi dần) hoặc "Hai người" chung một màn hình
// (bên trái / dưới là bé - xanh, bên phải / trên là đối thủ - đỏ; chạm nhiều ngón cùng lúc).
// Lõi chung: chọn chế độ, cảm ứng nhiều ngón, nút bấm trên canvas. Game: Võ đài, Khúc côn cầu, Kéo co, Bóng đá, Bóng chuyền.
// Đợt 15 (chuyển động): quán tính, đòn có khung lấy đà/ra đòn/thu về, bật lùi, dừng hình + rung màn khi trúng,
// số sát thương nảy, bụi chân, bóng có xoáy/dẹt khi nảy/bóng đổ, lưới gôn rung, cảnh nền vẽ sẵn (motionb.js).
import {sfx} from '../audio.js?v=4c51d34a6e';
import {h} from '../ui.js?v=4c51d34a6e';
import {banner, canvasIn, draw, endText, levelBanner, loadAll, loop, rand, ramp, roundRect, theme, themeImgs} from './funcore.js?v=4c51d34a6e';
import {BOT, DAD, FRIENDS, drawFigure, drawHead, heroOf} from './figure.js?v=4c51d34a6e';
import {E, approach, camera, fxb, prerender, shadow} from './motionb.js?v=4c51d34a6e';

export const BLUE = '#339af0', RED = '#fa5252';

// ---------- Lõi ----------
function chooseMode(box, opts, title) {
  if (opts.vs) return Promise.resolve(opts.vs);
  return new Promise(resolve => {
    const pickM = m => { sfx('power'); wrap.remove(); opts.vs = m; resolve(m); };
    const wrap = h('div', {class: 'vspick'}, h('h2', {}, title),
      h('div', {class: 'vsmodes'},
        h('button', {class: 'vsmode vs-bot', onclick: () => pickM('bot')}, h('span', {class: 'vsico'}, '🤖'), h('b', {}, 'Đấu với máy'), h('span', {}, `Cấp ${(opts.level || 0) + 1}`)),
        h('button', {class: 'vsmode vs-pvp', onclick: () => pickM('pvp')}, h('span', {class: 'vsico'}, '👨‍👦'), h('b', {}, 'Hai người'), h('span', {}, 'Bố mẹ và bé cùng chơi'))));
    box.append(wrap);
  });
}
// Bọc game đối kháng: run(box, opts, mode) trả {winner: 1|2|0, score}.
export const versus = (title, run) => async (box, opts) => {
  const mode = await chooseMode(box, opts, title);
  if (!opts.alive()) return null;
  const r = await run(box, opts, mode);
  if (!r) return null;
  if (mode === 'pvp') return {pvp: true, score: 0, win: false, title: r.winner === 1 ? '🏆 Bên XANH thắng!' : r.winner === 2 ? '🏆 Bên ĐỎ thắng!' : '🤝 Hoà!'};
  return {win: r.winner === 1, score: r.score || 0};
};
export const p2img = mode => mode === 'pvp' ? 'Man' : 'Robot';
// Nhân vật: bé mặc theo linh vật, đối thủ là robot đỏ (máy) hoặc bố mẹ (áo đỏ)
export const vsCos = (opts, mode) => [heroOf(opts.hero), mode === 'pvp' ? DAD : BOT];
// Tư thế theo chuyển động: nhảy khi trên không, chạy khi đang di chuyển
export const movePose = (p, ground) => { const mv = Math.abs(p.x - (p.lx ?? p.x)) > .3; p.lx = p.x; return p.y < ground - 2 ? 'jump' : mv ? 'run' : 'idle'; };

// Cảm ứng nhiều ngón: mỗi ngón một điểm {x, y, sx, sy}.
export function multi(cv) {
  const pts = new Map(), hs = {down: [], move: [], up: []};
  const loc = e => { const r = cv.getBoundingClientRect(); return [e.clientX - r.left, e.clientY - r.top]; };
  cv.style.touchAction = 'none';
  cv.addEventListener('pointerdown', e => { try { cv.setPointerCapture(e.pointerId); } catch (_) { /* bỏ qua */ } const [x, y] = loc(e); const p = {id: e.pointerId, x, y, sx: x, sy: y}; pts.set(e.pointerId, p); hs.down.forEach(f => f(p)); });
  cv.addEventListener('pointermove', e => { const p = pts.get(e.pointerId); if (!p) return; [p.x, p.y] = loc(e); hs.move.forEach(f => f(p)); });
  const up = e => { const p = pts.get(e.pointerId); if (!p) return; pts.delete(e.pointerId); hs.up.forEach(f => f(p)); };
  cv.addEventListener('pointerup', up); cv.addEventListener('pointercancel', up);
  return {pts, on: (t, f) => hs[t].push(f)};
}
// Nút tròn trên canvas: down(id) đang giữ, hit(id) vừa bấm (một lần). Nút lún xuống khi giữ.
export function buttons(M, list) {
  const hits = new Set();
  M.on('down', p => { for (const b of list) if (!b.hidden && Math.hypot(p.x - b.x, p.y - b.y) < b.r * 1.15) { hits.add(b.id); p.btn = b.id; b.pressT = .18; } });
  return {
    list,
    down: id => [...M.pts.values()].some(p => { const b = list.find(q => q.id === id); return b && Math.hypot(p.x - b.x, p.y - b.y) < b.r * 1.25; }),
    hit: id => { const v = hits.has(id); hits.delete(id); return v; },
    draw(ctx) {
      for (const b of list) {
        if (b.hidden) continue;
        const on = this.down(b.id), r = b.r * (on ? .92 : 1);
        ctx.fillStyle = 'rgba(0,0,0,.18)'; ctx.beginPath(); ctx.arc(b.x, b.y + (on ? 2 : 5), r, 0, 7); ctx.fill();
        ctx.fillStyle = on ? (b.c || '#ffd43b') : 'rgba(255,255,255,.8)'; ctx.beginPath(); ctx.arc(b.x, b.y + (on ? 2 : 0), r, 0, 7); ctx.fill();
        ctx.strokeStyle = b.c || '#fff'; ctx.lineWidth = 4; ctx.stroke();
        ctx.fillStyle = '#212529'; ctx.textAlign = 'center'; ctx.font = `800 ${r * .9}px "Baloo 2", sans-serif`; ctx.fillText(b.label, b.x, b.y + (on ? 2 : 0) + r * .32);
      }
    }
  };
}
// Bảng điểm hai bên; pops = [0..1, 0..1] làm số vừa đổi nảy to lên
export function scoreBar(ctx, W, a, b, need, img1, img2, pops) {
  ctx.fillStyle = 'rgba(0,0,0,.35)'; roundRect(ctx, W / 2 - 120, 8, 240, 54, 27); ctx.fill();
  for (const [im, x] of [[img1, W / 2 - 92], [img2, W / 2 + 92]]) typeof im === 'string' ? draw(ctx, im, x, 35, 40) : drawHead(ctx, x, 37, 16, im, {face: x < W / 2 ? 1 : -1});
  ctx.textAlign = 'center';
  const num = (v, x, c, k) => { ctx.font = `800 ${Math.round(34 * (1 + E.bump(k || 0) * .6))}px "Baloo 2", sans-serif`; ctx.fillStyle = c; ctx.fillText(v, x, 47); };
  num(a, W / 2 - 34, '#74c0fc', pops?.[0]); ctx.font = '800 34px "Baloo 2", sans-serif'; ctx.fillStyle = '#fff'; ctx.fillText(':', W / 2, 45); num(b, W / 2 + 34, '#ff8787', pops?.[1]);
  if (need) { ctx.font = '700 16px "Baloo 2", sans-serif'; const tx = `Ai ${need} điểm trước thì thắng`; ctx.lineWidth = 4; ctx.strokeStyle = 'rgba(0,0,0,.55)'; ctx.lineJoin = 'round'; ctx.strokeText(tx, W / 2, 78); ctx.fillStyle = '#fff'; ctx.fillText(tx, W / 2, 78); }
}
export function vsIntro(ctx, W, H, lv, mode, goal, hint) {
  if (mode === 'pvp') { ctx.fillStyle = 'rgba(0,0,0,.4)'; ctx.fillRect(0, H / 2 - 80, W, 160); ctx.textAlign = 'center'; ctx.fillStyle = '#ffd43b'; ctx.font = '800 44px "Baloo 2", sans-serif'; ctx.fillText('HAI NGƯỜI', W / 2, H / 2 - 18); ctx.fillStyle = '#fff'; ctx.font = '700 22px "Baloo 2", sans-serif'; ctx.fillText(`🎯 ${goal}`, W / 2, H / 2 + 18); ctx.font = '600 17px "Baloo 2", sans-serif'; ctx.fillText(hint, W / 2, H / 2 + 50); }
  else levelBanner(ctx, W, H, lv, goal, hint);
}
export const endVs = (ctx, W, H, winner, mode, lv, sub) => banner(ctx, W, H,
  mode === 'pvp' ? (winner === 1 ? 'XANH THẮNG!' : winner === 2 ? 'ĐỎ THẮNG!' : 'HOÀ!') : winner === 1 ? endText(true, lv) : winner === 2 ? 'MÁY THẮNG RỒI!' : 'HOÀ!', sub);
function sky(ctx, W, H, th) { const g = ctx.createLinearGradient(0, 0, 0, H); g.addColorStop(0, th.sky[0]); g.addColorStop(1, th.sky[1]); ctx.fillStyle = g; ctx.fillRect(0, 0, W, H); }
// Mây trôi (nền động nhẹ)
function clouds(ctx, W, H, t, n = 4, y0 = .08) {
  ctx.fillStyle = 'rgba(255,255,255,.75)';
  for (let i = 0; i < n; i++) {
    const x = ((i * W / n + t * (10 + i * 4)) % (W + 200)) - 100, y = H * (y0 + (i % 3) * .05), s = 26 + (i % 2) * 12;
    ctx.beginPath(); ctx.arc(x, y, s, 0, 7); ctx.arc(x + s, y - s * .4, s * .9, 0, 7); ctx.arc(x + s * 2, y, s * .8, 0, 7); ctx.fill();
  }
}
const pulseDecay = (arr, dt, k = 2.5) => { for (let i = 0; i < arr.length; i++) arr[i] = Math.max(0, arr[i] - dt * k); };

// ---------- 1. Võ đài: đi, nhảy, đấm, đỡ đòn; hết máu là thua ----------
// Đòn đấm 3 khung: lấy đà (.09s) -> ra đòn (tới .2s, xét trúng ở đầu khung) -> thu về (tới .36s).
export const fighter = versus('🥊 Võ đài', async (box, opts, mode) => {
  const lv = opts.level || 0, th = theme(lv);
  await loadAll(['Shield', 'Glowing star', ...themeImgs(lv)]);
  const {cv, ctx, W, H} = canvasIn(box);
  const S = Math.min(W, H), F = fxb(), C = camera(), ground = H * .68, M = multi(cv);
  const mk = (x, f) => ({x, y: ground, vx: 0, kb: 0, vy: 0, f, hp: 100, shp: 100, cd: 0, atk: -1, hitDone: false, block: false, hurt: 0, w: S * .2, air: false, ko: false});
  const P = [mk(W * .25, 1), mk(W * .75, -1)], COS = vsCos(opts, mode);
  const r = Math.min(56, S * .085, mode === 'pvp' ? (W / 2 - 24) / 6.8 : 99), by = H - r - 16;  // hai người trên màn hẹp: thu nhỏ nút cho khỏi chồng nhau
  const B = buttons(M, [
    {id: 'l1', x: r + 14, y: by, r, label: '◀'}, {id: 'r1', x: r * 3.4 + 14, y: by, r, label: '▶'},
    {id: 'j1', x: r * 5.8 + 14, y: by, r, label: '⬆', c: BLUE}, {id: 'p1', x: r * 2.2 + 14, y: by - r * 2.2, r, label: '👊', c: BLUE}, {id: 'b1', x: r * 4.6 + 14, y: by - r * 2.2, r, label: '🛡', c: BLUE},
    ...(mode === 'pvp' ? [{id: 'l2', x: W - r * 3.4 - 14, y: by, r, label: '◀'}, {id: 'r2', x: W - r - 14, y: by, r, label: '▶'},
      {id: 'j2', x: W - r * 5.8 - 14, y: by, r, label: '⬆', c: RED}, {id: 'p2', x: W - r * 4.6 - 14, y: by - r * 2.2, r, label: '👊', c: RED}, {id: 'b2', x: W - r * 2.2 - 14, y: by - r * 2.2, r, label: '🛡', c: RED}] : [])]);
  const WIND = .09, STRIKE = .2, END = .36;
  // Nền vẽ sẵn: trời, cảnh, sàn võ đài có cột và dây
  const bg = prerender(W, H, g => {
    sky(g, W, H, th);
    th.deco.slice(0, 2).forEach((d, i) => draw(g, d, W * (i ? .88 : .12), ground - S * .14, S * .26, S * .26, {alpha: .6}));
    g.fillStyle = th.ground; g.fillRect(0, ground, W, H - ground);
    g.fillStyle = '#c08552'; roundRect(g, W * .04, ground - 6, W * .92, 18, 8); g.fill();
    g.fillStyle = '#a0522d'; g.fillRect(W * .04, ground + 10, W * .92, 10);
    for (const x of [W * .05, W * .95]) { g.fillStyle = '#495057'; g.fillRect(x - 6, ground - S * .32, 12, S * .32); g.fillStyle = '#e03131'; g.fillRect(x - 8, ground - S * .34, 16, 14); }
    ['#fff', '#fa5252', '#fff'].forEach((c, i) => { g.strokeStyle = c; g.lineWidth = 4; g.beginPath(); g.moveTo(W * .05, ground - S * (.1 + i * .08)); g.quadraticCurveTo(W / 2, ground - S * (.08 + i * .08), W * .95, ground - S * (.1 + i * .08)); g.stroke(); });
  });
  let t = 0, end = null, endT = 0, winner = 0, ai = {think: 0, act: null};
  const react = ramp(lv, .55, .14), blockP = ramp(lv, .1, .6), dmgBot = Math.round(ramp(lv, 7, 13));
  const physics = (p, k, dt) => {
    p.kb = approach(p.kb, 0, 5, dt);
    p.x += (p.vx + p.kb) * dt;
    p.vy += S * 4 * dt; p.y += p.vy * dt;
    if (p.y >= ground) { if (p.air && p.vy > S * .5) { F.dust(p.x, ground, 6); C.shake(p.ko ? 6 : 1.5); } p.y = ground; p.vy = 0; p.air = false; } else p.air = true;
    if (p.x < p.w / 2) { p.x = p.w / 2; if (p.kb < -S * .3) { p.kb = -p.kb * .4; F.ring(p.x, p.y - p.w * .6, 30, '#fff', 4); C.shake(2); } }
    if (p.x > W - p.w / 2) { p.x = W - p.w / 2; if (p.kb > S * .3) { p.kb = -p.kb * .4; F.ring(p.x, p.y - p.w * .6, 30, '#fff', 4); C.shake(2); } }
  };
  const tryHit = (p, k) => {
    const o = P[1 - k];
    if (!(Math.abs(o.x - p.x) < p.w * 1.1 && Math.abs(o.y - p.y) < p.w * .7)) { sfx('tap'); return; }
    const hx = (p.x + o.x) / 2 + p.f * p.w * .15, hy = o.y - o.w * .75;
    if (o.block && o.f === -p.f) { sfx('pop'); F.text(o.x, o.y - o.w * 1.15, 'ĐỠ!', '#74c0fc', 26); F.ring(hx, hy, 34, '#74c0fc', 6); F.sparks(hx, hy, 5, '#d0ebff', p.f > 0 ? Math.PI : 0); o.kb += p.f * S * .35; C.shake(2); return; }
    const dmg = (k === 1 && mode === 'bot') ? dmgBot : 10, crit = !o.air && p.air;
    const d = crit ? Math.round(dmg * 1.4) : dmg;
    o.hp = Math.max(0, o.hp - d); o.hurt = .32; o.kb += p.f * S * (crit ? 1.5 : 1.05); if (o.air || crit) o.vy = Math.min(o.vy, -S * .55);
    o.atk = -1;  // trúng đòn thì đòn đang ra bị huỷ
    sfx('hit'); C.stop(crit ? .1 : .065); C.shake(crit ? 9 : 6);
    F.sparks(hx, hy, 10, '#fff3bf', p.f > 0 ? 0 : Math.PI); F.ring(hx, hy, 36, '#ffe066', 6); F.burst(hx, hy, 6, ['#fff', '#ffd43b']);
    F.num(o.x, o.y - o.w * 1.15, '-' + d, {crit, c: '#ff6b6b'});
  };
  const control = (p, k, inp, dt) => {
    p.cd = Math.max(0, p.cd - dt); p.hurt = Math.max(0, p.hurt - dt);
    p.block = !!inp.block && !p.air && p.atk < 0 && p.hurt <= 0;
    const dir = (inp.r ? 1 : 0) - (inp.l ? 1 : 0), lock = p.block || p.hurt > .15 || (p.atk >= 0 && !p.air);
    p.vx = approach(p.vx, lock ? 0 : dir * S * .58, p.air ? 3 : 14, dt);
    if (inp.j && !p.air && p.hurt <= 0) { p.vy = -S * 1.6; p.air = true; sfx('jump'); F.dust(p.x, ground, 5); }
    const o = P[1 - k]; if (p.atk < 0 && p.hurt <= 0) p.f = o.x > p.x ? 1 : -1;
    if (inp.p && p.cd <= 0 && !p.block && p.atk < 0 && p.hurt <= 0) { p.cd = .42; p.atk = 0; p.hitDone = false; sfx('flip'); }
    if (p.atk >= 0) {
      p.atk += dt;
      if (!p.hitDone && p.atk >= WIND) { p.hitDone = true; p.kb += p.f * S * .25; tryHit(p, k); }
      if (p.atk >= END) p.atk = -1;
    }
    physics(p, k, dt);
  };
  return loop({
    update(rdt) {
      t += rdt; C.update(rdt);
      const dt = rdt * C.scale(rdt);
      F.update(dt);
      for (const p of P) p.shp = approach(p.shp, p.hp, 4, rdt);
      if (end) {
        endT += rdt;
        for (const [k, p] of P.entries()) { p.vx = approach(p.vx, 0, 6, dt); p.hurt = Math.max(0, p.hurt - dt); physics(p, k, dt); }
        return endT > 2.4 ? end : null;
      }
      if (t < 2.4) return null;
      control(P[0], 0, {l: B.down('l1'), r: B.down('r1'), j: B.hit('j1'), p: B.hit('p1'), block: B.down('b1')}, dt);
      if (mode === 'pvp') control(P[1], 1, {l: B.down('l2'), r: B.down('r2'), j: B.hit('j2'), p: B.hit('p2'), block: B.down('b2')}, dt);
      else {
        // Máy: tiến lại gần, đấm khi tới tầm (có độ trễ phản xạ), đỡ khi bé lấy đà đấm
        const me = P[1], o = P[0], d = Math.abs(o.x - me.x);
        ai.think -= dt;
        if (ai.think <= 0) { ai.think = react * rand(.7, 1.3); ai.act = {l: false, r: false, j: false, p: false, block: false}; if (d > me.w * .9) ai.act[o.x < me.x ? 'l' : 'r'] = true; else if (Math.random() < .7) ai.act.p = true; else ai.act[o.x < me.x ? 'r' : 'l'] = true; if (o.atk >= 0 && Math.random() < blockP) ai.act.block = true; if (Math.random() < .06) ai.act.j = true; }
        const a = ai.act || {}; control(me, 1, {...a, p: a.p && Math.random() < .5}, dt);
      }
      for (const [k, p] of P.entries()) if (p.hp <= 0 && !end) {
        winner = 2 - k; end = {winner, score: P[0].hp}; p.ko = true; p.hurt = 3; p.vy = -S * 1.1; p.kb = (k ? 1 : -1) * S * 1.6;
        sfx(winner === 1 ? 'win' : 'pop'); C.stop(.3); C.shake(14); F.burst(p.x, p.y - p.w / 2, 30); F.text(W / 2, H * .3, 'K.O.!', '#ffd43b', 56);
      }
      return null;
    },
    draw() {
      ctx.drawImage(bg, 0, 0, W, H);
      clouds(ctx, W, H, t, 3);
      draw(ctx, th.sun, W * .5, H * .16 + Math.sin(t * .8) * 4, S * .14);
      C.begin(ctx);
      for (const [k, p] of P.entries()) {
        let pose = 'idle', act = 0, lean = 0;
        if (end && !p.ko) pose = 'cheer';
        else if (p.hurt > 0) pose = 'hurt';
        else if (p.block) pose = 'block';
        else if (p.atk >= 0) { pose = 'punch'; act = p.atk < WIND ? .05 : p.atk < STRIKE ? .5 * E.outCubic((p.atk - WIND) / (STRIKE - WIND)) : .5 + .5 * (p.atk - STRIKE) / (END - STRIKE); if (p.atk < WIND) lean = -p.f * p.w * .06 * E.outCubic(p.atk / WIND); }
        else if (p.air) pose = 'jump';
        else if (Math.abs(p.vx) > 25) pose = 'run';
        const flash = p.hurt > 0 && p.hurt < .32 && Math.floor(p.hurt * 30) % 2 ? .55 : 1;
        drawFigure(ctx, p.x + lean, p.y, p.w * 1.3, {c: COS[k], pose, t: t + k, act, face: p.f, team: k ? RED : BLUE, alpha: flash});
        if (p.block) draw(ctx, 'Shield', p.x + p.f * p.w * .45, p.y - p.w * .7, p.w * .42, p.w * .42, {alpha: .85});
      }
      F.draw(ctx);
      C.end(ctx);
      // Thanh máu: phần vừa mất hiện trắng rồi rút dần
      for (const [k, p] of P.entries()) {
        const bw = Math.min(260, W * .36), bx = k ? W - bw - 20 : 20, sh = Math.max(p.hp, p.shp);
        ctx.fillStyle = 'rgba(0,0,0,.35)'; roundRect(ctx, bx, 70, bw, 22, 11); ctx.fill();
        ctx.fillStyle = '#fff'; roundRect(ctx, k ? bx + bw * (1 - sh / 100) : bx, 70, bw * sh / 100, 22, 11); ctx.fill();
        if (p.hp > 0) { ctx.fillStyle = k ? RED : BLUE; roundRect(ctx, k ? bx + bw * (1 - p.hp / 100) : bx, 70, bw * p.hp / 100, 22, 11); ctx.fill(); }
        drawHead(ctx, k ? bx + bw + 4 - 34 : bx + 14, 60, 15, COS[k], {face: k ? -1 : 1, hurt: p.hurt > 0});
      }
      B.draw(ctx);
      if (t < 2.4) vsIntro(ctx, W, H, lv, mode, 'Đánh hết máu đối thủ', '◀ ▶ đi · ⬆ nhảy · 👊 đấm · 🛡 giữ để đỡ');
      if (end && endT > .6) endVs(ctx, W, H, winner, mode, lv, '');
    }
  }, opts.alive);
});

// ---------- 2. Khúc côn cầu: kéo vợt trong nửa sân của mình, đánh bóng vào gôn đối thủ ----------
export const hockey = versus('🏒 Khúc côn cầu', async (box, opts, mode) => {
  const lv = opts.level || 0, need = 5;
  await loadAll(['Glowing star']);
  const COS = vsCos(opts, mode);
  const {cv, ctx, W, H} = canvasIn(box);
  const F = fxb(), C = camera(), M = multi(cv), top = 90, L = 16, Rr = W - 16, B = H - 16;
  const S = Math.min(W, H), mr = S * .07, pr = S * .04, goalH = (B - top) * .36, cyy = (top + B) / 2;
  const mal = [{x: W * .2, y: cyy, vx: 0, vy: 0, tx: W * .2, ty: cyy}, {x: W * .8, y: cyy, vx: 0, vy: 0, tx: W * .8, ty: cyy}];
  const trail = Array.from({length: 12}, () => [0, 0]); let ti = 0;
  let puck, a = 0, b = 0, t = 0, end = null, endT = 0, winner = 0, pause = 0;
  const pops = [0, 0], goalFlash = [0, 0];
  const serve = side => { puck = {x: side === 1 ? W * .38 : W * .62, y: cyy, vx: 0, vy: 0, rot: 0, born: 0}; pause = .8; trail.forEach(p => { p[0] = puck.x; p[1] = puck.y; }); };
  serve(1);
  M.on('down', p => { p.side = p.x < W / 2 ? 0 : 1; });
  const aiSp = S * ramp(lv, 1.2, 3.2), aiSkill = ramp(lv, .3, .95);
  // Sân băng vẽ sẵn
  const rink = prerender(W, H, g => {
    g.fillStyle = '#d0ebff'; g.fillRect(0, 0, W, H);
    const ig = g.createLinearGradient(0, top, 0, B); ig.addColorStop(0, '#ffffff'); ig.addColorStop(1, '#e7f5ff');
    g.fillStyle = ig; roundRect(g, L, top, Rr - L, B - top, 40); g.fill();
    g.save(); roundRect(g, L, top, Rr - L, B - top, 40); g.clip();
    g.strokeStyle = 'rgba(116,192,252,.18)'; g.lineWidth = 1.5;
    for (let i = 0; i < 60; i++) { const x = (i * 157) % W, y = top + (i * 89) % (B - top), l = 20 + (i % 5) * 12, an = (i % 7) * .4; g.beginPath(); g.moveTo(x, y); g.lineTo(x + Math.cos(an) * l, y + Math.sin(an) * l); g.stroke(); }
    g.restore();
    g.strokeStyle = '#74c0fc'; g.lineWidth = 8; roundRect(g, L, top, Rr - L, B - top, 40); g.stroke();
    g.strokeStyle = '#ff8787'; g.lineWidth = 5; g.beginPath(); g.moveTo(W / 2, top); g.lineTo(W / 2, B); g.stroke();
    g.beginPath(); g.arc(W / 2, cyy, S * .12, 0, 7); g.stroke();
    g.fillStyle = '#ff8787'; g.beginPath(); g.arc(W / 2, cyy, 8, 0, 7); g.fill();
    for (const [x, s, c] of [[L, 1, BLUE], [Rr, -1, RED]]) { g.fillStyle = c + '22'; g.strokeStyle = c; g.lineWidth = 3; g.beginPath(); g.arc(x, cyy, goalH * .42, -Math.PI / 2, Math.PI / 2, s < 0); g.fill(); g.stroke(); }
  });
  const goal = side => {
    if (side === 2) { b++; pops[1] = 1; sfx('wrong'); F.text(W / 2, H / 2, mode === 'pvp' ? 'ĐỎ GHI BÀN!' : 'MÁY GHI BÀN!', '#ff8787', 40); goalFlash[0] = 1; F.burst(L, cyy, 24, ['#fff', '#74c0fc', '#ff8787']); serve(1); }
    else { a++; pops[0] = 1; sfx('win'); F.burst(Rr, cyy, 34); F.text(W / 2, H / 2, 'VÀO!', '#ffd43b', 46); goalFlash[1] = 1; serve(2); }
    C.shake(10); C.stop(.12);
  };
  return loop({
    update(rdt) {
      t += rdt; C.update(rdt); const dt = rdt * C.scale(rdt); F.update(dt); pulseDecay(pops, rdt); pulseDecay(goalFlash, rdt, 1.5);
      if (end) { endT += rdt; return endT > 2.2 ? end : null; }
      if (t < 2.4) return null;
      for (const p of M.pts.values()) { if (p.side === 0) { mal[0].tx = p.x; mal[0].ty = p.y; } else if (mode === 'pvp') { mal[1].tx = p.x; mal[1].ty = p.y; } }
      if (mode === 'bot') {
        const m = mal[1];
        let tx, ty;
        if (puck.x > W / 2) { tx = puck.x + pr * 1.5 * aiSkill; ty = puck.y + (puck.y - cyy) * .2; }
        else { tx = Rr - mr * 3; ty = cyy + (puck.y - cyy) * .5 * aiSkill; }
        const dx = tx - m.x, dy = ty - m.y, d = Math.hypot(dx, dy), st = Math.min(d, aiSp * dt * 1.6);
        if (d > 1) { m.tx = m.x + dx / d * st; m.ty = m.y + dy / d * st; } else { m.tx = tx; m.ty = ty; }
      }
      for (const [k, m] of mal.entries()) {
        const minX = k ? W / 2 + mr : L + mr, maxX = k ? Rr - mr : W / 2 - mr;
        const gx = Math.max(minX, Math.min(maxX, m.tx)), gy = Math.max(top + mr, Math.min(B - mr, m.ty));
        // Vợt bám theo ngón tay có quán tính nhẹ (mượt, không giật)
        const nx = approach(m.x, gx, 30, dt), ny = approach(m.y, gy, 30, dt);
        m.vx = (nx - m.x) / Math.max(dt, .001); m.vy = (ny - m.y) / Math.max(dt, .001); m.x = nx; m.y = ny;
        const dx = puck.x - m.x, dy = puck.y - m.y, d = Math.hypot(dx, dy);
        if (d < mr + pr && d > 0) {
          const nx2 = dx / d, ny2 = dy / d;
          puck.x = m.x + nx2 * (mr + pr); puck.y = m.y + ny2 * (mr + pr);
          const rel = (puck.vx - m.vx) * nx2 + (puck.vy - m.vy) * ny2;
          if (rel < 0) {
            puck.vx -= 1.9 * rel * nx2; puck.vy -= 1.9 * rel * ny2; sfx('tap');
            const pw = Math.min(1, -rel / (S * 2)); F.ring(m.x + nx2 * mr, m.y + ny2 * mr, 20 + pw * 30, k ? '#ffc9c9' : '#d0ebff', 5); if (pw > .4) { F.sparks(puck.x, puck.y, 6, '#fff', Math.atan2(ny2, nx2)); C.shake(pw * 4); }
          }
          const sp = Math.hypot(puck.vx, puck.vy), mx = S * 3.2; if (sp > mx) { puck.vx *= mx / sp; puck.vy *= mx / sp; }
        }
      }
      puck.born += dt;
      if (pause > 0) { pause -= dt; return null; }
      puck.x += puck.vx * dt; puck.y += puck.vy * dt; const fr = Math.exp(-dt * .35); puck.vx *= fr; puck.vy *= fr;
      puck.rot += (puck.vx + puck.vy) * dt * .02;
      ti = (ti + 1) % trail.length; trail[ti][0] = puck.x; trail[ti][1] = puck.y;
      const wall = (x, y) => { sfx('pop'); F.ring(x, y, 18, '#a5d8ff', 4); F.sparks(x, y, 4, '#e7f5ff'); };
      if (puck.y < top + pr) { puck.y = top + pr; puck.vy = Math.abs(puck.vy); wall(puck.x, top); }
      if (puck.y > B - pr) { puck.y = B - pr; puck.vy = -Math.abs(puck.vy); wall(puck.x, B); }
      const inGoal = Math.abs(puck.y - cyy) < goalH / 2;
      if (puck.x < L + pr) { if (inGoal) goal(2); else { puck.x = L + pr; puck.vx = Math.abs(puck.vx); wall(L, puck.y); } }
      if (puck.x > Rr - pr) { if (inGoal) goal(1); else { puck.x = Rr - pr; puck.vx = -Math.abs(puck.vx); wall(Rr, puck.y); } }
      if (a >= need || b >= need) { winner = a >= need ? 1 : 2; end = {winner, score: a * 5}; }
      return null;
    },
    draw() {
      C.begin(ctx);
      ctx.drawImage(rink, 0, 0, W, H);
      // Gôn sáng đèn khi có bàn
      for (const [k, x] of [[0, L - 6], [1, Rr - 6]]) {
        ctx.fillStyle = k ? RED : BLUE; ctx.fillRect(x, cyy - goalH / 2, 12, goalH);
        if (goalFlash[k] > 0) { ctx.fillStyle = `rgba(255,224,102,${goalFlash[k] * .6})`; ctx.fillRect(k ? Rr - 80 : L, cyy - goalH / 2 - 20, 80, goalH + 40); }
      }
      // Vệt trượt của bóng
      const sp = Math.hypot(puck.vx, puck.vy);
      if (sp > S * .4) for (let i = 1; i < trail.length; i++) { const p = trail[(ti - i + trail.length * 2) % trail.length], k = 1 - i / trail.length; ctx.fillStyle = `rgba(33,37,41,${k * .18 * Math.min(1, sp / (S * 2))})`; ctx.beginPath(); ctx.arc(p[0], p[1], pr * (.4 + k * .55), 0, 7); ctx.fill(); }
      const ps = pause > 0 ? E.outBack(Math.min(1, puck.born / .45)) : 1;
      shadow(ctx, puck.x + 3, puck.y + pr * .5, pr * 1.05, 0, .2);
      ctx.save(); ctx.translate(puck.x, puck.y); ctx.scale(ps, ps); ctx.rotate(puck.rot);
      ctx.fillStyle = '#212529'; ctx.beginPath(); ctx.arc(0, 0, pr, 0, 7); ctx.fill();
      ctx.fillStyle = '#495057'; ctx.beginPath(); ctx.arc(0, 0, pr * .68, 0, 7); ctx.fill();
      ctx.strokeStyle = '#ffd43b'; ctx.lineWidth = 3; ctx.beginPath(); ctx.arc(0, 0, pr * .45, 0, 2.2); ctx.stroke();
      ctx.restore();
      for (const [k, m] of mal.entries()) {
        const c = k ? RED : BLUE, sp2 = Math.min(1, Math.hypot(m.vx, m.vy) / (S * 3));
        shadow(ctx, m.x + 5, m.y + mr * .55, mr * 1.05, 0, .25);
        const gr = ctx.createRadialGradient(m.x - mr * .3, m.y - mr * .35, mr * .1, m.x, m.y, mr);
        gr.addColorStop(0, k ? '#ffa8a8' : '#a5d8ff'); gr.addColorStop(1, c);
        ctx.fillStyle = gr; ctx.beginPath(); ctx.arc(m.x, m.y, mr * (1 + sp2 * .06), 0, 7); ctx.fill();
        ctx.strokeStyle = 'rgba(0,0,0,.25)'; ctx.lineWidth = 3; ctx.stroke();
        ctx.fillStyle = 'rgba(255,255,255,.3)'; ctx.beginPath(); ctx.arc(m.x, m.y, mr * .7, 0, 7); ctx.fill();
        drawHead(ctx, m.x, m.y - mr * .05, mr * .56, COS[k], {face: k ? -1 : 1, t});
      }
      F.draw(ctx);
      C.end(ctx);
      scoreBar(ctx, W, a, b, need, ...COS, pops);
      if (t < 2.4) vsIntro(ctx, W, H, lv, mode, `Ghi ${need} bàn trước`, 'Kéo vợt trong nửa sân của mình');
      if (end) endVs(ctx, W, H, winner, mode, lv, `${a} : ${b}`);
    }
  }, opts.alive);
});

// ---------- 3. Kéo co: chạm thật nhanh vào nửa màn hình của mình ----------
export const tug = versus('🪢 Kéo co', async (box, opts, mode) => {
  const lv = opts.level || 0, th = theme(lv);
  const COS = vsCos(opts, mode), TEAM1 = [COS[0], FRIENDS[0], FRIENDS[1]], TEAM2 = [COS[1], {...FRIENDS[2], shirt: '#fa5252'}, {...FRIENDS[3], shirt: '#e03131'}];
  await loadAll(['Glowing star', 'Water wave', ...themeImgs(lv)]);
  const {cv, ctx, W, H} = canvasIn(box);
  const S = Math.min(W, H), F = fxb(), C = camera(), M = multi(cv), ground = H * .66;
  let pos = 0, shown = 0, t = 0, end = null, endT = 0, winner = 0, botAcc = 0, wob = 0;
  const taps = [0, 0], pulse = [0, 0];
  const goal = W * .22, botRate = ramp(lv, 3.2, 8.5), sz = S * .15;
  const bg = prerender(W, H, g => {
    sky(g, W, H, th);
    th.deco.slice(0, 3).forEach((d, i) => draw(g, d, W * (.1 + i * .4), ground - S * .12, S * .22, S * .22, {alpha: .55}));
    g.fillStyle = th.ground; g.fillRect(0, ground, W, H - ground);
    g.fillStyle = th.edge || 'rgba(0,0,0,.1)'; g.fillRect(0, ground, W, 8);
    g.fillStyle = '#8d5524'; g.beginPath(); g.ellipse(W / 2, ground + 14, W * .09, 22, 0, 0, 7); g.fill();
    g.fillStyle = '#6f4518'; g.beginPath(); g.ellipse(W / 2, ground + 16, W * .065, 14, 0, 0, 7); g.fill();
    g.strokeStyle = '#fff'; g.lineWidth = 4; g.setLineDash([10, 8]);
    for (const x of [W / 2 - goal, W / 2 + goal]) { g.beginPath(); g.moveTo(x, ground - S * .3); g.lineTo(x, ground + 30); g.stroke(); }
    g.setLineDash([]);
  });
  const pull = side => { pos += side ? 6 : -6; taps[side]++; pulse[side] = .14; wob = Math.min(1, wob + .35); const fx = side ? W / 2 + shown + S * .2 + sz * 1.7 : W / 2 + shown - S * .2 - sz * 1.7; F.dust(fx, ground + sz * .05, 2, side ? 1 : -1, 'rgba(141,85,36,.6)'); };
  M.on('down', p => {
    if (end || t < 2.4) return;
    const side = p.x < W / 2 ? 0 : 1;
    if (side === 1 && mode !== 'pvp') return;
    pull(side); sfx('tap');
  });
  return loop({
    update(dt) {
      t += dt; C.update(dt); F.update(dt); pulseDecay(pulse, dt, 1);
      shown = approach(shown, pos, 9, dt); wob = Math.max(0, wob - dt * 1.6);
      if (end) { endT += dt; return endT > 2.4 ? end : null; }
      if (t < 2.4) return null;
      if (mode === 'bot') { botAcc += dt * botRate * (1 + Math.sin(t * 1.7) * .25); while (botAcc >= 1) { botAcc -= 1; pull(1); } }
      if (pos <= -goal || pos >= goal) { winner = pos < 0 ? 1 : 2; end = {winner, score: taps[0]}; sfx(winner === 1 ? 'win' : 'pop'); F.burst(W / 2, ground + 10, 30, ['#8d5524', '#6f4518', '#a0522d', '#fff']); C.shake(10); }
      return null;
    },
    draw() {
      ctx.drawImage(bg, 0, 0, W, H);
      clouds(ctx, W, H, t, 4);
      draw(ctx, th.sun, W * .5, H * .14, S * .13);
      C.begin(ctx);
      const cx = W / 2 + shown, ry = ground - S * .12;
      // Dây võng xuống và rung khi giật
      const sag = 10 + Math.sin(t * 38) * 9 * wob;
      ctx.strokeStyle = '#a0522d'; ctx.lineWidth = 10; ctx.lineCap = 'round';
      ctx.beginPath(); ctx.moveTo(W * .03, ry + 4); ctx.quadraticCurveTo(cx, ry + sag * 2, W * .97, ry + 4); ctx.stroke();
      ctx.strokeStyle = '#d9a066'; ctx.lineWidth = 3; ctx.setLineDash([6, 8]); ctx.lineDashOffset = -shown; ctx.stroke(); ctx.setLineDash([]);
      // Nơ đỏ giữa dây bay phấp phới
      const ky = ry + sag;
      ctx.fillStyle = '#fa5252'; ctx.beginPath(); ctx.moveTo(cx, ky); ctx.lineTo(cx - 10 + Math.sin(t * 9) * 3, ky + 34); ctx.lineTo(cx + 2, ky + 28); ctx.lineTo(cx + 12 + Math.sin(t * 9 + 1) * 3, ky + 36); ctx.closePath(); ctx.fill();
      ctx.beginPath(); ctx.arc(cx, ky, 8, 0, 7); ctx.fill();
      for (const [side, team] of [[0, TEAM1], [1, TEAM2]]) {
        const dir = side ? 1 : -1, jerk = E.bump(pulse[side] / .14) * S * .025;
        team.forEach((c, i) => {
          const x = cx + dir * (S * .2 + i * sz * .85) + dir * jerk;
          const lose = end && winner !== side + 1, win = end && winner === side + 1;
          const fall = lose ? Math.min(1, endT * 2) : 0;
          drawFigure(ctx, x - dir * fall * S * .15, ground + sz * .05 + fall * 6, sz * 1.25, {c, pose: win ? 'cheer' : lose ? 'hurt' : 'pull', t: t * (pulse[side] ? 2.2 : .6) + i, face: -dir, team: side ? RED : BLUE});
        });
      }
      F.draw(ctx);
      C.end(ctx);
      ctx.fillStyle = 'rgba(51,154,240,.1)'; ctx.fillRect(0, 0, W / 2, H);
      if (mode === 'pvp') { ctx.fillStyle = 'rgba(250,82,82,.1)'; ctx.fillRect(W / 2, 0, W / 2, H); }
      ctx.textAlign = 'center'; ctx.font = `800 ${Math.round(26 * (1 + E.bump(pulse[0] / .14) * .15))}px "Baloo 2", sans-serif`; ctx.fillStyle = '#1971c2'; ctx.fillText('CHẠM THẬT NHANH!', W * .25, H * .9);
      if (mode === 'pvp') { ctx.font = `800 ${Math.round(26 * (1 + E.bump(pulse[1] / .14) * .15))}px "Baloo 2", sans-serif`; ctx.fillStyle = '#c92a2a'; ctx.fillText('CHẠM THẬT NHANH!', W * .75, H * .9); }
      if (t < 2.4) vsIntro(ctx, W, H, lv, mode, 'Kéo dây qua vạch bên mình', 'Chạm liên tục vào nửa màn hình của mình');
      if (end && endT > .5) endVs(ctx, W, H, winner, mode, lv, '');
    }
  }, opts.alive);
});

// Vật lý chung cho Bóng đá, Bóng chuyền: người chơi đi ◀ ▶, nhảy ⬆; bóng nảy có trọng lực.
function sideControls(M, W, H, r, mode) {
  const by = H - r - 14;
  return buttons(M, [
    {id: 'l1', x: r + 14, y: by, r, label: '◀'}, {id: 'r1', x: r * 3.4 + 14, y: by, r, label: '▶'}, {id: 'j1', x: r * 5.8 + 14, y: by, r, label: '⬆', c: BLUE},
    ...(mode === 'pvp' ? [{id: 'l2', x: W - r * 3.4 - 14, y: by, r, label: '◀'}, {id: 'r2', x: W - r - 14, y: by, r, label: '▶'}, {id: 'j2', x: W - r * 5.8 - 14, y: by, r, label: '⬆', c: RED}] : [])]);
}
// Người chơi bóng: tăng tốc/giảm tốc có quán tính, bụi khi chạy đà và tiếp đất
function runner(p, l, r, j, dt, S, ground, G, F, {sp = .62, jump = 1.55} = {}) {
  const dir = (r ? 1 : 0) - (l ? 1 : 0), was = p.vx;
  p.vx = approach(p.vx, dir * S * sp, p.y < ground - 1 ? 4 : 12, dt);
  if (dir && Math.abs(was) < S * .1 && Math.abs(p.vx) >= S * .1) F.dust(p.x, ground, 3, -dir);
  p.x += p.vx * dt;
  if (j && p.y >= ground) { p.vy = -S * jump; sfx('jump'); F.dust(p.x, ground, 4); }
  p.vy += G * dt; p.y += p.vy * dt;
  if (p.y >= ground) { if (p.vy > S * .6) F.dust(p.x, ground, 5); p.y = ground; p.vy = 0; }
}
// Vẽ bóng có xoáy và dẹt khi nảy
function drawBall(ctx, img, ball) {
  const q = ball.sq || 0;
  ctx.save(); ctx.translate(ball.x, ball.y + ball.r * q * .5); ctx.scale(1 + q, 1 - q);
  draw(ctx, img, 0, 0, ball.r * 2, ball.r * 2, {rot: ball.rot});
  ctx.restore();
}
// Bóng va vào đầu/thân người chơi: phản xạ theo pháp tuyến + cộng vận tốc người chơi
function headHit(ball, hx, hy, rr, p, minSp, up, F) {
  const dx = ball.x - hx, dy = ball.y - hy, d = Math.hypot(dx, dy);
  if (d >= rr || d === 0) return false;
  const nx = dx / d, ny = dy / d;
  ball.x = hx + nx * rr; ball.y = hy + ny * rr;
  const rvx = ball.vx - p.vx, rvy = ball.vy - p.vy, rel = rvx * nx + rvy * ny;
  if (rel < 0) { ball.vx -= 1.8 * rel * nx; ball.vy -= 1.8 * rel * ny; }
  ball.vx += p.vx * .5; ball.vy += Math.min(0, p.vy) * .4;
  const sp = Math.hypot(ball.vx, ball.vy);
  if (sp < minSp) { ball.vx = nx * minSp; ball.vy = ny * minSp; }
  ball.vy -= up; ball.sq = .25; ball.spin = (ball.vx - p.vx) * .02;
  sfx('pop'); F.ring(hx + nx * rr * .8, hy + ny * rr * .8, 22, '#fff', 4);
  return true;
}

// ---------- 4. Bóng đá đầu to: chạy, nhảy, húc bóng vào gôn đối thủ ----------
export const soccer = versus('⚽ Bóng đá đầu to', async (box, opts, mode) => {
  const lv = opts.level || 0, th = theme(lv), need = 3;
  await loadAll(['Soccer ball', 'Glowing star', ...themeImgs(lv)]);
  const COS = vsCos(opts, mode);
  const {cv, ctx, W, H} = canvasIn(box);
  const S = Math.min(W, H), F = fxb(), C = camera(), M = multi(cv), ground = H * .74, G = S * 3.4;
  const r = Math.min(52, S * .08, mode === 'pvp' ? (W / 2 - 24) / 6.8 : 99), B = sideControls(M, W, H, r, mode);
  const gw = S * .12, gh = S * .34;
  const P = [{x: W * .3, y: ground, vx: 0, vy: 0, w: S * .17}, {x: W * .7, y: ground, vx: 0, vy: 0, w: S * .17}];
  let ball, a = 0, b = 0, t = 0, end = null, endT = 0, winner = 0, pause = 0;
  const pops = [0, 0], net = [0, 0];
  const kick = () => { ball = {x: W / 2, y: ground - S * .55, vx: rand(-60, 60), vy: 0, r: S * .045, rot: 0, sq: 0, born: 0}; P[0].x = W * .3; P[1].x = W * .7; P[0].vx = P[1].vx = 0; pause = .9; };
  kick();
  const aiSp = ramp(lv, .45, 1), aiJump = ramp(lv, .2, .8);
  const bg = prerender(W, H, g => {
    sky(g, W, H, th);
    th.deco.slice(0, 2).forEach((d, i) => draw(g, d, W * (i ? .78 : .22), ground - S * .1, S * .2, S * .2, {alpha: .5}));
    // Khán đài
    for (let i = 0; i < 3; i++) { g.fillStyle = i % 2 ? 'rgba(73,80,87,.28)' : 'rgba(73,80,87,.4)'; g.fillRect(0, ground - S * (.06 + i * .05), W, S * .05); }
    g.fillStyle = '#fff'; g.fillRect(0, ground - S * .07, W, 3);
    g.fillStyle = '#51cf66'; g.fillRect(0, ground, W, H - ground);
    for (let x = 0; x < W; x += 80) { g.fillStyle = 'rgba(0,0,0,.06)'; g.fillRect(x, ground, 40, H - ground); }
    g.strokeStyle = '#fff'; g.lineWidth = 4; g.beginPath(); g.moveTo(W / 2, ground); g.lineTo(W / 2, H); g.stroke();
    g.beginPath(); g.ellipse(W / 2, ground + (H - ground) * .45, S * .16, (H - ground) * .3, 0, 0, 7); g.stroke();
  });
  const scored = side => {
    if (side === 1) { a++; pops[0] = 1; net[1] = 1; sfx('win'); F.burst(W - gw / 2, ground - gh / 2, 34); F.text(W / 2, H * .4, 'VÀO!', '#ffd43b', 50); }
    else { b++; pops[1] = 1; net[0] = 1; sfx('wrong'); F.text(W / 2, H * .4, mode === 'pvp' ? 'ĐỎ GHI BÀN!' : 'MÁY GHI BÀN!', '#ff8787', 40); }
    C.shake(10); C.stop(.12); setTimeout(() => { if (!end) kick(); }, 700); pause = 99;
  };
  return loop({
    update(rdt) {
      t += rdt; C.update(rdt); const dt = rdt * C.scale(rdt); F.update(dt); pulseDecay(pops, rdt); pulseDecay(net, rdt, 1.2);
      if (end) { endT += rdt; return endT > 2.2 ? end : null; }
      if (t < 2.4) return null;
      runner(P[0], B.down('l1'), B.down('r1'), B.hit('j1'), dt, S, ground, G, F);
      if (mode === 'pvp') runner(P[1], B.down('l2'), B.down('r2'), B.hit('j2'), dt, S, ground, G, F);
      else {
        // Máy: đứng sau bóng (phía gôn mình) rồi húc về gôn bé; nhảy khi bóng trên đầu
        const p = P[1], want = ball.x + S * .06;
        const go = Math.abs(want - p.x) > 10 && Math.random() < aiSp + .2;
        runner(p, go && want < p.x, go && want > p.x, ball.y < p.y - p.w && Math.abs(ball.x - p.x) < p.w && Math.random() < aiJump * dt * 8, dt, S, ground, G, F, {sp: .62 * aiSp});
      }
      for (const p of P) p.x = Math.max(gw + p.w * .3, Math.min(W - gw - p.w * .3, p.x));
      ball.born += dt; ball.sq = Math.max(0, ball.sq - dt * 2.5);
      if (pause > 0) { pause -= dt; return null; }
      ball.vy += G * .55 * dt; ball.x += ball.vx * dt; ball.y += ball.vy * dt;
      ball.rot += ball.vx * dt / ball.r;
      if (ball.y > ground - ball.r) {
        ball.y = ground - ball.r;
        if (ball.vy > S * .5) { ball.sq = Math.min(.3, ball.vy / (S * 6)); F.dust(ball.x, ground, 3); }
        ball.vy = -Math.abs(ball.vy) * .68; ball.vx *= Math.exp(-dt * 3);
      }
      if (ball.y < 90 + ball.r) { ball.y = 90 + ball.r; ball.vy = Math.abs(ball.vy); }
      // Xà ngang gôn
      for (const gx of [0, W - gw]) if (ball.x > gx && ball.x < gx + gw && Math.abs(ball.y - (ground - gh)) < ball.r) { ball.vy = -ball.vy * .8; ball.y += ball.vy > 0 ? ball.r : -ball.r; sfx('tap'); F.sparks(ball.x, ground - gh, 5); C.shake(3); }
      for (const p of P) headHit(ball, p.x, p.y - p.w * .55, p.w * .48 + ball.r, p, S * 1.1, S * .3, F);
      if (ball.x < ball.r) { if (ball.y > ground - gh) scored(2); else { ball.x = ball.r; ball.vx = Math.abs(ball.vx) * .8; } }
      if (ball.x > W - ball.r) { if (ball.y > ground - gh) scored(1); else { ball.x = W - ball.r; ball.vx = -Math.abs(ball.vx) * .8; } }
      if (a >= need || b >= need) { winner = a >= need ? 1 : 2; end = {winner, score: a * 5}; }
      return null;
    },
    draw() {
      ctx.drawImage(bg, 0, 0, W, H);
      clouds(ctx, W, H, t, 3, .1);
      C.begin(ctx);
      // Gôn: lưới phồng ra khi có bàn
      for (const [k, gx] of [[0, 0], [1, W - gw]]) {
        const bulge = E.bump(1 - net[k]) * net[k] * gw * .5 * (k ? 1 : -1);
        ctx.strokeStyle = 'rgba(255,255,255,.55)'; ctx.lineWidth = 1.5;
        for (let y = ground - gh; y <= ground; y += 12) { const q = Math.sin((y - (ground - gh)) / gh * Math.PI); ctx.beginPath(); ctx.moveTo(gx, y); ctx.lineTo(gx + gw / 2 + bulge * q, y); ctx.lineTo(gx + gw, y); ctx.stroke(); }
        for (let x = 0; x <= gw; x += 12) { ctx.beginPath(); ctx.moveTo(gx + x, ground - gh); ctx.quadraticCurveTo(gx + x + bulge, ground - gh / 2, gx + x, ground); ctx.stroke(); }
        ctx.strokeStyle = '#fff'; ctx.lineWidth = 7; ctx.lineCap = 'round';
        ctx.beginPath(); ctx.moveTo(k ? gx : gx + gw, ground); ctx.lineTo(k ? gx : gx + gw, ground - gh); ctx.lineTo(k ? gx + gw : gx, ground - gh); ctx.stroke();
        ctx.fillStyle = k ? RED : BLUE; ctx.fillRect(gx, ground - gh - 10, gw, 8);
      }
      shadow(ctx, ball.x, ground + 4, ball.r * 1.1, ground - ball.y, .25);
      for (const [k, p] of P.entries()) {
        shadow(ctx, p.x, ground + 4, p.w * .35, ground - p.y, .2);
        const pose = end ? (winner === k + 1 ? 'cheer' : 'hurt') : p.y < ground - 2 ? 'jump' : Math.abs(p.vx) > 25 ? 'run' : 'idle';
        drawFigure(ctx, p.x, p.y, p.w * .62, {c: {...COS[k], shirt: k ? RED : BLUE}, pose, t: t + k, face: k ? -1 : 1, noHead: true});
        drawHead(ctx, p.x, p.y - p.w * .55, p.w * .42, COS[k], {face: k ? -1 : 1, t});
      }
      const bs = pause > 0 ? E.outBack(Math.min(1, ball.born / .45)) : 1;
      if (bs > 0) { const rr = ball.r; ball.r = rr * bs; drawBall(ctx, 'Soccer ball', ball); ball.r = rr; }
      F.draw(ctx);
      C.end(ctx);
      B.draw(ctx);
      scoreBar(ctx, W, a, b, need, ...COS, pops);
      if (t < 2.4) vsIntro(ctx, W, H, lv, mode, `Ghi ${need} bàn trước`, '◀ ▶ chạy · ⬆ nhảy · húc bóng vào gôn bên phải');
      if (end) endVs(ctx, W, H, winner, mode, lv, `${a} : ${b}`);
    }
  }, opts.alive);
});

// ---------- 5. Bóng chuyền: đánh bóng qua lưới, bóng rơi sân bên nào thì bên kia được điểm ----------
export const volley = versus('🏐 Bóng chuyền', async (box, opts, mode) => {
  const lv = opts.level || 0, need = 5;
  await loadAll(['Volleyball', 'Glowing star', 'Palm tree', 'Sun with face']);
  const COS = vsCos(opts, mode);
  const {cv, ctx, W, H} = canvasIn(box);
  const S = Math.min(W, H), F = fxb(), C = camera(), M = multi(cv), ground = H * .76, G = S * 2.2;
  const r = Math.min(52, S * .08, mode === 'pvp' ? (W / 2 - 24) / 6.8 : 99), B = sideControls(M, W, H, r, mode);
  const netH = S * .26, netX = W / 2;
  const P = [{x: W * .25, y: ground, vx: 0, vy: 0, w: S * .16}, {x: W * .75, y: ground, vx: 0, vy: 0, w: S * .16}];
  let ball, a = 0, b = 0, t = 0, end = null, endT = 0, winner = 0, pause = 0, netWob = 0;
  const pops = [0, 0];
  const serve = side => { ball = {x: side === 1 ? W * .25 : W * .75, y: ground - S * .55, vx: 0, vy: 0, r: S * .04, rot: 0, sq: 0, spin: 0, born: 0}; pause = .9; };
  serve(1);
  const aiSp = ramp(lv, .5, 1.05), aiRead = ramp(lv, .4, 1);
  const bg = prerender(W, H, g => {
    const gr = g.createLinearGradient(0, 0, 0, H); gr.addColorStop(0, '#4dabf7'); gr.addColorStop(.6, '#d0ebff'); gr.addColorStop(1, '#e7f5ff'); g.fillStyle = gr; g.fillRect(0, 0, W, H);
    g.fillStyle = '#1c7ed6'; g.fillRect(0, ground - S * .08, W, S * .08);
    g.fillStyle = 'rgba(255,255,255,.5)'; for (let i = 0; i < 14; i++) g.fillRect((i * 97) % W, ground - S * .06 + (i % 3) * 8, 30, 3);
    draw(g, 'Palm tree', W * .06, ground - S * .18, S * .36); draw(g, 'Palm tree', W * .94, ground - S * .18, S * .36, S * .36, {flip: true});
    g.fillStyle = '#ffe8a3'; g.fillRect(0, ground, W, H - ground);
    for (let i = 0; i < 70; i++) { g.fillStyle = i % 2 ? 'rgba(201,162,122,.35)' : 'rgba(255,255,255,.4)'; g.beginPath(); g.arc((i * 61.7) % W, ground + 6 + (i * 37) % (H - ground - 6), 2, 0, 7); g.fill(); }
  });
  const point = side => {
    if (side === 2) { b++; pops[1] = 1; sfx('wrong'); F.text(W * .25, H * .4, '+1 bên đỏ', '#ff8787', 32); }
    else { a++; pops[0] = 1; sfx('win'); F.text(W * .75, H * .4, '+1 bên xanh', '#74c0fc', 32); }
    F.burst(ball.x, ground, 16, ['#ffe8a3', '#e9c46a', '#fff']); F.ring(ball.x, ground, 40, '#fff', 5); C.shake(6);
    const k = side; pause = 99; setTimeout(() => { if (!end) serve(k); }, 650);
  };
  return loop({
    update(rdt) {
      t += rdt; C.update(rdt); const dt = rdt * C.scale(rdt); F.update(dt); pulseDecay(pops, rdt); netWob = Math.max(0, netWob - rdt * 1.5);
      if (end) { endT += rdt; return endT > 2.2 ? end : null; }
      if (t < 2.4) return null;
      runner(P[0], B.down('l1'), B.down('r1'), B.hit('j1'), dt, S, ground, G * 1.6, F, {sp: .7, jump: 1.35});
      if (mode === 'pvp') runner(P[1], B.down('l2'), B.down('r2'), B.hit('j2'), dt, S, ground, G * 1.6, F, {sp: .7, jump: 1.35});
      else {
        // Máy đoán chỗ bóng rơi (đọc sớm hơn ở cấp cao) rồi chạy tới, đứng hơi lệch ra sau để đánh qua lưới
        const p = P[1];
        let land = ball.x + ball.vx * aiRead * .9; if (ball.x < netX) land = W * .75;
        const want = Math.max(netX + p.w * .6, land + p.w * .18);
        runner(p, want < p.x - 8, want > p.x + 8, ball.x > netX && ball.y < p.y - p.w * 1.2 && Math.abs(ball.x - p.x) < p.w * .8 && Math.random() < .2, dt, S, ground, G * 1.6, F, {sp: .7 * aiSp, jump: 1.35});
      }
      P[0].x = Math.max(P[0].w * .4, Math.min(netX - P[0].w * .5, P[0].x)); P[1].x = Math.max(netX + P[1].w * .5, Math.min(W - P[1].w * .4, P[1].x));
      ball.born += dt; ball.sq = Math.max(0, ball.sq - dt * 2.5);
      if (pause > 0) { pause -= dt; return null; }
      ball.vy += G * dt; ball.x += ball.vx * dt; ball.y += ball.vy * dt; ball.rot += (ball.vx * .6 / ball.r + ball.spin * 20) * dt;
      if (ball.x < ball.r || ball.x > W - ball.r) { ball.vx = -ball.vx; ball.x = Math.max(ball.r, Math.min(W - ball.r, ball.x)); }
      // Lưới: bóng đập vào lưới thì lưới rung
      if (Math.abs(ball.x - netX) < ball.r + 4 && ball.y > ground - netH) { ball.vx = -ball.vx * .6; ball.x = netX + (ball.x < netX ? -1 : 1) * (ball.r + 5); netWob = 1; sfx('tap'); }
      for (const p of P) {
        const hy = p.y - p.w * .5;
        if (ball.y - hy < p.w * .3 && headHit(ball, p.x, hy, p.w * .5 + ball.r, p, S * 1.25, 0, F)) {
          const sp = S * 1.25, d = Math.hypot(ball.vx, ball.vy) || 1;
          ball.vx = ball.vx / d * sp * .8; ball.vy = Math.min(-S * .9, ball.vy / d * sp);
          if (p.y < ground - p.w * .4) { F.sparks(ball.x, ball.y, 8, '#fff3bf'); C.shake(3); }  // đập bóng khi đang nhảy
        }
      }
      if (ball.y > ground - ball.r) point(ball.x < netX ? 2 : 1);
      if (a >= need || b >= need) { winner = a >= need ? 1 : 2; end = {winner, score: a * 5}; }
      return null;
    },
    draw() {
      ctx.drawImage(bg, 0, 0, W, H);
      clouds(ctx, W, H, t, 3, .08);
      draw(ctx, 'Sun with face', W * .5, H * .14, S * .12, S * .12, {rot: Math.sin(t) * .05});
      C.begin(ctx);
      // Điểm bóng sắp rơi (giúp bé đoán)
      if (pause <= 0 && ball.vy > -S * .2) {
        const dy = ground - ball.r - ball.y, tt = (-ball.vy + Math.sqrt(Math.max(0, ball.vy * ball.vy + 2 * G * dy))) / G, lx = ball.x + ball.vx * tt;
        if (lx > 0 && lx < W) { ctx.strokeStyle = 'rgba(250,82,82,.5)'; ctx.lineWidth = 3; ctx.setLineDash([6, 6]); ctx.beginPath(); ctx.ellipse(lx, ground + 6, ball.r * 1.3, ball.r * .4, 0, 0, 7); ctx.stroke(); ctx.setLineDash([]); }
      }
      // Cột + lưới (rung khi bóng đập vào)
      ctx.fillStyle = '#868e96'; ctx.fillRect(netX - 4, ground - netH - 6, 8, netH + 6);
      ctx.strokeStyle = 'rgba(255,255,255,.95)'; ctx.lineWidth = 2;
      const wob = Math.sin(t * 40) * netWob * 6;
      for (let y = ground - netH; y < ground - netH * .45; y += 10) { const k = (y - (ground - netH)) / (netH * .55); ctx.beginPath(); ctx.moveTo(netX - 12 + wob * k, y); ctx.lineTo(netX + 12 + wob * k, y); ctx.stroke(); }
      for (const dx of [-12, 0, 12]) { ctx.beginPath(); ctx.moveTo(netX + dx, ground - netH); ctx.lineTo(netX + dx + wob, ground - netH * .45); ctx.stroke(); }
      ctx.fillStyle = '#fff'; ctx.fillRect(netX - 14, ground - netH - 4, 28, 5);
      shadow(ctx, ball.x, ground + 4, ball.r * 1.1, ground - ball.y, .25);
      for (const [k, p] of P.entries()) {
        shadow(ctx, p.x, ground + 4, p.w * .35, ground - p.y, .2);
        const pose = end ? (winner === k + 1 ? 'cheer' : 'hurt') : p.y < ground - 2 ? 'cheer' : Math.abs(p.vx) > 25 ? 'run' : 'idle';
        drawFigure(ctx, p.x, p.y, p.w * .7, {c: {...COS[k], shirt: k ? RED : BLUE}, pose, t: t + k, face: k ? -1 : 1, noHead: true});
        drawHead(ctx, p.x, p.y - p.w * .5, p.w * .36, COS[k], {face: k ? -1 : 1, t});
      }
      if (ball.y < 100) { ctx.fillStyle = '#ffd43b'; ctx.beginPath(); ctx.moveTo(ball.x, 96); ctx.lineTo(ball.x - 10, 110); ctx.lineTo(ball.x + 10, 110); ctx.fill(); }
      const bs = pause > 0 ? E.outBack(Math.min(1, ball.born / .45)) : 1;
      if (bs > 0) { const rr = ball.r; ball.r = rr * bs; drawBall(ctx, 'Volleyball', ball); ball.r = rr; }
      F.draw(ctx);
      C.end(ctx);
      B.draw(ctx);
      scoreBar(ctx, W, a, b, need, ...COS, pops);
      if (t < 2.4) vsIntro(ctx, W, H, lv, mode, `Được ${need} điểm trước`, '◀ ▶ chạy · ⬆ nhảy · đỡ bóng sang sân bên kia');
      if (end) endVs(ctx, W, H, winner, mode, lv, `${a} : ${b}`);
    }
  }, opts.alive);
});
