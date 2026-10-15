// Game mới (đợt 11): Rắn săn mồi, Bắn bia, Xe tăng, Xếp gạch, Nhảy mây. Mỗi lượt một cấp (opts.level), 60 cấp.
import {sfx} from '../audio.js?v=4c51d34a6e';
import {LIVES, banner, canvasIn, draw, endText, fx, goalPill, hit, hud, levelBanner, loadAll, loop, pick, rand, ramp, roundRect, theme, themeImgs} from './funcore.js?v=4c51d34a6e';
import {drawFigure, heroOf} from './figure.js?v=4c51d34a6e';
import {anim, approach, booms, coin, dust, easeOut, easeOutBack, shaker, sheets, spr, sprBox, stripX, tile} from './funfx.js?v=4c51d34a6e';

const local = (cv, e) => { const r = cv.getBoundingClientRect(); return [e.clientX - r.left, e.clientY - r.top]; };
const DIRS = {u: [0, -1], d: [0, 1], l: [-1, 0], r: [1, 0]};
const OPP = {u: 'd', d: 'u', l: 'r', r: 'l'};
// Vuốt theo hướng, hoặc chạm: hướng tính từ vị trí nhân vật (ref()) tới chỗ chạm.
export function dirInput(cv, ref, onDir) {
  let st = null;
  cv.addEventListener('pointerdown', e => { st = local(cv, e); });
  cv.addEventListener('pointerup', e => {
    if (!st) return;
    const [x, y] = local(cv, e);
    let dx = x - st[0], dy = y - st[1];
    if (Math.hypot(dx, dy) < 24) { const [px, py] = ref(); dx = x - px; dy = y - py; }
    st = null;
    onDir(Math.abs(dx) > Math.abs(dy) ? (dx > 0 ? 'r' : 'l') : (dy > 0 ? 'd' : 'u'));
  });
}
function sky(ctx, W, H, th) { const g = ctx.createLinearGradient(0, 0, 0, H); g.addColorStop(0, th.sky[0]); g.addColorStop(1, th.sky[1]); ctx.fillStyle = g; ctx.fillRect(0, 0, W, H); }

// ---------- 1. Rắn săn mồi (bò mượt): rắn bò theo ngón tay trong sân lớn, ăn hạt và trái cây để dài ra,
// rắn máy bò quanh; đâm đầu vào thân rắn khác là mất mạng, rắn máy đâm vào thân bé thì hoá thành hạt. Chạm 2 lần để tăng tốc.
const SNAKE_SKINS = [['#51cf66', '#2f9e44'], ['#ff922b', '#e8590c'], ['#cc5de8', '#9c36b5'], ['#339af0', '#1971c2'], ['#ff6b6b', '#e03131'], ['#fcc419', '#f08c00'], ['#20c997', '#0ca678'], ['#f06595', '#c2255c']];
export async function snake(box, opts) {
  const lv = opts.level || 0, th = theme(lv), need = Math.round(ramp(lv, 25, 110));
  const FRUIT = ['Red apple', 'Strawberry', 'Grapes', 'Cherries', 'Banana', 'Watermelon'];
  await loadAll([...FRUIT, 'Red heart', 'Coin', 'High voltage']);
  const {cv, ctx, W, H} = canvasIn(box);
  const S = Math.min(W, H), F = fx();
  const WW = Math.max(W, H) * 2.2, WH = Math.max(W, H) * 1.8;  // kích thước sân
  const R0 = S * .028, SP = S * ramp(lv, .3, .38), TURN = 4.2;
  const foods = [], SD = dust(200), SSH = shaker();
  const addFood = (x = rand(40, WW - 40), y = rand(40, WH - 40), big = Math.random() < .12, v) => foods.push({x, y, big, v: v || (big ? 4 : 1), k: big ? pick(FRUIT) : null, c: `hsl(${Math.floor(rand(0, 360))},85%,62%)`, ph: rand(0, 6)});
  for (let i = 0; i < 160; i++) addFood();
  const mkSnake = (x, y, len, skin, bot) => {
    const a = rand(0, 6.28), path = [];
    for (let i = 0; i < len * 4; i++) path.push([x - Math.cos(a) * i * 3, y - Math.sin(a) * i * 3]);
    return {x, y, a, ta: a, len, path, skin, bot, boost: 0, dead: false, think: 0, r: R0};
  };
  const me = mkSnake(WW / 2, WH / 2, 14, SNAKE_SKINS[3], false);  // rắn của bé màu xanh dương, nổi trên nền cỏ
  const bots = [];
  const nBots = Math.round(ramp(lv, 2, 8));
  const spawnBot = () => { let x, y; do { x = rand(100, WW - 100); y = rand(100, WH - 100); } while (Math.hypot(x - me.x, y - me.y) < S * .8); bots.push(mkSnake(x, y, Math.round(rand(10, 10 + lv * .6)), pick(SNAKE_SKINS.filter((_, i) => i !== 3)), true)); };
  for (let i = 0; i < nBots; i++) spawnBot();
  let score = 0, lives = 3, t = 0, end = null, endT = 0, inv = 2, lastTap = 0, cam = {x: me.x - W / 2, y: me.y - H / 2};
  const aim = e => { const [x, y] = local(cv, e); me.ta = Math.atan2(y + cam.y - me.y, x + cam.x - me.x); };
  cv.addEventListener('pointerdown', e => { cv.setPointerCapture(e.pointerId); aim(e); const now = performance.now(); if (now - lastTap < 300) { me.boost = 1.6; sfx('power'); } lastTap = now; });
  cv.addEventListener('pointermove', e => { if (e.buttons || e.pointerType !== 'mouse') aim(e); });
  const angDiff = (a, b) => { let d = b - a; while (d > Math.PI) d -= 2 * Math.PI; while (d < -Math.PI) d += 2 * Math.PI; return d; };
  // Các điểm thân theo khoảng cách đều dọc đường đi
  const segs = sn => { const out = [], gap = sn.r * .55; let acc = 0; out.push(sn.path[0]); for (let i = 1; i < sn.path.length && out.length < sn.len; i++) { const [x0, y0] = sn.path[i - 1], [x1, y1] = sn.path[i]; acc += Math.hypot(x1 - x0, y1 - y0); if (acc >= gap) { out.push([x1, y1]); acc = 0; } } return out; };
  const move = (sn, dt) => {
    sn.boost = Math.max(0, sn.boost - dt); sn.gulp = Math.max(0, (sn.gulp || 0) - dt);
    if (sn.boost > 0 && Math.random() < .7) SD.emit(sn.path[Math.min(sn.path.length - 1, 12)][0], sn.path[Math.min(sn.path.length - 1, 12)][1], rand(-30, 30), rand(-30, 30), {life: .4, r: sn.r * .4, grow: 4, c: '#ffe066', a: .8});
    sn.a += Math.max(-TURN * dt, Math.min(TURN * dt, angDiff(sn.a, sn.ta)));
    const v = (sn.bot ? SP * ramp(lv, .75, 1) : SP) * (sn.boost > 0 ? 1.7 : 1);
    sn.x += Math.cos(sn.a) * v * dt; sn.y += Math.sin(sn.a) * v * dt;
    sn.path.unshift([sn.x, sn.y]);
    const keep = sn.len * sn.r * .55 / 2 + 40; if (sn.path.length > keep * 2) sn.path.length = Math.ceil(keep * 2);
    sn.r = R0 * (1 + Math.min(.8, sn.len / 160));
  };
  const kill = (sn) => {
    sn.dead = true; sfx('boom'); SSH.add(5); for (const [x, y] of segs(sn).filter((_, i) => i % 4 === 0)) SD.sparks(x, y, 3, sn.skin[0], 180);
    for (const [x, y] of segs(sn).filter((_, i) => i % 2 === 0)) addFood(x + rand(-8, 8), y + rand(-8, 8), false, 2);
    F.burst(sn.x - cam.x, sn.y - cam.y, 24);
  };
  return loop({
    update(dt) {
      t += dt; F.update(dt); SD.update(dt); SSH.update(dt);
      if (end) { endT += dt; return endT > 2 ? end : null; }
      if (t < 2) return null;
      inv = Math.max(0, inv - dt);
      move(me, dt);
      // Rắn máy: tìm hạt gần, tránh tường; cấp cao có lúc lao chặn đầu bé
      for (const b of bots) {
        if (b.dead) continue;
        b.think -= dt;
        if (b.think <= 0) {
          b.think = rand(.3, .8);
          const chase = lv >= 15 && Math.random() < ramp(lv, 0, .35) && Math.hypot(me.x - b.x, me.y - b.y) < S;
          if (chase) b.ta = Math.atan2(me.y + Math.sin(me.a) * S * .3 - b.y, me.x + Math.cos(me.a) * S * .3 - b.x);
          else { let best = null, bd = 1e9; for (const f of foods) { const d = Math.hypot(f.x - b.x, f.y - b.y); if (d < bd) { bd = d; best = f; } } if (best) b.ta = Math.atan2(best.y - b.y, best.x - b.x) + rand(-.3, .3); }
        }
        if (b.x < 80 || b.x > WW - 80 || b.y < 80 || b.y > WH - 80) b.ta = Math.atan2(WH / 2 - b.y, WW / 2 - b.x);
        move(b, dt);
      }
      // Ăn hạt
      for (const sn of [me, ...bots]) {
        if (sn.dead) continue;
        for (let i = foods.length - 1; i >= 0; i--) {
          const f = foods[i];
          if (Math.hypot(f.x - sn.x, f.y - sn.y) < sn.r + (f.big ? 18 : 7)) {
            foods.splice(i, 1); sn.len += f.v;
            sn.gulp = .25;
            if (sn === me) { score += f.v; sfx(f.big ? 'coin' : 'count'); if (f.big) { F.text(f.x - cam.x, f.y - cam.y - 20, '+' + f.v, '#ffd43b'); SD.sparks(f.x, f.y, 10, '#ffe066', 220); } }
          }
        }
      }
      while (foods.length < 140) addFood();
      // Va chạm: đầu chạm thân rắn khác
      const all = [me, ...bots.filter(b => !b.dead)];
      const bodies = all.map(sn => ({sn, pts: segs(sn)}));
      for (const sn of all) {
        if (sn.dead || (sn === me && inv > 0)) continue;
        for (const {sn: o, pts} of bodies) {
          if (o === sn) continue;
          if (pts.some(([x, y], i) => i > 1 && Math.hypot(x - sn.x, y - sn.y) < sn.r * .7 + o.r * .8)) {
            if (sn === me) {
              lives--; sfx('hit'); SSH.add(10); SD.sparks(me.x, me.y, 18, '#ff8787', 300);
              if (lives <= 0) { end = {win: false, score}; return null; }
              const keep = me.len; Object.assign(me, mkSnake(rand(200, WW - 200), rand(200, WH - 200), Math.max(14, Math.round(keep * .6)), me.skin, false)); inv = 2;
            } else { kill(sn); if (o === me) { F.text(W / 2, H * .3, 'GIỎI QUÁ!', '#ffd43b'); } }
            break;
          }
        }
      }
      for (let i = bots.length - 1; i >= 0; i--) if (bots[i].dead) { bots.splice(i, 1); setTimeout(spawnBot, 2500); }
      // Tường sân: chạm là bị đẩy lại và mất mạng ở cấp cao
      if (me.x < me.r || me.y < me.r || me.x > WW - me.r || me.y > WH - me.r) {
        me.x = Math.max(me.r, Math.min(WW - me.r, me.x)); me.y = Math.max(me.r, Math.min(WH - me.r, me.y)); me.a += Math.PI; me.ta = me.a;
        if (lv >= 20 && inv <= 0) { lives--; inv = 2; sfx('hit'); if (lives <= 0) { end = {win: false, score}; return null; } } else sfx('pop');
      }
      cam.x += (me.x - W / 2 - cam.x) * Math.min(1, dt * 5); cam.y += (me.y - H / 2 - cam.y) * Math.min(1, dt * 5);
      if (score >= need) { end = {win: true, score: score + lives * 5}; sfx('win'); }
      return null;
    },
    draw() {
      ctx.fillStyle = th.edge; ctx.fillRect(0, 0, W, H);
      ctx.save(); SSH.apply(ctx); ctx.translate(-cam.x, -cam.y);
      ctx.fillStyle = th.ground; roundRect(ctx, 0, 0, WW, WH, 40); ctx.fill();
      // Hoa văn lục giác chấm nhẹ
      ctx.fillStyle = 'rgba(0,0,0,.06)';
      const x0 = Math.max(0, Math.floor(cam.x / 48) * 48), y0 = Math.max(0, Math.floor(cam.y / 42) * 42);
      for (let y = y0; y < Math.min(WH, cam.y + H + 42); y += 42) for (let x = x0 + ((y / 42) % 2) * 24; x < Math.min(WW, cam.x + W + 48); x += 48) { ctx.beginPath(); ctx.arc(x, y, 5, 0, 7); ctx.fill(); }
      ctx.strokeStyle = '#e03131'; ctx.lineWidth = 8; ctx.setLineDash([24, 16]); roundRect(ctx, 0, 0, WW, WH, 40); ctx.stroke(); ctx.setLineDash([]);
      for (const f of foods) {
        if (f.x < cam.x - 30 || f.x > cam.x + W + 30 || f.y < cam.y - 30 || f.y > cam.y + H + 30) continue;
        f.ph += .05;
        if (f.k) draw(ctx, f.k, f.x, f.y + Math.sin(f.ph) * 3, 38, 38, {rot: Math.sin(f.ph * .7) * .2});
        else { ctx.fillStyle = f.c; ctx.globalAlpha = .35; ctx.beginPath(); ctx.arc(f.x, f.y, 11, 0, 7); ctx.fill(); ctx.globalAlpha = 1; ctx.beginPath(); ctx.arc(f.x, f.y, 6 + Math.sin(f.ph * 2) * 1.2, 0, 7); ctx.fill(); }
      }
      const drawSnake = (sn, blink) => {
        if (blink) return;
        const pts = segs(sn), n = pts.length;
        if (n < 2) return;
        // Thân là ống trơn: bóng đổ, viền đậm, thân sáng, vạch vảy, dải sáng lưng; đuôi thon dần
        const path = (from, to) => { ctx.beginPath(); ctx.moveTo(pts[from][0], pts[from][1]); for (let i = from + 1; i <= to; i++) ctx.lineTo(pts[i][0], pts[i][1]); };
        ctx.lineCap = 'round'; ctx.lineJoin = 'round';
        const parts = [[0, Math.floor(n * .6), 1], [Math.floor(n * .6), Math.floor(n * .85), .8], [Math.floor(n * .85), n - 1, .6]];
        for (const [a, b, k] of parts) { if (b <= a) continue; path(a, b); ctx.strokeStyle = 'rgba(0,0,0,.18)'; ctx.lineWidth = sn.r * 2.1 * k; ctx.save(); ctx.translate(3, 5); ctx.stroke(); ctx.restore(); }
        for (const [a, b, k] of parts) { if (b <= a) continue; path(a, b); ctx.strokeStyle = sn.skin[1]; ctx.lineWidth = sn.r * 2 * k; ctx.stroke(); }
        for (const [a, b, k] of parts) { if (b <= a) continue; path(a, b); ctx.strokeStyle = sn.skin[0]; ctx.lineWidth = sn.r * 1.5 * k; ctx.stroke(); }
        // Vảy: chấm đậm xen kẽ dọc thân
        ctx.fillStyle = sn.skin[1];
        for (let i = 3; i < n - 2; i += 3) { const [x, y] = pts[i], rr = sn.r * (i > n * .85 ? .6 : i > n * .6 ? .8 : 1); ctx.beginPath(); ctx.arc(x, y, rr * .38, 0, 7); ctx.fill(); }
        path(0, Math.floor(n * .85)); ctx.strokeStyle = 'rgba(255,255,255,.35)'; ctx.lineWidth = sn.r * .35; ctx.save(); ctx.translate(-sn.r * .25, -sn.r * .3); ctx.stroke(); ctx.restore();
        // Đầu to hơn thân, nuốt mồi thì phồng
        const gulp = sn.gulp > 0 ? Math.sin(sn.gulp / .25 * Math.PI) * .25 : 0;
        ctx.fillStyle = sn.skin[1]; ctx.beginPath(); ctx.ellipse(sn.x, sn.y, sn.r * (1.25 + gulp), sn.r * (1.1 + gulp), sn.a, 0, 7); ctx.fill();
        ctx.fillStyle = sn.skin[0]; ctx.beginPath(); ctx.ellipse(sn.x - Math.cos(sn.a) * sn.r * .05, sn.y - Math.sin(sn.a) * sn.r * .05, sn.r * (1.08 + gulp), sn.r * (.92 + gulp), sn.a, 0, 7); ctx.fill();
        if (sn.boost > 0) { ctx.strokeStyle = 'rgba(255,212,59,.7)'; ctx.lineWidth = 4; ctx.beginPath(); ctx.arc(sn.x, sn.y, sn.r * 1.4, 0, 7); ctx.stroke(); }
        // Đầu: mắt to nhìn theo hướng bò, lưỡi thè ra
        const r = sn.r * 1.05, c = Math.cos(sn.a), s2 = Math.sin(sn.a);
        if (Math.sin(t * 6 + sn.len) > .3) { ctx.strokeStyle = '#ff4d6d'; ctx.lineWidth = 3; ctx.beginPath(); ctx.moveTo(sn.x + c * r, sn.y + s2 * r); ctx.lineTo(sn.x + c * r * 1.7, sn.y + s2 * r * 1.7); ctx.stroke(); }
        for (const k of [-1, 1]) {
          const ex = sn.x + c * r * .35 - s2 * r * .5 * k, ey = sn.y + s2 * r * .35 + c * r * .5 * k;
          ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.arc(ex, ey, r * .42, 0, 7); ctx.fill();
          ctx.fillStyle = '#212529'; ctx.beginPath(); ctx.arc(ex + c * r * .14, ey + s2 * r * .14, r * .24, 0, 7); ctx.fill();
          ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.arc(ex + c * r * .06 - r * .08, ey + s2 * r * .06 - r * .08, r * .08, 0, 7); ctx.fill();
        }
        ctx.fillStyle = 'rgba(255,110,140,.45)'; for (const k of [-1, 1]) { ctx.beginPath(); ctx.arc(sn.x - c * r * .1 - s2 * r * .75 * k, sn.y - s2 * r * .1 + c * r * .75 * k, r * .18, 0, 7); ctx.fill(); }
      };
      for (const b of bots) drawSnake(b, false);
      drawSnake(me, inv > 0 && Math.floor(inv * 8) % 2);
      SD.draw(ctx);
      ctx.restore();
      F.draw(ctx);
      hud(ctx, W, {score, lives: 0, time: null});
      for (let i = 0; i < 3; i++) draw(ctx, 'Red heart', W - 40 - i * 36, 32, 30, 30, {alpha: i < lives ? 1 : .22});
      goalPill(ctx, W, score, need, 16);
      if (t < 2) levelBanner(ctx, W, H, lv, `Ăn ${need} hạt`, 'Kéo ngón tay để rắn bò theo · Chạm 2 lần để tăng tốc · Đừng đâm vào rắn khác');
      if (end) banner(ctx, W, H, endText(end.win, lv), `${score}/${need} hạt`);
    }
  }, opts.alive);
}

// ---------- 2. Bắn bia: bia, quái hiện lên di chuyển; chạm để bắn, đừng bắn bạn thỏ ----------
export async function gallery(box, opts) {
  const lv = opts.level || 0, th = theme(lv), need = Math.round(14 + lv * .9), TIME = 40;
  const BAD = ['Bullseye', 'Alien monster', 'Ghost', 'Balloon', 'Bat'], GOOD = ['Rabbit face', 'Baby chick'];
  const [[gs, en, an, fxs]] = await Promise.all([sheets(['gallery/gallery', 'plat/enemies', 'animals/round', 'fxa/fx']), loadAll([...BAD, ...GOOD, 'Collision', 'Glowing star', 'Coin', 'Alarm clock', ...themeImgs(lv)])]);
  const {cv, ctx, W, H} = canvasIn(box);
  const S = Math.min(W, H), F = fx(), D = dust(200), B = booms(fxs, 16), SH = shaker();
  // Quầy bắn bia Kenney: bia tròn, vịt gỗ có hồng tâm, ong bay; bạn thỏ/gà con là hình thú tròn
  const LOOK = {'Bullseye': 'target_red1_outline', 'Alien monster': 'duck_outline_target_yellow', 'Ghost': 'duck_outline_target_white'};
  const FRIEND = {'Rabbit face': 'rabbit', 'Baby chick': 'chick'};
  const holes = Array.from({length: 12}, () => ({x: 0, y: 0, t: 0})); let holeI = 0, aim = null;
  const lanes = [H * .3, H * .5, H * .7];
  const targets = [];
  let score = 0, t = 0, spawn = .5, end = null, endT = 0, shot = null, combo = 0, bonusT = 0;
  const sp = ramp(lv, 120, 300);
  cv.addEventListener('pointerdown', e => {
    if (end || t < 2) return;
    const [x, y] = local(cv, e);
    shot = {x, y, t: .18}; sfx('shoot'); SH.add(2.5); aim = {x, y};
    const hl = holes[holeI]; holeI = (holeI + 1) % holes.length; hl.x = x; hl.y = y; hl.t = 1.2;
    const tg = targets.find(o => !o.dead && Math.hypot(o.x - x, o.y - y) < o.s * .55);
    if (!tg) { combo = 0; return; }
    tg.dead = .4;
    if (GOOD.includes(tg.k)) { score = Math.max(0, score - 3); combo = 0; sfx('wrong'); F.text(tg.x, tg.y - 40, 'Ối! Bạn mà!', '#ff6b6b'); return; }
    if (tg.k === 'Alarm clock') { bonusT += 5; sfx('power'); F.text(tg.x, tg.y - 40, '+5 giây', '#4dabf7'); return; }
    combo++; const p = (tg.k === 'Bullseye' ? 3 : tg.k === 'Bat' ? 2 : 1) + (combo >= 5 ? 1 : 0);
    score += p; sfx('boom'); D.sparks(tg.x, tg.y, 12, '#ffe066', 260); D.debris(tg.x, tg.y, 6, '#c08552', 220); F.text(tg.x, tg.y - 40, '+' + p, '#ffd43b');
  });
  return loop({
    update(dt) {
      t += dt; F.update(dt); D.update(dt); B.update(dt); SH.update(dt);
      for (const hl of holes) hl.t = Math.max(0, hl.t - dt);
      if (end) { endT += dt; return endT > 2 ? end : null; }
      if (t < 2) return null;
      if (shot) { shot.t -= dt; if (shot.t <= 0) shot = null; }
      spawn -= dt;
      if (spawn <= 0) {
        spawn = rand(.45, .9) * ramp(lv, 1.1, .6);
        const lane = Math.floor(rand(0, 3)), dir = lane % 2 ? -1 : 1, r = Math.random();
        const k = r < ramp(lv, .12, .25) ? pick(GOOD) : r > .97 ? 'Alarm clock' : pick(BAD);
        const s = S * (k === 'Bullseye' ? ramp(lv, .14, .1) : .13);
        targets.push({k, x: dir > 0 ? -s : W + s, y: lanes[lane], y0: lanes[lane], v: dir * sp * rand(.8, 1.3), s, ph: rand(0, 6), dead: 0, wob: lv >= 15 && Math.random() < .5});
      }
      for (let i = targets.length - 1; i >= 0; i--) {
        const o = targets[i]; o.ph += dt;
        if (o.dead) { o.dead -= dt; if (o.dead <= 0) targets.splice(i, 1); continue; }
        o.x += o.v * dt; if (o.wob) o.y = o.y0 + Math.sin(o.ph * 3) * S * .06;
        if (o.x < -S * .3 || o.x > W + S * .3) targets.splice(i, 1);
      }
      if (t - 2 >= TIME + bonusT) { end = {win: score >= need, score}; sfx(score >= need ? 'win' : 'pop'); }
      return null;
    },
    draw() {
      ctx.save(); SH.apply(ctx);
      // Quầy bắn bia: nền ván gỗ, cây + mây gỗ trôi chậm, mỗi làn là dải cỏ/nước gợn sóng chạy ngang
      if (gs) tile(ctx, gs, 'bg_wood', Math.min(256, S * .35), 0, 0, -10, -10, W + 20, H + 20); else sky(ctx, W, H, th);
      for (let k = 0; k < 3; k++) spr(ctx, gs, k % 2 ? 'cloud2' : 'cloud1', ((k * W * .45 + t * 14) % (W + 300)) - 150, H * .14 + k * 18, S * .1);
      for (let k = 0; k < 5; k++) spr(ctx, gs, k % 2 ? 'tree_pine' : 'tree_oak', (k + .5) * W / 5, lanes[0] - S * .02, S * .2, {alpha: .9});
      const laneH = S * .09;
      lanes.forEach((y, i) => {
        const wave = Math.sin(t * 2 + i) * 4;
        stripX(ctx, gs, i % 2 ? 'water1' : 'grass1', (i % 2 ? -1 : 1) * t * 40, y + S * .055 + wave, laneH, W);
      });
      for (const o of targets) {
        const bob = Math.sin(o.ph * 5) * 3;
        if (o.dead) {
          // Bị bắn: lật ra sau rồi rơi xuống
          const k = 1 - o.dead / .4;
          if (GOOD.includes(o.k)) { spr(ctx, an, FRIEND[o.k], o.x, o.y + bob, o.s, {rot: Math.sin(k * 30) * .3}); continue; }
          ctx.save(); ctx.translate(o.x, o.y + k * k * S * .15); ctx.scale(Math.cos(k * Math.PI), 1);
          spr(ctx, gs, Math.cos(k * Math.PI) < 0 ? 'target_back_outline' : (LOOK[o.k] || 'target_white_outline'), 0, 0, o.s, {alpha: 1 - k * .6});
          ctx.restore(); continue;
        }
        spr(ctx, gs, 'stick_wood_outline', o.x, o.y + S * .07 + bob, S * .14);
        if (LOOK[o.k]) spr(ctx, gs, LOOK[o.k], o.x, o.y + bob, o.s, {flip: o.v < 0 && o.k !== 'Bullseye'});
        else if (o.k === 'Bat') anim(ctx, en, 'bee', o.ph, o.x, o.y + bob, o.s * .9, {flip: o.v > 0});
        else if (FRIEND[o.k]) spr(ctx, an, FRIEND[o.k], o.x, o.y + bob, o.s, {rot: Math.sin(o.ph * 3) * .1});
        else draw(ctx, o.k, o.x, o.y + bob, o.s, o.s, {rot: Math.sin(o.ph * 3) * .15});
      }
      // Rèm sân khấu trên và hai bên
      stripX(ctx, gs, 'curtain_top', 0, -4, S * .1, W);
      spr(ctx, gs, 'curtain', S * .05, H * .3, H * .6, {alpha: .95}); spr(ctx, gs, 'curtain', W - S * .05, H * .3, H * .6, {flip: true, alpha: .95});
      for (const hl of holes) if (hl.t > 0) spr(ctx, gs, 'shot_brown_large', hl.x, hl.y, 16, {alpha: Math.min(1, hl.t * 2)});
      D.draw(ctx);
      if (aim) spr(ctx, gs, 'crosshair', aim.x, aim.y, 50 * (shot ? 1 + shot.t * 2 : 1), {alpha: .85});
      ctx.restore();
      F.draw(ctx);
      hud(ctx, W, {score, lives: 0, time: Math.max(0, TIME + bonusT - Math.max(0, t - 2))});
      goalPill(ctx, W, score, need);
      if (t < 2) levelBanner(ctx, W, H, lv, `Bắn được ${need} điểm`, 'Chạm vào bia và quái vật · Đừng bắn bạn thỏ, gà con');
      if (end) banner(ctx, W, H, endText(end.win, lv), `${score}/${need} điểm`);
    }
  }, opts.alive);
}

// ---------- 3. Xe tăng: đợt 17 tách sang funtank.js (hệ vũ khí, skill, xưởng xe tăng, kho đồ giữ qua màn) ----------
export {tank} from './funtank.js?v=4c51d34a6e';

// ---------- 4. Xếp gạch: khối rơi, nút ← ⟳ → ⤓, xoá hàng ----------
const SHAPES = [[[1, 1, 1, 1]], [[1, 1], [1, 1]], [[0, 1, 0], [1, 1, 1]], [[1, 0, 0], [1, 1, 1]], [[0, 0, 1], [1, 1, 1]], [[1, 1, 0], [0, 1, 1]], [[0, 1, 1], [1, 1, 0]]];
const SCOL = ['#4dabf7', '#ffd43b', '#b197fc', '#ff922b', '#339af0', '#ff6b6b', '#51cf66'];
export async function blocks(box, opts) {
  const lv = opts.level || 0, th = theme(lv), need = Math.min(30, 3 + Math.floor(lv * .4));
  const [[pz]] = await Promise.all([sheets(['puzzle/puzzle']), loadAll(['Glowing star', 'Coin'])]);
  // Ô kẹo bóng Kenney theo màu khối
  const PZ = {'#4dabf7': 'sq_cyan', '#ffd43b': 'sq_yellow', '#b197fc': 'sq_purple', '#ff922b': 'sq_orange', '#339af0': 'sq_blue', '#ff6b6b': 'sq_red', '#51cf66': 'sq_green', '#adb5bd': 'sq_grey'};
  const D = dust(200), SH = shaker(), flashes = []; let lockT = 0, lockCells = [];
  const {cv, ctx, W, H} = canvasIn(box);
  const C = 10, Rr = 18, btnH = Math.min(90, H * .12), cs = Math.floor(Math.min((W * .62) / C, (H - (W < 640 ? 130 : 90) - btnH) / Rr));
  const ox = Math.round((W - C * cs) / 2), oy = W < 640 ? 108 : 70;
  // Cấp thấp chỉ dùng khối dễ (I, O, T, L); có sẵn vài hàng rác ở cấp cao.
  const pool = lv < 6 ? [0, 1, 2, 3] : [0, 1, 2, 3, 4, 5, 6];
  const grid = Array.from({length: Rr}, () => Array(C).fill(0));
  const junk = lv < 15 ? 0 : Math.min(6, Math.floor((lv - 10) / 8));
  for (let r = Rr - junk; r < Rr; r++) { const hole = Math.floor(rand(0, C)); for (let c = 0; c < C; c++) if (c !== hole && Math.random() < .8) grid[r][c] = '#adb5bd'; }
  const F = fx();
  let cur, nextK = pick(pool), lines = 0, score = 0, t = 0, fall = 0, end = null, endT = 0, drop = false;
  const fits = (m, x, y) => m.every((row, i) => row.every((v, j) => !v || (x + j >= 0 && x + j < C && y + i < Rr && (y + i < 0 || !grid[y + i][x + j]))));
  const spawn = () => {
    const k = nextK; nextK = pick(pool);
    cur = {m: SHAPES[k], c: SCOL[k], x: Math.floor((C - SHAPES[k][0].length) / 2), y: -1};
    if (!fits(cur.m, cur.x, cur.y + 1)) { end = {win: false, score}; sfx('wrong'); }
  };
  spawn();
  const rot = m => m[0].map((_, j) => m.map(row => row[j]).reverse());
  const btns = [['←', () => { if (fits(cur.m, cur.x - 1, cur.y)) { cur.x--; sfx('tap'); } }], ['⟳', () => { const r = rot(cur.m); for (const k of [0, -1, 1, -2, 2]) if (fits(r, cur.x + k, cur.y)) { cur.m = r; cur.x += k; sfx('tap'); break; } }],
    ['→', () => { if (fits(cur.m, cur.x + 1, cur.y)) { cur.x++; sfx('tap'); } }], ['⬇', () => { drop = true; }]];
  let pressI = -1, pressT = 0;
  const bw = Math.min(140, (W - 40) / 4 - 12), by = H - btnH - 10;
  const bx = i => W / 2 + (i - 1.5) * (bw + 12) - bw / 2;
  cv.addEventListener('pointerdown', e => {
    if (end || t < 2 || !cur) return;
    const [x, y] = local(cv, e);
    if (y > by - 10) { const i = btns.findIndex((_, i) => x >= bx(i) && x <= bx(i) + bw); if (i >= 0) { btns[i][1](); pressI = i; pressT = .15; } return; }
    // Chạm lên bảng: chạm bên trái/phải khối để dời, chạm vào khối để xoay
    const cx = ox + (cur.x + cur.m[0].length / 2) * cs;
    if (Math.abs(x - cx) < cs * 1.5) btns[1][1](); else if (x < cx) btns[0][1](); else btns[2][1]();
  });
  const lock = () => {
    lockCells = [];
    cur.m.forEach((row, i) => row.forEach((v, j) => { if (v && cur.y + i >= 0) { grid[cur.y + i][cur.x + j] = cur.c; lockCells.push([cur.x + j, cur.y + i]); } }));
    lockT = .2; if (drop) { SH.add(4); for (const [x, y] of lockCells) D.puff(ox + (x + .5) * cs, oy + (y + 1) * cs, 1, 'rgba(255,255,255,1)', 50, cs * .2); }
    if (cur.y < 0) { end = {win: false, score}; return; }
    let n = 0;
    for (let r = Rr - 1; r >= 0; r--) if (grid[r].every(Boolean)) {
      // Hàng xoá: loé sáng + vụn kẹo bắn ra
      flashes.push({y: r + n, t: .35}); for (let c = 0; c < C; c++) D.debris(ox + (c + .5) * cs, oy + (r + .5) * cs, 2, grid[r][c], 220);
      grid.splice(r, 1); grid.unshift(Array(C).fill(0)); n++; r++;
    }
    if (n) { SH.add(3 + n * 2); lockCells = []; }
    if (n) { lines += n; score += [0, 1, 3, 6, 10][n]; sfx(n > 1 ? 'win' : 'coin'); F.text(W / 2, oy + Rr * cs / 2, n > 1 ? `${n} HÀNG!` : '+1 hàng', '#ffd43b'); F.burst(W / 2, oy + Rr * cs / 2, 20); }
    else sfx('pop');
    drop = false;
    if (lines >= need) { end = {win: true, score: score + 10}; sfx('win'); return; }
    spawn();
  };
  return loop({
    update(dt) {
      t += dt; F.update(dt); D.update(dt); SH.update(dt); lockT = Math.max(0, lockT - dt); pressT = Math.max(0, pressT - dt);
      for (let i = flashes.length - 1; i >= 0; i--) { flashes[i].t -= dt; if (flashes[i].t <= 0) flashes.splice(i, 1); }
      if (end) { endT += dt; return endT > 2 ? end : null; }
      if (t < 2) return null;
      fall += dt;
      const sp = drop ? .03 : ramp(lv, .75, .22);
      if (fall >= sp) { fall = 0; if (fits(cur.m, cur.x, cur.y + 1)) cur.y++; else lock(); }
      return null;
    },
    draw() {
      sky(ctx, W, H, th);
      ctx.save(); SH.apply(ctx);
      ctx.fillStyle = 'rgba(20,30,50,.85)'; roundRect(ctx, ox - 8, oy - 8, C * cs + 16, Rr * cs + 16, 14); ctx.fill();
      ctx.fillStyle = 'rgba(255,255,255,.04)'; for (let x = 1; x < C; x += 2) ctx.fillRect(ox + x * cs, oy, cs, Rr * cs);
      const cell = (x, y, c, k = 1) => {
        const px = ox + (x + .5) * cs, py = oy + (y + .5) * cs;
        if (pz && PZ[c]) sprBox(ctx, pz, PZ[c], px, py, (cs - 1) * k, (cs - 1) * k);
        else { ctx.fillStyle = c; roundRect(ctx, ox + x * cs + 1, oy + y * cs + 1, cs - 2, cs - 2, 5); ctx.fill(); ctx.fillStyle = 'rgba(255,255,255,.3)'; ctx.fillRect(ox + x * cs + 4, oy + y * cs + 3, cs - 8, 4); }
      };
      const lk = lockT > 0 ? 1 + Math.sin(lockT / .2 * Math.PI) * .1 : 1;
      grid.forEach((row, y) => row.forEach((c, x) => { if (c) cell(x, y, c, lockCells.some(p => p[0] === x && p[1] === y) ? lk : 1); }));
      for (const f of flashes) { ctx.fillStyle = `rgba(255,255,255,${f.t / .35 * .9})`; const k = 1 + (1 - f.t / .35) * .3; ctx.fillRect(ox - 6 * k, oy + f.y * cs - cs * (k - 1) / 2, C * cs + 12 * k, cs * k); }
      if (cur && !end) {
        let gy = cur.y; while (fits(cur.m, cur.x, gy + 1)) gy++;
        // Rơi mượt: vẽ khối lệch dần xuống theo thời gian tới bước rơi kế tiếp (không vượt bóng đổ)
        const sp = drop ? .03 : ramp(lv, .75, .22), fy = Math.min(gy, cur.y + Math.min(1, fall / sp) * (fits(cur.m, cur.x, cur.y + 1) ? 1 : 0));
        cur.m.forEach((row, i) => row.forEach((v, j) => { if (v && gy + i >= 0) { ctx.strokeStyle = 'rgba(255,255,255,.35)'; ctx.lineWidth = 2; ctx.strokeRect(ox + (cur.x + j) * cs + 3, oy + (gy + i) * cs + 3, cs - 6, cs - 6); } }));
        cur.m.forEach((row, i) => row.forEach((v, j) => { if (v && fy + i >= -.5) cell(cur.x + j, fy + i, cur.c); }));
      }
      D.draw(ctx);
      ctx.restore();
      // Khối kế tiếp
      const nx = ox + C * cs + 24;
      if (nx + 90 < W) { ctx.fillStyle = 'rgba(0,0,0,.25)'; roundRect(ctx, nx, oy, 96, 80, 14); ctx.fill(); SHAPES[nextK].forEach((row, i) => row.forEach((v, j) => { if (v) { if (pz) sprBox(ctx, pz, PZ[SCOL[nextK]], nx + 20 + j * 18, oy + 26 + i * 18, 17, 17); else { ctx.fillStyle = SCOL[nextK]; ctx.fillRect(nx + 12 + j * 18, oy + 18 + i * 18, 16, 16); } } })); }
      btns.forEach(([l], i) => { const pk = i === pressI && pressT > 0 ? 4 : 0; ctx.fillStyle = 'rgba(0,0,0,.2)'; roundRect(ctx, bx(i), by + 5, bw, btnH, 22); ctx.fill(); ctx.save(); ctx.translate(0, pk); ctx.fillStyle = '#fff'; roundRect(ctx, bx(i), by, bw, btnH, 22); ctx.fill(); ctx.fillStyle = '#212529'; ctx.font = `800 ${btnH * .5}px "Baloo 2", sans-serif`; ctx.textAlign = 'center'; ctx.fillText(l, bx(i) + bw / 2, by + btnH * .68); ctx.restore(); });
      F.draw(ctx);
      hud(ctx, W, {score, lives: 0, time: null});
      goalPill(ctx, W, lines, need, 16);
      if (t < 2) levelBanner(ctx, W, H, lv, `Xoá ${need} hàng`, 'Chạm nút để dời, xoay, thả nhanh');
      if (end) banner(ctx, W, H, end.win ? endText(true, lv) : 'ĐẦY RỒI!', `${lines}/${need} hàng`);
    }
  }, opts.alive);
}

// ---------- 5. Nhảy mây: tự bật nhảy, kéo trái phải để đáp lên mây, lên thật cao ----------
export async function jumper(box, opts) {
  const lv = opts.level || 0, th = theme(lv), need = Math.round(ramp(lv, 60, 400));  // mét
  const [[tl, en, fxs]] = await Promise.all([sheets(['plat/tiles', 'plat/enemies', 'fxa/fx']), loadAll([opts.hero, 'Cloud', 'Glowing star', 'Coin', 'Bat', 'Rocket', 'Ghost', ...themeImgs(lv)])]);
  const {cv, ctx, W, H} = canvasIn(box);
  const S = Math.min(W, H), F = fx(), G = S * 2.6, JUMP = -S * 1.55, D = dust(200), SH = shaker();
  let land = 0, bits = [];
  const me = {x: W / 2, y: H * .7, vy: JUMP, w: S * .12, tx: W / 2, rocket: 0};
  const plats = [], coins = [], foes = [];
  let camY = 0, best = 0, t = 0, end = null, endT = 0, coinN = 0, topY = H;
  const gap = () => S * ramp(lv, .16, .27);
  const add = y => {
    const r = Math.random(), w = S * ramp(lv, .28, .18);
    const kind = lv >= 8 && r < ramp(lv, .1, .35) ? 'move' : lv >= 20 && r > 1 - ramp(lv, 0, .18) ? 'break' : 'cloud';
    plats.push({x: rand(w / 2, W - w / 2), y, w, kind, v: rand(60, 140) * (Math.random() < .5 ? -1 : 1), gone: false});
    if (Math.random() < .3) coins.push({x: rand(30, W - 30), y: y - S * .1});
    if (lv >= 12 && Math.random() < ramp(lv, .03, .12)) foes.push({x: rand(40, W - 40), y: y - S * .2, ph: rand(0, 6), k: pick(['Bat', 'Ghost'])});
    if (Math.random() < .015) coins.push({x: rand(30, W - 30), y: y - S * .15, rocket: true});
  };
  plats.push({x: W / 2, y: H * .85, w: W, kind: 'ground'});
  for (let y = H * .85 - gap(); y > -H; y -= gap() * rand(.8, 1.1)) add(y), topY = y;
  const steer = e => { me.tx = local(cv, e)[0]; };
  cv.addEventListener('pointerdown', e => { cv.setPointerCapture(e.pointerId); steer(e); });
  cv.addEventListener('pointermove', e => { if (e.buttons || e.pointerType !== 'mouse') steer(e); });
  const height = () => Math.max(0, Math.round((H * .7 - me.y) / (S * .1)));
  return loop({
    update(dt) {
      t += dt; F.update(dt);
      if (end) { endT += dt; return endT > 2 ? end : null; }
      if (t < 2) return null;
      me.x += (me.tx - me.x) * Math.min(1, dt * 8);
      D.update(dt); SH.update(dt); land = Math.max(0, land - dt);
      for (const p of plats) if (p.dip) p.dip = Math.max(0, p.dip - dt);
      for (let i = bits.length - 1; i >= 0; i--) { const b = bits[i]; b.vy += G * dt; b.y += b.vy * dt; b.r += b.vr * dt; if (b.y > camY + H + 100) bits.splice(i, 1); }
      if (me.rocket > 0) { me.rocket -= dt; me.vy = JUMP * 1.4; if (Math.random() < .9) D.emit(me.x + rand(-6, 6), me.y + me.w * .1, rand(-30, 30), rand(150, 260), {life: .35, r: 5, grow: 8, c: Math.random() < .5 ? '#ff922b' : '#ffd43b', a: .9}); }
      else me.vy += G * dt;
      const prevY = me.y; me.y += me.vy * dt;
      if (me.vy > 0) for (const p of plats) {
        if (p.gone || Math.abs(me.x - p.x) > p.w / 2 + me.w * .2) continue;
        if (prevY <= p.y && me.y >= p.y) {
          if (p.kind === 'break') { p.gone = true; sfx('pop'); D.debris(p.x, p.y, 10, '#c08552', 220); bits.push({x: p.x - p.w / 4, y: p.y, vy: 0, r: 0, vr: -2, w: p.w / 2}, {x: p.x + p.w / 4, y: p.y, vy: 0, r: 0, vr: 2, w: p.w / 2}); continue; }
          me.y = p.y; me.vy = JUMP; sfx('jump'); land = .2; p.dip = .3; D.puff(me.x, p.y, 4, 'rgba(255,255,255,1)', 60, 6); break;
        }
      }
      for (const p of plats) if (p.kind === 'move') { p.x += p.v * dt; if (p.x < p.w / 2 || p.x > W - p.w / 2) p.v *= -1; }
      for (let i = coins.length - 1; i >= 0; i--) { const c = coins[i]; if (Math.hypot(c.x - me.x, c.y - me.y + me.w / 2) < me.w * .7) { coins.splice(i, 1); if (c.rocket) { me.rocket = 2.5; sfx('power'); SH.add(4); } else { coinN++; sfx('coin'); D.sparks(c.x, c.y, 6, '#ffe066', 160); } } }
      for (const f of foes) { f.ph += dt; f.x += Math.sin(f.ph) * 60 * dt; if (me.rocket <= 0 && Math.hypot(f.x - me.x, f.y - me.y + me.w / 2) < me.w * .6) { if (me.vy > 0) { me.vy = JUMP; sfx('boom'); D.sparks(f.x, f.y, 12, '#ffe066', 260); SH.add(5); land = .2; f.y = 1e9; } else { end = {win: false, score: best + coinN}; sfx('hit'); SH.add(10); } } }
      // Camera theo bé đi lên
      const want = Math.min(camY, me.y - H * .45);
      camY += (want - camY) * Math.min(1, dt * 5);
      while (topY > camY - H * .3) { topY -= gap() * rand(.8, 1.1); add(topY); }
      for (let i = plats.length - 1; i >= 0; i--) if (plats[i].y > camY + H + 80) plats.splice(i, 1);
      best = Math.max(best, height());
      if (me.y > camY + H + me.w) { end = {win: false, score: best + coinN}; sfx('wrong'); }
      if (best >= need) { end = {win: true, score: best + coinN * 2}; sfx('win'); }
      return null;
    },
    draw() {
      const k = Math.min(1, best / Math.max(need, 1));
      const g = ctx.createLinearGradient(0, 0, 0, H); g.addColorStop(0, k > .6 ? '#364fc7' : th.sky[0]); g.addColorStop(1, th.sky[1]); ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
      draw(ctx, th.sun, W * .86, H * .12, S * .12);
      // Mây nền trôi chậm theo độ cao (parallax)
      for (let k = 0; k < 5; k++) draw(ctx, 'Cloud', ((k * 211 + t * 8) % (W + 160)) - 80, ((k * 173 - camY * .3) % (H + 120) + H + 120) % (H + 120) - 60, 90 + k * 12, (90 + k * 12) * .6, {alpha: .55});
      ctx.save(); SH.apply(ctx); ctx.translate(0, -camY);
      // Bục mây/đảo nổi Kenney: đầu trái + giữa lặp + đầu phải; nhún xuống khi bé đáp
      const plat = (p, kind) => {
        const hh = Math.max(26, S * .055), n = Math.max(0, Math.round((p.w - hh * 2) / hh)), w = hh * (n + 2), x0 = p.x - w / 2, y = p.y - hh * .2 + (p.dip ? Math.sin(p.dip / .3 * Math.PI) * 8 : 0);
        const g = kind === 'move' ? 'purple' : kind === 'break' ? 'dirt' : 'grass';
        spr(ctx, tl, `terrain_${g}_cloud_left`, x0 + hh / 2, y + hh / 2, hh);
        for (let i = 0; i < n; i++) spr(ctx, tl, `terrain_${g}_cloud_middle`, x0 + hh * (i + 1.5), y + hh / 2, hh);
        spr(ctx, tl, `terrain_${g}_cloud_right`, x0 + w - hh / 2, y + hh / 2, hh);
      };
      for (const p of plats) {
        if (p.gone) continue;
        if (p.kind === 'ground') { ctx.fillStyle = th.ground; ctx.fillRect(0, p.y, W, H); ctx.fillStyle = th.edge; ctx.fillRect(0, p.y, W, 8); continue; }
        if (tl) plat(p, p.kind); else draw(ctx, 'Cloud', p.x, p.y + 8, p.w * 1.1, p.w * .45);
      }
      for (const b of bits) { ctx.save(); ctx.translate(b.x, b.y); ctx.rotate(b.r); spr(ctx, tl, 'terrain_dirt_cloud_middle', 0, 0, Math.max(26, S * .055)); ctx.restore(); }
      for (const c of coins) { if (c.rocket) draw(ctx, 'Rocket', c.x, c.y + Math.sin(t * 4 + c.x) * 4, 44, 44, {rot: Math.sin(t * 3) * .2}); else coin(ctx, fxs, t + c.x * .01, c.x, c.y, 32); }
      for (const f of foes) anim(ctx, en, f.k === 'Bat' ? 'bee' : 'fly', t + f.ph, f.x, f.y, S * .1, {flip: Math.cos(f.ph) > 0});
      D.draw(ctx);
      // Bé: kéo dài khi bật lên, nén lại khi đáp
      const sq = land > 0 ? Math.sin(land / .2 * Math.PI) * .18 : 0, st = me.vy < 0 ? Math.min(.12, -me.vy / (S * 12)) : 0;
      ctx.save(); ctx.translate(me.x, me.y); ctx.scale(1 + sq - st * .5, 1 - sq + st); ctx.translate(-me.x, -me.y);
      drawFigure(ctx, me.x, me.y, me.w * 1.35, {c: heroOf(opts.hero), pose: me.vy < 0 ? 'jump' : 'cheer', t, face: me.tx < me.x - 2 ? -1 : 1});
      ctx.restore();
      F.draw(ctx);
      ctx.restore();
      hud(ctx, W, {score: coinN, lives: 0, time: null});
      ctx.fillStyle = 'rgba(0,0,0,.28)'; roundRect(ctx, W / 2 - 80, 10, 160, 44, 22); ctx.fill();
      ctx.fillStyle = '#fff'; ctx.textAlign = 'center'; ctx.font = '800 26px "Baloo 2", sans-serif'; ctx.fillText(`⬆ ${best}/${need} m`, W / 2, 42);
      if (t < 2) levelBanner(ctx, W, H, lv, `Lên cao ${need} mét`, 'Kéo ngón tay sang trái, phải để đáp lên mây');
      if (end) banner(ctx, W, H, end.win ? endText(true, lv) : 'RƠI MẤT RỒI!', `${best}/${need} mét`);
    }
  }, opts.alive);
}
