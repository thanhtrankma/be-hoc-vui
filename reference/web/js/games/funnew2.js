// Game mới (đợt 11): Khủng long chạy, Ếch qua đường, Bóng bàn, Ăn đậu, Ghép 3. Mỗi lượt một cấp (opts.level), 60 cấp.
import {sfx} from '../audio.js?v=4c51d34a6e';
import {banner, canvasIn, draw, endText, fx, goalPill, hud, levelBanner, loadAll, loop, pick, rand, ramp, roundRect, theme, themeImgs} from './funcore.js?v=4c51d34a6e';
import {BOT, drawHead, heroOf} from './figure.js?v=4c51d34a6e';
import {dirInput} from './funnew1.js?v=4c51d34a6e';
import {anim, approach, backHills, booms, coin, dust, easeOut, easeOutBack, groundTiles, shaker, sheets, spr, sprBox, sprW} from './funfx.js?v=4c51d34a6e';

const local = (cv, e) => { const r = cv.getBoundingClientRect(); return [e.clientX - r.left, e.clientY - r.top]; };
const DIRS = {u: [0, -1], d: [0, 1], l: [-1, 0], r: [1, 0]};
function sky(ctx, W, H, th) { const g = ctx.createLinearGradient(0, 0, 0, H); g.addColorStop(0, th.sky[0]); g.addColorStop(1, th.sky[1]); ctx.fillStyle = g; ctx.fillRect(0, 0, W, H); }
const hearts = (ctx, W, n, max = 3) => { for (let i = 0; i < max; i++) draw(ctx, 'Red heart', W - 40 - i * 36, 32, 30, 30, {alpha: i < n ? 1 : .22}); };

const v0 = lv => lv / 120;  // chân chạy nhanh hơn ở cấp cao
// ---------- 6. Khủng long chạy: chạm để nhảy (chạm 2 lần nhảy cao), né xương rồng, chim; ăn xu ----------
export async function runner(box, opts) {
  const lv = opts.level || 0, th = theme(lv), need = Math.round(ramp(lv, 150, 900));
  const OBS = ['Cactus', 'Rock', 'Fire'];
  const [[dino, en, tl, bgs, fxs]] = await Promise.all([sheets(['creatures/dino', 'plat/enemies', 'plat/tiles', 'plat/bg', 'fxa/fx']), loadAll(['T-Rex', 'Coin', 'Bird', 'Bat', 'Cloud', 'Red heart', ...OBS, ...themeImgs(lv)])]);
  const {cv, ctx, W, H} = canvasIn(box);
  const S = Math.min(W, H), F = fx(), ground = H * .78, G = S * 4.2, D = dust(200), SH = shaker();
  let scroll = 0, land = 0, jumpT = 0, wasAir = false, stepT = 0;
  const me = {x: W * .2, y: ground, vy: 0, w: S * .17, jumps: 0, inv: 0};
  const obs = [], coins = [], deco = [];
  let dist = 0, lives = 3, t = 0, spawn = 1.2, end = null, endT = 0, coinN = 0;
  for (let i = 0; i < 6; i++) deco.push({x: rand(0, W), k: pick(th.deco), s: rand(.7, 1.1)});
  cv.addEventListener('pointerdown', () => { if (end || t < 2) return; if (me.jumps < 2) { me.vy = -Math.sqrt(2 * G * S * (me.jumps ? .22 : .3)); me.jumps++; sfx('jump'); jumpT = 0; D.puff(me.x, me.y, 4, 'rgba(230,220,200,1)', 60, 6); } });
  return loop({
    update(dt) {
      t += dt; F.update(dt); D.update(dt); SH.update(dt); land = Math.max(0, land - dt); jumpT += dt;
      if (end) { endT += dt; return endT > 2 ? end : null; }
      if (t < 2) return null;
      const v = S * ramp(lv, .55, 1.05) * (1 + Math.min(.3, dist / 3000));
      dist += v * dt / (S * .1); scroll += v * dt;
      me.vy += G * dt; me.y += me.vy * dt; me.inv = Math.max(0, me.inv - dt);
      if (me.y >= ground) { if (wasAir) { land = .16; D.puff(me.x, ground, 5, 'rgba(230,220,200,1)', 80, 7); } me.y = ground; me.vy = 0; me.jumps = 0; }
      wasAir = me.y < ground - 1;
      stepT -= dt; if (!wasAir && stepT <= 0) { stepT = .14; D.emit(me.x - me.w * .2, ground - 3, -v * .4, rand(-50, -20), {life: .35, r: 3, grow: 8, c: 'rgba(230,220,200,1)', a: .6}); }
      spawn -= dt;
      if (spawn <= 0) {
        spawn = rand(.9, 1.6) * ramp(lv, 1.25, .7);
        if (lv >= 6 && Math.random() < ramp(lv, .1, .35)) obs.push({k: pick(['Bird', 'Bat']), x: W + 60, y: ground - S * rand(.25, .4), s: S * .1, fly: true, ph: 0});
        else { const k = pick(OBS), n = lv >= 25 && Math.random() < .3 ? 2 : 1; for (let i = 0; i < n; i++) obs.push({k, x: W + 60 + i * S * .09, y: ground - S * .05, s: S * .1}); }
        if (Math.random() < .5) for (let i = 0; i < 4; i++) coins.push({x: W + 220 + i * 50, y: ground - S * (.12 + .18 * Math.sin(i / 3 * Math.PI))});
      }
      const mb = {x: me.x, y: me.y - me.w * .45};
      for (let i = obs.length - 1; i >= 0; i--) {
        const o = obs[i]; o.x -= v * dt; if (o.fly) { o.ph += dt; o.y += Math.sin(o.ph * 5) * 30 * dt; }
        if (o.x < -80) { obs.splice(i, 1); continue; }
        if (me.inv <= 0 && Math.abs(o.x - mb.x) < (o.s + me.w) * .32 && Math.abs(o.y - mb.y) < (o.s + me.w) * .35) {
          lives--; me.inv = 1.4; sfx('hit'); SH.add(9); D.sparks(me.x, mb.y, 14, '#ff8787', 280); D.debris(o.x, o.y, 6, o.k === 'Cactus' ? '#2f9e44' : '#868e96', 240);
          if (lives <= 0) end = {win: false, score: Math.round(dist / 10) + coinN};
        }
      }
      for (let i = coins.length - 1; i >= 0; i--) { const c = coins[i]; c.x -= v * dt; if (c.x < -40) { coins.splice(i, 1); continue; } if (Math.hypot(c.x - mb.x, c.y - mb.y) < me.w * .5) { coins.splice(i, 1); coinN++; sfx('coin'); D.sparks(c.x, c.y, 6, '#ffe066', 160); F.text(c.x, c.y - 20, '+1', '#ffd43b'); } }
      for (const d of deco) { d.x -= v * dt * .3; if (d.x < -100) { d.x = W + 100; d.k = pick(th.deco); } }
      if (dist >= need && !end) { end = {win: true, score: Math.round(need / 10) + coinN * 2 + lives * 5}; sfx('win'); }
      return null;
    },
    draw() {
      ctx.save(); SH.apply(ctx);
      sky(ctx, W, H, th);
      draw(ctx, th.sun, W * .86, H * .14, S * .13);
      // Nền nhiều lớp: đồi xa (chậm), cảnh theo chủ đề (vừa), mặt đất gạch (nhanh)
      backHills(ctx, bgs, lv, scroll * .1, ground + 6, H * .3, W);
      for (const d of deco) draw(ctx, d.k, d.x, ground - S * .13 * d.s, S * .24 * d.s, S * .24 * d.s, {alpha: .7});
      groundTiles(ctx, tl, lv, scroll, ground - 4, W, H + 20, Math.max(44, S * .075));
      for (const c of coins) coin(ctx, fxs, t + c.x * .01, c.x, c.y, 30);
      const OBS_LOOK = {Cactus: 'cactus', Rock: 'rock'};
      for (const o of obs) {
        if (o.fly) anim(ctx, en, o.k === 'Bird' ? 'bee' : 'fly', t + o.ph, o.x, o.y, o.s * 1.1);
        else if (OBS_LOOK[o.k]) spr(ctx, tl, OBS_LOOK[o.k], o.x, o.y - o.s * .2, o.s * 1.5);
        else { const fl = 1 + Math.sin(t * 18 + o.x) * .08; draw(ctx, o.k, o.x, o.y - o.s * .1 * fl, o.s * (2 - fl), o.s * fl); }
      }
      D.draw(ctx);
      const blink = me.inv > 0 && Math.floor(me.inv * 10) % 2;
      if (!blink) {
        // Khủng long có hoạt ảnh chạy/nhảy; nén khi tiếp đất
        const sq = land > 0 ? Math.sin(land / .16 * Math.PI) * .14 : 0, hh = me.w * 1.05;
        ctx.save(); ctx.translate(me.x, me.y); ctx.scale(1 + sq, 1 - sq);
        if (dino) anim(ctx, dino, me.y < ground - 1 ? 'jump' : 'run', me.y < ground - 1 ? jumpT : t * (1 + v0(lv)), 0, -hh / 2 + hh * .04, hh);
        else draw(ctx, 'T-Rex', 0, -me.w * .45, me.w, me.w, {flip: true});
        ctx.restore();
      }
      F.draw(ctx);
      ctx.restore();
      hud(ctx, W, {score: coinN, lives: 0, time: null}); hearts(ctx, W, lives);
      ctx.fillStyle = 'rgba(0,0,0,.28)'; roundRect(ctx, W / 2 - 90, 10, 180, 44, 22); ctx.fill();
      ctx.fillStyle = '#fff'; ctx.textAlign = 'center'; ctx.font = '800 26px "Baloo 2", sans-serif'; ctx.fillText(`🏃 ${Math.floor(dist)}/${need} m`, W / 2, 42);
      if (t < 2) levelBanner(ctx, W, H, lv, `Chạy ${need} mét`, 'Chạm để nhảy · Chạm 2 lần để nhảy cao');
      if (end) banner(ctx, W, H, end.win ? endText(true, lv) : 'VẤP NGÃ RỒI!', `${Math.floor(dist)}/${need} mét`);
    }
  }, opts.alive);
}

// ---------- 7. Ếch qua đường: nhảy qua đường xe chạy và sông có khúc gỗ, về tới bờ bên kia ----------
export async function frogger(box, opts) {
  const lv = opts.level || 0, th = theme(lv), need = Math.min(8, 2 + Math.floor(lv / 10));
  const CARS = ['Automobile', 'Bus', 'Racing car', 'Police car', 'Delivery truck', 'Taxi'];
  const [[rs, en]] = await Promise.all([sheets(['racing/racing', 'plat/enemies']), loadAll(['Frog', 'Wood', 'Lotus', 'Red heart', 'Glowing star', ...CARS])]);
  const {cv, ctx, W, H} = canvasIn(box);
  const F = fx(), D = dust(200), SH = shaker();
  // Xe nhìn từ trên (Kenney Racing) thay hình xe nghiêng
  const CAR_SPR = ['car_red_1', 'car_blue_3', 'car_green_5', 'car_yellow_1', 'car_black_3', 'car_purple_5', 'car_blue_1', 'car_yellow_3'];
  // Hàng từ dưới lên: 0 bờ, đường (xe), dải cỏ, sông (gỗ), đích. Cấp cao nhiều làn hơn.
  const roadN = Math.min(5, 2 + Math.floor(lv / 12)), riverN = lv < 5 ? 0 : Math.min(4, 1 + Math.floor((lv - 5) / 14));
  const kinds = ['safe', ...Array(roadN).fill('road'), 'safe', ...Array(riverN).fill('river'), 'goal'];
  const R = kinds.length, top0 = W < 640 ? 110 : 70, cs = Math.min((H - top0 - 10) / R, W / 5), cols = Math.floor(W / cs), top = top0 + Math.max(0, (H - top0 - 10 - R * cs) / 2); // bàn lấp màn dọc (tối thiểu 5 cột), căn giữa phần dư
  const rowY = r => top + (R - 1 - r) * cs;
  const lanes = kinds.map((k, r) => {
    if (k !== 'road' && k !== 'river') return {k, items: []};
    const dir = r % 2 ? 1 : -1, v = dir * cs * ramp(lv, 1.3, 3.2) * rand(.8, 1.25);
    const items = [], len = k === 'river' ? Math.round(ramp(lv, 3, 2)) : 1, n = k === 'river' ? 3 : Math.round(ramp(lv, 2, 4));
    const span = W + cs * 4;
    for (let i = 0; i < n; i++) items.push({x: i * span / n + rand(0, cs), len, img: k === 'road' ? pick(CAR_SPR) : 'Wood', ph: rand(0, 6)});
    return {k, v, items, span};
  });
  let me = {c: Math.floor(cols / 2), r: 0, x: 0, ride: 0, dx: 0, dr: 0, face: 1}, crossed = 0, lives = 3, t = 0, end = null, endT = 0, hop = 0;
  me.x = me.dx = (me.c + .5) * cs;
  const die = () => {
    const L0 = lanes[me.r], y0 = rowY(me.r) + cs / 2;
    if (L0.k === 'river') { for (let k = 0; k < 14; k++) D.emit(me.x, y0, rand(-120, 120), rand(-220, -80), {life: .7, r: 4, grow: 0, c: '#d0ebff', k: 2, g: 600, a: 1}); }
    else { D.sparks(me.x, y0, 14, '#ffe066', 260); SH.add(8); }
    lives--; sfx('hit'); if (lives <= 0) end = {win: false, score: crossed * 10}; me.r = 0; me.x = (Math.floor(cols / 2) + .5) * cs; };
  dirInput(cv, () => [me.x, rowY(me.r) + cs / 2], d => {
    if (end || t < 2) return;
    const [dx, dy] = DIRS[d];
    me.x = Math.max(cs / 2, Math.min(W - cs / 2, me.x + dx * cs)); me.r = Math.max(0, Math.min(R - 1, me.r - dy));
    if (dx) me.face = dx; hop = .18; sfx('jump');
    if (kinds[me.r] === 'goal') {
      crossed++; sfx('win'); F.burst(me.x, rowY(me.r) + cs / 2, 24); for (let k = 0; k < 10; k++) D.emit(me.x, rowY(me.r) + cs / 2, rand(-150, 150), rand(-200, -50), {life: .8, r: 4, grow: 0, c: '#d0ebff', k: 2, g: 500, a: 1}); F.text(me.x, rowY(me.r), `${crossed}/${need}`, '#ffd43b');
      if (crossed >= need) { end = {win: true, score: crossed * 10 + lives * 5}; return; }
      me.r = 0;
    }
  });
  return loop({
    update(dt) {
      t += dt; F.update(dt); hop = Math.max(0, hop - dt); D.update(dt); SH.update(dt);
      // Vị trí vẽ đuổi theo vị trí thật (nhảy mượt từ ô này sang ô kia)
      me.dx = Math.abs(me.dx - me.x) > cs * 2.5 ? me.x : approach(me.dx, me.x, 22, dt); me.dr = Math.abs(me.dr - me.r) > 1.5 ? me.r : approach(me.dr, me.r, 22, dt);
      if (end) { endT += dt; return endT > 2 ? end : null; }
      if (t < 2) return null;
      for (const L of lanes) if (L.items.length) for (const it of L.items) { it.x += L.v * dt; if (L.v > 0 && it.x > W + cs * 2) it.x -= L.span; if (L.v < 0 && it.x < -cs * 2 - it.len * cs) it.x += L.span; }
      const L = lanes[me.r];
      if (L.k === 'road' && L.items.some(it => Math.abs(it.x + cs * .5 - me.x) < cs * .8)) die();
      else if (L.k === 'river') {
        const log = L.items.find(it => me.x > it.x - cs * .2 && me.x < it.x + it.len * cs + cs * .2);
        if (!log) die(); else { me.x += L.v * dt; if (me.x < 0 || me.x > W) die(); }
      }
      return null;
    },
    draw() {
      ctx.save(); SH.apply(ctx);
      sky(ctx, W, H, th);
      kinds.forEach((k, r) => {
        const y = rowY(r);
        ctx.fillStyle = k === 'road' ? '#495057' : k === 'river' ? '#339af0' : k === 'goal' ? '#8ce99a' : th.ground;
        ctx.fillRect(0, y, W, cs);
        if (k === 'road') { ctx.fillStyle = 'rgba(255,255,255,.6)'; for (let x = 0; x < W; x += 60) ctx.fillRect(x, y + cs - 3, 30, 3); ctx.fillStyle = 'rgba(0,0,0,.12)'; ctx.fillRect(0, y, W, 4); }
        if (k === 'river') { ctx.strokeStyle = 'rgba(255,255,255,.35)'; ctx.lineWidth = 2; const v = lanes[r].v; for (let x = -40; x < W + 40; x += 46) { const xx = x + ((t * v * .3) % 46); ctx.beginPath(); ctx.arc(xx, y + cs * (.3 + (x / 46 % 2) * .4), 8, Math.PI * 1.1, Math.PI * 1.9); ctx.stroke(); } }
        if (k === 'goal') for (let x = cs / 2; x < W; x += cs * 1.6) draw(ctx, 'Lotus', x, y + cs / 2 + Math.sin(t * 2 + x) * 2, cs * .7);
      });
      lanes.forEach((L, r) => {
        const y = rowY(r);
        for (const it of L.items) {
          if (L.k === 'road') {
            // Xe nhìn từ trên, quay đầu theo chiều chạy, rung nhẹ thân xe; khói xả phía sau
            const cxx = it.x + cs * .5, jig = Math.sin(t * 20 + it.ph) * .6;
            spr(ctx, rs, it.img, cxx, y + cs / 2 + jig, cs * 1.35, {rot: L.v > 0 ? Math.PI / 2 : -Math.PI / 2});
            if (Math.random() < .08) D.emit(cxx - Math.sign(L.v) * cs * .7, y + cs / 2, -L.v * .2, rand(-20, 20), {life: .5, r: 3, grow: 8, c: 'rgba(200,200,200,1)', a: .5});
          } else {
            const bob = Math.sin(t * 2 + it.ph) * 2, lw = it.len * cs;
            ctx.fillStyle = 'rgba(0,0,0,.15)'; roundRect(ctx, it.x + 4, y + cs * .2 + 5, lw, cs * .66, cs * .3); ctx.fill();
            ctx.fillStyle = '#8d5524'; roundRect(ctx, it.x, y + cs * .15 + bob, lw, cs * .7, cs * .3); ctx.fill();
            ctx.fillStyle = '#a0522d'; ctx.fillRect(it.x + 8, y + cs * .32 + bob, lw - 16, 4); ctx.fillRect(it.x + 14, y + cs * .58 + bob, lw - 30, 3);
            ctx.fillStyle = '#e0a96d'; ctx.beginPath(); ctx.ellipse(it.x + lw - cs * .12, y + cs / 2 + bob, cs * .1, cs * .3, 0, 0, 7); ctx.fill();
            ctx.strokeStyle = '#a0522d'; ctx.lineWidth = 2; ctx.beginPath(); ctx.ellipse(it.x + lw - cs * .12, y + cs / 2 + bob, cs * .05, cs * .16, 0, 0, 7); ctx.stroke();
          }
        }
      });
      D.draw(ctx);
      // Ếch Kenney: đang nhảy dùng khung bật, cao lên theo vòng cung
      const hk = hop > 0 ? Math.sin((1 - hop / .18) * Math.PI) : 0, fy = top + (R - 1 - me.dr) * cs + cs / 2;
      ctx.fillStyle = 'rgba(0,0,0,.18)'; ctx.beginPath(); ctx.ellipse(me.dx, fy + cs * .3, cs * .3 * (1 - hk * .3), cs * .1, 0, 0, 7); ctx.fill();
      if (en) spr(ctx, en, hop > 0 ? 'frog_jump' : (Math.sin(t * 3) > .9 ? 'frog_rest' : 'frog_idle'), me.dx, fy - hk * cs * .45, cs * .85, {flip: me.face > 0});
      else draw(ctx, 'Frog', me.dx, fy - hk * 60, cs * .85);
      F.draw(ctx);
      ctx.restore();
      hud(ctx, W, {score: crossed, lives: 0, time: null}); hearts(ctx, W, lives);
      goalPill(ctx, W, crossed, need, 16);
      if (t < 2) levelBanner(ctx, W, H, lv, `Qua đường ${need} lần`, 'Chạm hoặc vuốt để ếch nhảy · Né xe · Đứng trên khúc gỗ');
      if (end) banner(ctx, W, H, endText(end.win, lv), `${crossed}/${need} lần`);
    }
  }, opts.alive);
}

// ---------- 8. Bóng bàn: kéo vợt dưới, đánh thắng máy ----------
export async function pong(box, opts) {
  const lv = opts.level || 0, th = theme(lv), need = lv < 20 ? 3 : 5;
  const [[pz]] = await Promise.all([sheets(['puzzle/puzzle']), loadAll(['Robot', 'Glowing star', opts.hero])]);
  const {cv, ctx, W, H} = canvasIn(box);
  const S = Math.min(W, H), F = fx(), top = 80, bot = H - 20, D = dust(160), SH = shaker();
  const trail = Array.from({length: 10}, () => [0, 0]); let trailI = 0, squash = 0, sqA = 0, meHit = 0, aiHit = 0, spin = 0;
  const pw = S * ramp(lv, .3, .2), ph = 18, R = S * .025;
  const me = {x: W / 2, tx: W / 2}, ai = {x: W / 2};
  let ball, mine = 0, his = 0, t = 0, end = null, endT = 0, serveT = 1, rally = 0;
  const serve = dirDown => { ball = {x: W / 2, y: (top + bot) / 2, vx: rand(-.5, .5) * S, vy: (dirDown ? 1 : -1) * S * ramp(lv, .55, .95)}; serveT = .8; rally = 0; };
  serve(true);
  const steer = e => { me.tx = local(cv, e)[0]; };
  cv.addEventListener('pointerdown', e => { cv.setPointerCapture(e.pointerId); steer(e); });
  cv.addEventListener('pointermove', e => { if (e.buttons || e.pointerType !== 'mouse') steer(e); });
  const aiSpeed = S * ramp(lv, .45, 1.15), aiErr = ramp(lv, .35, .08);
  return loop({
    update(dt) {
      t += dt; F.update(dt); D.update(dt); SH.update(dt); squash = Math.max(0, squash - dt); meHit = Math.max(0, meHit - dt); aiHit = Math.max(0, aiHit - dt);
      if (ball) { trail[trailI][0] = ball.x; trail[trailI][1] = ball.y; trailI = (trailI + 1) % trail.length; }
      if (end) { endT += dt; return endT > 2 ? end : null; }
      if (t < 2) return null;
      me.x = approach(me.x, Math.max(pw / 2, Math.min(W - pw / 2, me.tx)), 16, dt);
      // Máy đuổi theo bóng, có độ trễ và sai số
      const aim = ball.vy < 0 ? ball.x + Math.sin(t * 1.3) * pw * aiErr : W / 2;
      ai.x += Math.max(-aiSpeed * dt, Math.min(aiSpeed * dt, aim - ai.x));
      if (serveT > 0) { serveT -= dt; return null; }
      for (let k = 0; k < 3; k++) {
        ball.x += ball.vx * dt / 3; ball.y += ball.vy * dt / 3;
        if (ball.x < R || ball.x > W - R) { ball.vx *= -1; ball.x = Math.max(R, Math.min(W - R, ball.x)); sfx('tap'); squash = .1; sqA = Math.PI / 2; D.sparks(ball.x, ball.y, 4, '#fff', 140); }
        const hitPad = (px, py, down) => {
          if (Math.abs(ball.y - py) < ph / 2 + R && Math.abs(ball.x - px) < pw / 2 + R && (down ? ball.vy > 0 : ball.vy < 0)) {
            const off = (ball.x - px) / (pw / 2), sp = Math.min(S * 1.9, Math.hypot(ball.vx, ball.vy) * 1.05);
            ball.vx = sp * off * .75; ball.vy = (down ? -1 : 1) * Math.sqrt(Math.max(1, sp * sp - ball.vx * ball.vx));
            sfx('pop'); D.sparks(ball.x, ball.y, 8, down ? '#ffe066' : '#ff8787', 220); rally++; squash = .12; sqA = 0; spin = off * 12;
            if (down) meHit = .15; else aiHit = .15; if (rally > 4) SH.add(1.5);
          }
        };
        hitPad(me.x, bot - 40, true); hitPad(ai.x, top + 30, false);
      }
      if (ball.y > bot + 20) { his++; sfx('wrong'); SH.add(7); if (his >= need) end = {win: false, score: mine * 5}; else serve(true); }
      if (ball.y < top - 20) { mine++; sfx('win'); F.burst(ball.x, top, 24); SH.add(5); F.text(W / 2, H / 2, 'GHI ĐIỂM!', '#ffd43b'); if (mine >= need) end = {win: true, score: mine * 5 + 10}; else serve(false); }
      return null;
    },
    draw() {
      ctx.save(); SH.apply(ctx);
      sky(ctx, W, H, th);
      ctx.fillStyle = 'rgba(0,0,0,.2)'; roundRect(ctx, 16, top - 2, W - 20, bot - top + 20, 24); ctx.fill();
      ctx.fillStyle = '#1971c2'; roundRect(ctx, 10, top - 10, W - 20, bot - top + 20, 24); ctx.fill();
      ctx.strokeStyle = 'rgba(255,255,255,.9)'; ctx.lineWidth = 4; roundRect(ctx, 20, top, W - 40, bot - top, 16); ctx.stroke();
      ctx.strokeStyle = 'rgba(255,255,255,.7)'; ctx.setLineDash([14, 12]); ctx.beginPath(); ctx.moveTo(10, (top + bot) / 2); ctx.lineTo(W - 10, (top + bot) / 2); ctx.stroke(); ctx.setLineDash([]);
      // Vợt sprite Kenney, lún xuống khi đánh trúng
      const ak = aiHit > 0 ? Math.sin(aiHit / .15 * Math.PI) * 6 : 0, mk = meHit > 0 ? Math.sin(meHit / .15 * Math.PI) * 6 : 0;
      if (pz) sprBox(ctx, pz, 'paddleRed', ai.x, top + 30 - ak, pw, ph * 1.5); else { ctx.fillStyle = '#ff6b6b'; roundRect(ctx, ai.x - pw / 2, top + 30 - ph / 2, pw, ph, 9); ctx.fill(); }
      drawHead(ctx, ai.x, top + 2 - ak, 18, BOT);
      if (pz) sprBox(ctx, pz, 'paddleBlu', me.x, bot - 40 + mk, pw, ph * 1.5); else { ctx.fillStyle = '#ffd43b'; roundRect(ctx, me.x - pw / 2, bot - 40 - ph / 2, pw, ph, 9); ctx.fill(); }
      drawHead(ctx, me.x, bot - 10 + mk, 18, heroOf(opts.hero));
      for (let i = 0; i < trail.length; i++) { const [x, y] = trail[(trailI + i) % trail.length]; ctx.globalAlpha = i / trail.length * .3; ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.arc(x, y, R * (.3 + i / trail.length * .6), 0, 7); ctx.fill(); }
      ctx.globalAlpha = 1;
      D.draw(ctx);
      // Bóng méo khi nảy, xoay theo cú đánh
      const sq = squash > 0 ? Math.sin(squash / .12 * Math.PI) * .3 : 0;
      ctx.save(); ctx.translate(ball.x, ball.y); ctx.rotate(sqA); ctx.scale(1 + sq, 1 - sq); ctx.rotate(t * spin);
      if (pz) spr(ctx, pz, 'ballGrey', 0, 0, R * 2.3); else { ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.arc(0, 0, R, 0, 7); ctx.fill(); }
      ctx.restore();
      F.draw(ctx);
      ctx.restore();
      ctx.fillStyle = 'rgba(0,0,0,.3)'; roundRect(ctx, W / 2 - 80, 10, 160, 50, 25); ctx.fill();
      ctx.fillStyle = '#fff'; ctx.textAlign = 'center'; ctx.font = '800 32px "Baloo 2", sans-serif'; ctx.fillText(`${mine} : ${his}`, W / 2, 46);
      if (t < 2) levelBanner(ctx, W, H, lv, `Ghi ${need} điểm trước máy`, 'Kéo ngón tay để di chuyển vợt vàng');
      if (end) banner(ctx, W, H, end.win ? endText(true, lv) : 'MÁY THẮNG RỒI!', `${mine} : ${his}`);
    }
  }, opts.alive);
}

// ---------- 9. Ăn đậu: đi trong mê cung ăn hết hạt, tránh ma; ăn sao thì ma sợ ----------
function makeMaze(cols, rows) {
  // Mê cung có nhiều lối vòng: đào kiểu DFS rồi đục thêm tường.
  const g = Array.from({length: rows}, () => Array(cols).fill(1));
  const st = [[1, 1]]; g[1][1] = 0;
  while (st.length) {
    const [x, y] = st[st.length - 1];
    const nb = [[2, 0], [-2, 0], [0, 2], [0, -2]].map(([dx, dy]) => [x + dx, y + dy, dx, dy]).filter(([a, b]) => a > 0 && b > 0 && a < cols - 1 && b < rows - 1 && g[b][a]);
    if (!nb.length) { st.pop(); continue; }
    const [a, b, dx, dy] = pick(nb); g[y + dy / 2][x + dx / 2] = 0; g[b][a] = 0; st.push([a, b]);
  }
  for (let i = 0; i < cols * rows / 6; i++) { const x = Math.floor(rand(1, cols - 1)), y = Math.floor(rand(1, rows - 1)); if ((x + y) % 2 && g[y][x]) g[y][x] = 0; }
  return g;
}
export async function pacman(box, opts) {
  const lv = opts.level || 0, th = theme(lv);
  const [[pz, fxs]] = await Promise.all([sheets(['puzzle/puzzle', 'fxa/fx']), loadAll(['Ghost', 'Glowing star', 'Cherries', 'Red heart', opts.hero])]);
  const {cv, ctx, W, H} = canvasIn(box);
  const F = fx(), top = W < 640 ? 110 : 70, D = dust(160), SH = shaker();
  const WALL = ['sq_green', 'sq_yellow', 'sq_blue', 'sq_purple', 'sq_red', 'sq_orange'][Math.floor(lv / 10) % 6];
  const cols = Math.round(ramp(lv, 11, 19)) | 1, rows = Math.round(cols * Math.min(1.2, (H - top) / W * 1.0)) | 1;
  const cs = Math.floor(Math.min(W / cols, (H - top - 10) / rows)), ox = (W - cols * cs) / 2, oy = top;
  const g = makeMaze(cols, rows);
  const dots = new Set(), stars = new Set();
  for (let y = 0; y < rows; y++) for (let x = 0; x < cols; x++) if (!g[y][x] && !(x === 1 && y === 1)) dots.add(x + ',' + y);
  [[1, rows - 2], [cols - 2, 1], [cols - 2, rows - 2]].forEach(([x, y]) => { if (!g[y][x]) { dots.delete(x + ',' + y); stars.add(x + ',' + y); } });
  const total = dots.size;
  const open = (x, y) => x >= 0 && y >= 0 && x < cols && y < rows && !g[y][x];
  const me = {x: 1, y: 1, px: 1, py: 1, k: 0, dir: null, next: null};
  const nG = Math.min(5, 1 + Math.floor(lv / 10));
  const ghosts = Array.from({length: nG}, (_, i) => { const x = cols - 2, y = rows - 2 - (i % 2) * 2; const ok = open(x, y); return {x: ok ? x : cols - 2, y: ok ? y : rows - 2, px: x, py: y, k: 0, dir: 'l', hue: i * 70}; });
  let lives = 3, t = 0, end = null, endT = 0, scared = 0, eaten = 0;
  dirInput(cv, () => [ox + (me.x + .5) * cs, oy + (me.y + .5) * cs], d => { me.next = d; });
  const meSp = ramp(lv, 4.2, 6), gSp = ramp(lv, 2.4, 5.4);
  const moveActor = (a, sp, dt, choose) => {
    a.k += sp * dt;
    while (a.k >= 1) {
      a.k -= 1; a.px = a.x; a.py = a.y;
      const d = choose(a);
      if (d && open(a.x + DIRS[d][0], a.y + DIRS[d][1])) { a.dir = d; a.x += DIRS[d][0]; a.y += DIRS[d][1]; } else { a.dir = null; a.k = 0; }
    }
  };
  return loop({
    update(dt) {
      t += dt; F.update(dt); D.update(dt); SH.update(dt);
      if (end) { endT += dt; return endT > 2 ? end : null; }
      if (t < 2) return null;
      scared = Math.max(0, scared - dt);
      moveActor(me, meSp, dt, a => (a.next && open(a.x + DIRS[a.next][0], a.y + DIRS[a.next][1])) ? a.next : a.dir);
      const key = me.x + ',' + me.y;
      if (dots.delete(key)) { eaten++; if (eaten % 3 === 0) sfx('count'); D.sparks(ox + (me.x + .5) * cs, oy + (me.y + .5) * cs, 3, '#ffe066', 90); }
      if (stars.delete(key)) { scared = 6; sfx('power'); SH.add(4); D.sparks(ox + (me.x + .5) * cs, oy + (me.y + .5) * cs, 16, '#74c0fc', 260); F.text(ox + me.x * cs, oy + me.y * cs, 'MA SỢ RỒI!', '#4dabf7'); }
      for (const gh of ghosts) {
        moveActor(gh, scared ? gSp * .6 : gSp, dt, a => {
          const opts2 = Object.keys(DIRS).filter(d => open(a.x + DIRS[d][0], a.y + DIRS[d][1]) && !(a.dir && DIRS[d][0] === -DIRS[a.dir][0] && DIRS[d][1] === -DIRS[a.dir][1]));
          if (!opts2.length) return Object.keys(DIRS).find(d => open(a.x + DIRS[d][0], a.y + DIRS[d][1]));
          // Đuổi theo bé (hoặc chạy trốn khi sợ), có ngẫu nhiên để không quá khó
          if (Math.random() < ramp(lv, .45, .8)) opts2.sort((p, q) => { const dp = Math.abs(a.x + DIRS[p][0] - me.x) + Math.abs(a.y + DIRS[p][1] - me.y), dq = Math.abs(a.x + DIRS[q][0] - me.x) + Math.abs(a.y + DIRS[q][1] - me.y); return scared ? dq - dp : dp - dq; });
          else opts2.sort(() => Math.random() - .5);
          return opts2[0];
        });
        if (gh.x === me.x && gh.y === me.y) {
          if (scared) { sfx('boom'); F.burst(ox + (gh.x + .5) * cs, oy + (gh.y + .5) * cs, 18); D.puff(ox + (gh.x + .5) * cs, oy + (gh.y + .5) * cs, 6, 'rgba(255,255,255,1)', 80, cs * .2); SH.add(4); gh.x = cols - 2; gh.y = rows - 2; if (!open(gh.x, gh.y)) { gh.x = me.x; } gh.k = 0; }
          else { lives--; sfx('hit'); SH.add(9); D.sparks(ox + (me.x + .5) * cs, oy + (me.y + .5) * cs, 16, '#ff8787', 260); me.x = me.y = 1; me.k = 0; me.dir = me.next = null; if (lives <= 0) end = {win: false, score: eaten}; }
        }
      }
      if (!dots.size && !end) { end = {win: true, score: eaten + lives * 10}; sfx('win'); }
      return null;
    },
    draw() {
      ctx.fillStyle = '#10153a'; ctx.fillRect(0, 0, W, H);
      ctx.save(); SH.apply(ctx);
      for (let y = 0; y < rows; y++) for (let x = 0; x < cols; x++) if (g[y][x]) { if (pz) sprBox(ctx, pz, WALL, ox + (x + .5) * cs, oy + (y + .5) * cs, cs - 2, cs - 2); else { ctx.fillStyle = th.edge; roundRect(ctx, ox + x * cs + 2, oy + y * cs + 2, cs - 4, cs - 4, cs * .25); ctx.fill(); } }
      // Hạt đậu lấp lánh theo sóng
      ctx.fillStyle = '#ffe066';
      for (const d of dots) { const [x, y] = d.split(',').map(Number); ctx.beginPath(); ctx.arc(ox + (x + .5) * cs, oy + (y + .5) * cs, cs * (.11 + Math.max(0, Math.sin(t * 4 - (x + y) * .5)) * .04), 0, 7); ctx.fill(); }
      for (const s of stars) { const [x, y] = s.split(',').map(Number); draw(ctx, 'Glowing star', ox + (x + .5) * cs, oy + (y + .5) * cs, cs * (.8 + Math.sin(t * 6) * .1)); }
      const pos = a => [ox + (a.px + (a.x - a.px) * Math.min(1, a.k) + .5) * cs, oy + (a.py + (a.y - a.py) * Math.min(1, a.k) + .5) * cs];
      const GC = ['#ff6b6b', '#cc5de8', '#ff922b', '#20c997', '#f06595'];
      for (const [i, gh] of ghosts.entries()) {
        const [x, y] = pos(gh);
        // Vòng màu dưới chân ma (Safari không có ctx.filter); khi sợ thì ma mờ, vòng xanh nhấp nháy.
        ctx.fillStyle = scared ? (Math.floor(t * 6) % 2 ? '#4dabf7' : '#d0ebff') : GC[i % GC.length];
        ctx.globalAlpha = .55; ctx.beginPath(); ctx.arc(x, y, cs * .48, 0, 7); ctx.fill(); ctx.globalAlpha = 1;
        // Ma bồng bềnh: phập phồng, nghiêng theo hướng đi; khi sợ thì run
        const wob = Math.sin(t * 8 + i), lean = gh.dir === 'l' ? -.15 : gh.dir === 'r' ? .15 : 0, shiver = scared ? Math.sin(t * 60) * 1.5 : 0;
        ctx.save(); ctx.translate(x + shiver, y + Math.sin(t * 6 + i) * 3); ctx.rotate(lean); ctx.scale(1 + wob * .05, 1 - wob * .05);
        draw(ctx, 'Ghost', 0, 0, cs * .9, cs * .9, {alpha: scared ? .6 : 1, flip: gh.dir === 'r'});
        ctx.restore();
      }
      const [mx, my] = pos(me), bobk = Math.abs(Math.sin(t * 12)) * (me.dir ? 1 : 0);
      drawHead(ctx, mx, my - bobk * cs * .06, cs * .42, heroOf(opts.hero), {face: me.dir && me.dir[0] < 0 ? -1 : 1, t});
      D.draw(ctx);
      ctx.restore();
      F.draw(ctx);
      hud(ctx, W, {score: eaten, lives: 0, time: null}); hearts(ctx, W, lives);
      goalPill(ctx, W, total - dots.size, total, 16);
      if (t < 2) levelBanner(ctx, W, H, lv, `Ăn hết ${total} hạt đậu`, 'Vuốt hoặc chạm để đi · Ăn ngôi sao thì ma sợ');
      if (end) banner(ctx, W, H, end.win ? endText(true, lv) : 'MA BẮT MẤT RỒI!', `${total - dots.size}/${total} hạt`);
    }
  }, opts.alive);
}

// ---------- 10. Ghép 3: đổi chỗ 2 ô cạnh nhau để có 3 hình giống nhau thẳng hàng ----------
export async function match3(box, opts) {
  const lv = opts.level || 0, th = theme(lv), need = Math.round(ramp(lv, 20, 90)), moves0 = Math.round(ramp(lv, 22, 18));
  const GEM = ['Red apple', 'Banana', 'Grapes', 'Strawberry', 'Tangerine', 'Watermelon', 'Cherries'];
  const kinds = GEM.slice(0, Math.round(ramp(lv, 4, 7)));
  await loadAll([...kinds, 'Glowing star', 'Collision']);
  const {cv, ctx, W, H} = canvasIn(box);
  const N = 7, top = W < 640 ? 160 : 80, cs = Math.floor(Math.min((W - 20) / N, (H - top - 20) / N)), ox = (W - N * cs) / 2, oy = top;
  const F = fx(), D = dust(220), SH = shaker(), pops = [];
  const g = Array.from({length: N}, () => Array.from({length: N}, () => ({k: pick(kinds), y: -rand(2, 6) * cs, vy: 0, ox: 0, oy: 0})));  // rơi vào bảng lúc mở màn
  const matches = () => {
    const m = new Set();
    for (let y = 0; y < N; y++) for (let x = 0; x < N - 2; x++) if (g[y][x].k === g[y][x + 1].k && g[y][x].k === g[y][x + 2].k) [0, 1, 2].forEach(k => m.add(`${x + k},${y}`));
    for (let x = 0; x < N; x++) for (let y = 0; y < N - 2; y++) if (g[y][x].k === g[y + 1][x].k && g[y][x].k === g[y + 2][x].k) [0, 1, 2].forEach(k => m.add(`${x},${y + k}`));
    return m;
  };
  // Bảng mở đầu không có sẵn hàng 3
  for (let m = matches(); m.size; m = matches()) for (const p of m) { const [x, y] = p.split(',').map(Number); g[y][x].k = pick(kinds); }
  let score = 0, moves = moves0, t = 0, end = null, endT = 0, sel = null, busy = false, combo = 0;
  const cell = e => { const [x, y] = local(cv, e); const cx = Math.floor((x - ox) / cs), cy = Math.floor((y - oy) / cs); return cx >= 0 && cy >= 0 && cx < N && cy < N ? [cx, cy] : null; };
  let down = null;
  // Đổi chỗ có trượt mượt: ô mới mang độ lệch về vị trí cũ rồi trượt về 0
  const swap = (a, b) => {
    const A = g[a[1]][a[0]], B2 = g[b[1]][b[0]]; g[a[1]][a[0]] = B2; g[b[1]][b[0]] = A;
    if (A) { A.ox = (a[0] - b[0]) * cs; A.oy = (a[1] - b[1]) * cs; }
    if (B2) { B2.ox = (b[0] - a[0]) * cs; B2.oy = (b[1] - a[1]) * cs; }
  };
  const wait = ms => new Promise(r => setTimeout(r, ms));
  async function tryMove(a, b) {
    busy = true; swap(a, b); sfx('tap');
    await wait(160);
    if (!matches().size) { swap(a, b); sfx('wrong'); busy = false; return; }
    moves--; combo = 0;
    for (let m = matches(); m.size; m = matches()) {
      combo++;
      const pts = m.size * combo; score += pts;
      for (const p of m) { const [x, y] = p.split(',').map(Number); const px = ox + (x + .5) * cs, py = oy + (y + .5) * cs; pops.push({k: g[y][x].k, x: px, y: py, t: .3}); D.sparks(px, py, 6, '#fff3bf', 200); g[y][x] = null; }
      SH.add(1.5 + combo * 1.5);
      sfx(combo > 1 ? 'win' : 'coin'); F.text(W / 2, oy - 10, combo > 1 ? `x${combo} +${pts}` : `+${pts}`, '#ffd43b');
      await wait(220);
      // Cột dồn xuống: mỗi ô nhớ độ lệch (y âm) bằng quãng phải rơi, rơi có trọng lực rồi nảy nhẹ
      for (let x = 0; x < N; x++) {
        const col = []; for (let y = N - 1; y >= 0; y--) if (g[y][x]) col.push([g[y][x], y]);
        for (let y = N - 1, i = 0; y >= 0; y--, i++) {
          if (col[i]) { const [c, y0] = col[i]; c.y += (y0 - y) * cs; c.vy = c.vy || 0; g[y][x] = c; }
          else g[y][x] = {k: pick(kinds), y: -(i - col.length + 1) * cs - cs * .5, vy: 0, ox: 0, oy: 0};
        }
      }
      await wait(260);
    }
    if (score >= need) { end = {win: true, score: score + moves * 2}; sfx('win'); }
    else if (moves <= 0) end = {win: false, score};
    busy = false;
  }
  cv.addEventListener('pointerdown', e => { if (busy || end || t < 2) return; down = cell(e); });
  cv.addEventListener('pointerup', e => {
    if (!down || busy || end) return;
    const up = cell(e), a = down; down = null;
    if (up && (up[0] !== a[0] || up[1] !== a[1])) {
      const dx = Math.sign(up[0] - a[0]), dy = Math.sign(up[1] - a[1]);
      const b = Math.abs(up[0] - a[0]) > Math.abs(up[1] - a[1]) ? [a[0] + dx, a[1]] : [a[0], a[1] + dy];
      sel = null; tryMove(a, b); return;
    }
    if (sel && Math.abs(sel[0] - a[0]) + Math.abs(sel[1] - a[1]) === 1) { const s = sel; sel = null; tryMove(s, a); }
    else { sel = a; sfx('tap'); }
  });
  return loop({
    update(dt) {
      t += dt; F.update(dt); D.update(dt); SH.update(dt);
      for (let i = pops.length - 1; i >= 0; i--) { pops[i].t -= dt; if (pops[i].t <= 0) pops.splice(i, 1); }
      for (const row of g) for (const c of row) {
        if (!c) continue;
        if (c.y < 0 || c.vy) { c.vy += cs * 70 * dt; c.y += c.vy * dt; if (c.y >= 0) { c.y = 0; c.vy = c.vy > cs * 4 ? -c.vy * .25 : 0; } }
        if (c.ox) c.ox = Math.abs(c.ox) < .5 ? 0 : approach(c.ox, 0, 18, dt);
        if (c.oy) c.oy = Math.abs(c.oy) < .5 ? 0 : approach(c.oy, 0, 18, dt);
      }
      if (end) { endT += dt; return endT > 2 ? end : null; }
      return null;
    },
    draw() {
      sky(ctx, W, H, th);
      ctx.save(); SH.apply(ctx);
      ctx.fillStyle = 'rgba(255,255,255,.55)'; roundRect(ctx, ox - 8, oy - 8, N * cs + 16, N * cs + 16, 20); ctx.fill();
      for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
        if ((x + y) % 2) { ctx.fillStyle = 'rgba(0,0,0,.05)'; ctx.fillRect(ox + x * cs, oy + y * cs, cs, cs); }
        const c = g[y][x]; if (!c) continue;
        const isSel = sel && sel[0] === x && sel[1] === y;
        if (isSel) { ctx.fillStyle = 'rgba(255,212,59,.6)'; roundRect(ctx, ox + x * cs + 2, oy + y * cs + 2, cs - 4, cs - 4, 12); ctx.fill(); }
        // Ô chọn phập phồng; các ô thở nhẹ lệch pha cho bảng sinh động
        const br = isSel ? .86 + Math.sin(t * 10) * .06 : .8 + Math.sin(t * 2 + x * .7 + y * .5) * .015;
        if (c.y < -cs * .3 && oy + (y + .5) * cs + c.y < oy - cs * .3) continue;
        draw(ctx, c.k, ox + (x + .5) * cs + (c.ox || 0), oy + (y + .5) * cs + c.y + (c.oy || 0), cs * br, cs * br, {rot: isSel ? Math.sin(t * 8) * .12 : 0});
      }
      for (const p of pops) { const k = p.t / .3; draw(ctx, p.k, p.x, p.y, cs * .8 * (k < .6 ? k / .6 : 1 + (1 - k) * 1.2), cs * .8 * (k < .6 ? k / .6 : 1 + (1 - k) * 1.2), {alpha: Math.min(1, k * 2)}); }
      D.draw(ctx);
      ctx.restore();
      F.draw(ctx);
      hud(ctx, W, {score, lives: 0, time: null});
      const mx = W < 640 ? 12 : W - 170, my = W < 640 ? 104 : 10;
      ctx.fillStyle = 'rgba(0,0,0,.28)'; roundRect(ctx, mx, my, 158, 44, 22); ctx.fill();
      ctx.fillStyle = '#fff'; ctx.textAlign = 'center'; ctx.font = '800 24px "Baloo 2", sans-serif'; ctx.fillText(`Còn ${moves} lượt`, mx + 79, my + 31);
      goalPill(ctx, W, score, need, 16);
      if (t < 2) levelBanner(ctx, W, H, lv, `Được ${need} điểm trong ${moves0} lượt`, 'Vuốt một hình sang ô bên cạnh để xếp 3 hình giống nhau');
      if (end) banner(ctx, W, H, end.win ? endText(true, lv) : 'HẾT LƯỢT RỒI!', `${score}/${need} điểm`);
    }
  }, opts.alive);
}
