// Kho game vui nhộn: Hứng trái cây, Đập quái vật, Câu cá, Xây tháp, Phá gạch, Chim bay. Canvas, mỗi lượt khoảng 1 phút.
// Mỗi lượt là một cấp (opts.level): đạt mục tiêu thì thắng và lên cấp; cấp cao chạy nhanh hơn, mục tiêu cao hơn, đổi cảnh mỗi 10 cấp.
import {sfx} from '../audio.js?v=4c51d34a6e';
import {banner, canvasIn, draw, endText, fx, goalPill, hit, hud, levelBanner, loadAll, loop, pick, rand, ramp, roundRect, theme, themeImgs} from './funcore.js?v=4c51d34a6e';
import {drawFigure, heroOf} from './figure.js?v=4c51d34a6e';
import {anim, approach, aspect, backHills, booms, dust, easeOutBack, groundTiles, shaker, sheets, spr, sprBox, sprW, coin} from './funfx.js?v=4c51d34a6e';

const pointer = (cv, fn) => e => { const r = cv.getBoundingClientRect(); fn(e.clientX - r.left, e.clientY - r.top, e); };
const HEARTS = 3;
function hearts(ctx, W, n) { for (let i = 0; i < HEARTS; i++) draw(ctx, 'Red heart', W - 40 - i * 36, 32, 30, 30, {alpha: i < n ? 1 : .22}); }
function timer(ctx, W, time) {
  ctx.fillStyle = 'rgba(0,0,0,.28)'; roundRect(ctx, W / 2 - 50, 10, 100, 44, 22); ctx.fill();
  ctx.fillStyle = '#fff'; ctx.textAlign = 'center'; ctx.font = '800 28px "Baloo 2", sans-serif'; ctx.fillText(`⏱ ${Math.ceil(time)}`, W / 2, 42);
}
function sky(ctx, W, H, a = '#74c0fc', b = '#e7f5ff') { const g = ctx.createLinearGradient(0, 0, 0, H); g.addColorStop(0, a); g.addColorStop(1, b); ctx.fillStyle = g; ctx.fillRect(0, 0, W, H); }

// ---------- Hứng trái cây: kéo giỏ, hứng trái cây, né bom; sao vàng nhân đôi điểm ----------
export async function catcher(box, opts) {
  const FRUIT = ['Red apple', 'Banana', 'Grapes', 'Strawberry', 'Watermelon', 'Tangerine', 'Cherries', 'Pineapple', 'Peach'];
  const lv = opts.level || 0, th = theme(lv), need = Math.round(15 + lv * .95);
  const [[tl, bgs, fxs]] = await Promise.all([sheets(['plat/tiles', 'plat/bg', 'fxa/fx']), loadAll([...FRUIT, 'Bomb', 'Glowing star', 'Basket', 'Red heart', 'Coin', 'Cloud', ...themeImgs(lv)])]);
  const D = dust(200), B = booms(fxs), SH = shaker();
  let tilt = 0, squash = 0;
  const {cv, ctx, W, H} = canvasIn(box);
  const S = Math.min(W, H), F = fx();
  const me = {x: W / 2, y: H * .86, w: S * ramp(lv, .22, .17), h: S * .14, tx: W / 2};
  const drops = [];
  let score = 0, lives = HEARTS, t = 0, spawn = .6, combo = 0, double = 0, end = null, endT = 0;
  const TIME = 50;
  const mv = pointer(cv, x => { me.tx = x; });
  cv.addEventListener('pointerdown', e => { cv.setPointerCapture(e.pointerId); mv(e); });
  cv.addEventListener('pointermove', e => { if (e.buttons || e.pointerType !== 'mouse') mv(e); });
  return loop({
    update(dt) {
      t += dt;
      if (end) { endT += dt; F.update(dt); return endT > 2 ? end : null; }
      const px = me.x; me.x = approach(me.x, me.tx, 12, dt);
      tilt = approach(tilt, Math.max(-.35, Math.min(.35, (me.x - px) / Math.max(dt, .001) / 2500)), 12, dt);
      squash = Math.max(0, squash - dt); SH.update(dt); D.update(dt); B.update(dt);
      double = Math.max(0, double - dt);
      spawn -= dt;
      if (spawn <= 0) {
        spawn = Math.max(.28, .85 - t / 80) * ramp(lv, 1, .78);
        const r = Math.random(), sz = S * .1;
        const k = r < .16 + ramp(lv, 0, .1) + t / 400 ? 'Bomb' : r > .96 ? 'Glowing star' : pick(FRUIT);
        drops.push({k, x: rand(sz, W - sz), y: -sz, w: sz, h: sz, vy: (rand(140, 220) + t * 3) * ramp(lv, 1, 1.6), rot: rand(-1, 1)});
      }
      for (let i = drops.length - 1; i >= 0; i--) {
        const d = drops[i]; d.y += d.vy * dt; d.rot += dt;
        if (d.k === 'Bomb' && Math.random() < .5) D.emit(d.x + d.w * .3, d.y - d.h * .45, rand(-30, 30), rand(-80, -20), {life: .25, r: 2, grow: 0, c: '#ffd43b', k: 1, a: 1});
        if (d.y > H + 40) { if (d.k !== 'Bomb' && d.k !== 'Glowing star') combo = 0; drops.splice(i, 1); continue; }
        if (Math.abs(d.y - (me.y - me.h * .3)) < me.h * .45 && Math.abs(d.x - me.x) < me.w * .5) {
          drops.splice(i, 1);
          if (d.k === 'Bomb') { lives--; combo = 0; sfx('boom'); B.add(d.x, d.y, d.w * 2.2); D.puff(d.x, d.y, 8, 'rgba(90,90,90,1)', 90, 12); SH.add(12); if (lives <= 0) end = {win: false, score}; }
          else if (d.k === 'Glowing star') { double = 8; sfx('power'); F.text(d.x, d.y - 30, 'NHÂN ĐÔI!', '#ffd43b'); }
          else { combo++; const p = (combo >= 5 ? 2 : 1) * (double > 0 ? 2 : 1); score += p; sfx('coin'); F.text(d.x, d.y - 30, '+' + p, '#ffd43b'); D.sparks(d.x, d.y, 8, '#fff3bf', 200); squash = .2; }
        }
      }
      if (t >= TIME && !end) { end = {win: score >= need, score}; sfx(score >= need ? 'win' : 'pop'); }
      F.update(dt);
      return null;
    },
    draw() {
      ctx.save(); SH.apply(ctx);
      sky(ctx, W, H, th.sky[0], th.sky[1]);
      draw(ctx, th.sun, W * .85, H * .13 + Math.sin(t * .8) * 4, S * .14);
      backHills(ctx, bgs, lv, t * 6, H * .9, H * .38, W);
      draw(ctx, th.deco[0], W * .1, H * .62, S * .5, S * .5, {rot: Math.sin(t * 1.3) * .03}); draw(ctx, th.deco[1], W * .9, H * .64, S * .42, S * .42, {rot: Math.sin(t * 1.1 + 1) * .03});
      groundTiles(ctx, tl, lv, 0, H * .9 - 8, W, H + 20, Math.max(40, S * .07));
      for (const d of drops) {
        // Bóng mờ trên mặt đất cho biết chỗ rơi
        const k = Math.max(0, Math.min(1, d.y / H));
        ctx.fillStyle = `rgba(0,0,0,${.08 + k * .14})`; ctx.beginPath(); ctx.ellipse(d.x, H * .9, d.w * (.2 + k * .25), 5, 0, 0, 7); ctx.fill();
        if (d.k === 'Bomb') spr(ctx, tl, Math.floor(t * 8) % 2 ? 'bomb_active' : 'bomb', d.x, d.y, d.h * 1.3, {rot: Math.sin(d.rot * 3) * .3});
        else draw(ctx, d.k, d.x, d.y, d.w, d.h, {rot: Math.sin(d.rot * 2) * .5});
      }
      // Giỏ nghiêng theo hướng kéo, phồng ra khi hứng
      const sq = squash > 0 ? Math.sin(squash / .2 * Math.PI) * .15 : 0;
      ctx.fillStyle = 'rgba(0,0,0,.18)'; ctx.beginPath(); ctx.ellipse(me.x, H * .9 + 2, me.w * .4, 7, 0, 0, 7); ctx.fill();
      ctx.save(); ctx.translate(me.x, me.y + me.w * .4); ctx.rotate(tilt); ctx.scale(1 + sq, 1 - sq);
      draw(ctx, 'Basket', 0, -me.w * .4, me.w, me.w);
      ctx.restore();
      if (double > 0) draw(ctx, 'Glowing star', me.x + me.w * .45, me.y - me.h * .7 + Math.sin(t * 6) * 5, 30, 30, {rot: t * 2});
      D.draw(ctx); B.draw(ctx);
      F.draw(ctx);
      ctx.restore();
      hud(ctx, W, {score, lives: 0, time: null}); hearts(ctx, W, lives); timer(ctx, W, Math.max(0, TIME - t)); goalPill(ctx, W, score, need);
      if (combo >= 5) { ctx.fillStyle = '#ff922b'; ctx.font = '800 24px "Baloo 2", sans-serif'; ctx.textAlign = 'left'; ctx.fillText(`Chuỗi ${combo} 🔥`, 16, 84); }
      if (t < 2.6) levelBanner(ctx, W, H, lv, `Hứng ${need} điểm`, `${th.vi} · Kéo giỏ · Né quả bom`);
      if (end) banner(ctx, W, H, lives <= 0 ? 'TRÚNG BOM RỒI!' : endText(end.win, lv), `${score}/${need} điểm`);
    }
  }, opts.alive);
}

// ---------- Đập quái vật: quái thò lên từ hang, chạm để đập; đừng đập bạn thỏ ----------
export async function whack(box, opts) {
  const BAD = ['Alien monster', 'Ghost', 'Goblin', 'Ogre'], GOOD = ['Rabbit face', 'Dog face'];
  const lv = opts.level || 0, th = theme(lv), need = Math.round(15 + lv * .8);
  const [[en, an, tl, bgs]] = await Promise.all([sheets(['plat/enemies', 'animals/round', 'plat/tiles', 'plat/bg']), loadAll([...BAD, ...GOOD, 'Hole', 'Hammer', 'Collision', 'Coin', 'Glowing star', 'Seedling'])]);
  // Quái là slime, chuột, sâu Kenney; bạn là thỏ, cún (khoá luật vẫn theo tên cũ)
  const LOOK = {'Alien monster': ['slime', 'slime_normal_flat'], 'Ghost': ['mouse', 'mouse_rest'], 'Goblin': ['sslime', 'slime_spike_flat'], 'Ogre': ['fslime', 'slime_fire_flat']};
  const FRIEND = {'Rabbit face': 'rabbit', 'Dog face': 'dog'};
  const D = dust(160), SH = shaker();
  const {cv, ctx, W, H} = canvasIn(box);
  const S = Math.min(W, H), F = fx();
  const cols = W > H ? 4 : 3, rows = 3;
  const cw = Math.min(W / cols, (H - 120) / rows), holes = [];
  for (let r = 0; r < rows; r++) for (let c = 0; c < cols; c++) holes.push({x: W / 2 + (c - (cols - 1) / 2) * cw, y: 140 + r * cw + cw * .55, k: null, up: 0, life: 0, hitT: 0});
  let score = 0, t = 0, spawn = .6, end = null, endT = 0, hammer = null, miss = 0;
  const TIME = 45;
  cv.addEventListener('pointerdown', pointer(cv, (x, y) => {
    if (end) return;
    hammer = {x, y, t: .2}; SH.add(2);
    const hl = holes.find(o => o.k && o.up > .4 && Math.abs(x - o.x) < cw * .4 && y < o.y + cw * .1 && y > o.y - cw * .6);
    if (!hl) { sfx('tap'); return; }
    if (GOOD.includes(hl.k)) { score = Math.max(0, score - 2); sfx('wrong'); F.text(hl.x, hl.y - cw * .5, 'Ối! Bạn mà!', '#ff6b6b'); }
    else { const p = hl.k === 'Ogre' ? 3 : 1; score += p; sfx('boom'); D.sparks(hl.x, hl.y - cw * .3, 12, '#ffe066', 280); D.debris(hl.x, hl.y, 6, '#8d5524', 200); SH.add(hl.k === 'Ogre' ? 7 : 4); F.text(hl.x, hl.y - cw * .55, '+' + p, '#ffd43b'); }
    hl.hitT = .25; hl.life = 0;
  }));
  return loop({
    update(dt) {
      t += dt;
      if (end) { endT += dt; F.update(dt); return endT > 2 ? end : null; }
      if (hammer) { hammer.t -= dt; if (hammer.t <= 0) hammer = null; }
      SH.update(dt); D.update(dt);
      spawn -= dt;
      if (spawn <= 0) {
        spawn = Math.max(.3, .9 - t / 70) * ramp(lv, 1, .75);
        const free = holes.filter(o => !o.k);
        if (free.length) { const o = pick(free); D.debris(o.x, o.y, 5, '#8d5524', 160); o.k = Math.random() < ramp(lv, .2, .32) ? pick(GOOD) : Math.random() < .12 ? 'Ogre' : pick(BAD); o.life = Math.max(.5, 1.5 - t / 60) * ramp(lv, 1, .62); o.up = 0; }
      }
      for (const o of holes) {
        if (!o.k) continue;
        o.hitT = Math.max(0, o.hitT - dt);
        if (o.life > 0) { o.life -= dt; o.up = Math.min(1, o.up + dt * 6); }
        else { o.up -= dt * 6; if (o.up <= 0) { o.k = null; o.up = 0; } }
      }
      if (t >= TIME) { end = {win: score >= need, score}; sfx(score >= need ? 'win' : 'pop'); }
      F.update(dt);
      return null;
    },
    draw() {
      ctx.save(); SH.apply(ctx);
      sky(ctx, W, H, th.sky[0], th.sky[1]);
      backHills(ctx, bgs, lv, t * 5, 150, 120, W);
      groundTiles(ctx, tl, lv, 0, 130, W, H + 20, Math.max(48, S * .08));
      for (const o of holes) {
        ctx.fillStyle = '#5c3d1e'; ctx.beginPath(); ctx.ellipse(o.x, o.y, cw * .36, cw * .12, 0, 0, 7); ctx.fill();
        if (o.k) {
          ctx.save(); ctx.beginPath(); ctx.rect(o.x - cw * .5, o.y - cw, cw, cw); ctx.clip();
          // Thò lên nảy (easeOutBack), bị đập thì bẹp xuống
          const up = o.life > 0 ? easeOutBack(Math.min(1, o.up)) : o.up, sz = cw * .62, hitK = o.hitT > 0 ? o.hitT / .25 : 0;
          const y = o.y - up * cw * .38 + cw * .12;
          if (FRIEND[o.k]) spr(ctx, an, FRIEND[o.k], o.x, y - sz * .1, sz * (hitK ? .9 : 1), {rot: Math.sin(t * 6 + o.x) * .08});
          else {
            const L = LOOK[o.k] || LOOK['Alien monster'];
            if (hitK) spr(ctx, en, L[1], o.x, y + sz * .2, sz * .5);
            else { ctx.save(); ctx.translate(o.x, y + sz * .4); const sq = 1 + Math.sin(t * 9 + o.x) * .05; ctx.scale(1 / sq, sq); anim(ctx, en, L[0], t + o.x, 0, -sz * .4, sz * (o.k === 'Ogre' ? 1.1 : 1)); ctx.restore(); }
          }
          ctx.restore();
          if (o.hitT > 0 && !GOOD.includes(o.k)) draw(ctx, 'Collision', o.x, o.y - cw * .4, cw * .4 * (1 + (1 - hitK) * .4), cw * .4 * (1 + (1 - hitK) * .4), {alpha: hitK});
        }
        ctx.fillStyle = '#8d5524'; ctx.beginPath(); ctx.ellipse(o.x, o.y + 4, cw * .38, cw * .1, 0, 0, Math.PI); ctx.fill();
      }
      D.draw(ctx);
      ctx.restore();
      if (hammer) { const k = 1 - hammer.t / .2, sw = k < .4 ? -1.1 + easeOutBack(k / .4) * 1.5 : .4 - (k - .4) * .6; draw(ctx, 'Hammer', hammer.x + 20, hammer.y - 20, S * .14, S * .14, {rot: sw}); }
      F.draw(ctx);
      hud(ctx, W, {score, lives: 0, time: Math.max(0, TIME - t)}); goalPill(ctx, W, score, need);
      if (t < 2.6) levelBanner(ctx, W, H, lv, `Đập ${need} điểm`, 'Đừng đập bạn thỏ, bạn cún nhé');
      if (end) banner(ctx, W, H, endText(end.win, lv), `${score}/${need} điểm`);
    }
  }, opts.alive);
}

// ---------- Câu cá: chạm chỗ muốn thả lưỡi câu; cá to nhiều điểm, sứa làm rơi cá ----------
export async function fishing(box, opts) {
  const FISH = [['Tropical fish', 1], ['Fish', 1], ['Blowfish', 2], ['Octopus', 3], ['Crab', 2], ['Shark', 5], ['Spouting whale', 8]];
  const lv = opts.level || 0, th = theme(lv), need = Math.round(12 + lv * .6);
  const [[en, fs]] = await Promise.all([sheets(['plat/enemies', 'fish/fish']), loadAll([...FISH.map(f => f[0]), 'Jellyfish', 'Sailboat', 'Cloud', 'Coin', 'Gem stone', 'Running shoe', opts.hero, th.sun])]);
  // Cá Kenney (có hoạt ảnh bơi) thay emoji; bạch tuộc, cua, cá voi, sứa vẫn hình cũ nhưng có nhịp bơi
  const FLOOK = {'Tropical fish': ['a', 'fishy'], 'Fish': ['a', 'fishb'], 'Blowfish': ['s', 'fish_brown'], 'Shark': ['a', 'eel'], 'Crab': null, 'Octopus': null, 'Spouting whale': null};
  const D = dust(160), weeds = [], bubbles = [];
  const {cv, ctx, W, H} = canvasIn(box);
  const S = Math.min(W, H), F = fx(), sea = H * .3;
  for (let i = 0; i < Math.ceil(W / 70); i++) weeds.push({x: i * 70 + rand(0, 40), k: pick(['seaweed_green_a', 'seaweed_green_b', 'seaweed_grass_a', 'seaweed_pink_a', 'seaweed_orange_a', 'rock_a']), s: rand(.7, 1.2), ph: rand(0, 6)});
  for (let i = 0; i < 14; i++) bubbles.push({x: rand(0, W), y: rand(H * .35, H), v: rand(30, 70), s: rand(8, 18), ph: rand(0, 6)});
  const boat = {x: W / 2, tx: W / 2};
  const hook = {x: W / 2, y: sea, state: 'idle', vy: 0, fish: null, ty: 0};
  const swim = [];
  let score = 0, t = 0, spawn = 0, end = null, endT = 0;
  const TIME = 55;
  cv.addEventListener('pointerdown', pointer(cv, (x, y) => {
    if (hook.state !== 'idle' || end) return;
    boat.tx = Math.max(S * .16, Math.min(W - S * .16, x)); hook.ty = Math.max(sea + 40, Math.min(H - 30, y)); hook.state = 'move';
  }));
  const add = () => {
    const deep = Math.random();
    const pool = deep < .4 ? FISH.slice(0, 3) : deep < .75 ? FISH.slice(1, 5) : FISH.slice(3);
    const [k, pts] = Math.random() < ramp(lv, .14, .3) ? ['Jellyfish', -1] : Math.random() < .05 ? ['Gem stone', 10] : Math.random() < .05 ? ['Running shoe', 0] : pick(pool);
    const dir = Math.random() < .5 ? 1 : -1, sz = S * (pts >= 5 ? .2 : pts >= 3 ? .14 : .1);
    swim.push({k, pts, x: dir > 0 ? -sz : W + sz, y: sea + 50 + (pts >= 3 || k === 'Gem stone' ? rand(.45, .95) : rand(.05, .6)) * (H - sea - 90), dir, v: rand(50, 110) * (pts >= 5 ? .7 : 1) * ramp(lv, 1, 1.7), w: sz, h: sz, ph: rand(0, 6)});
  };
  return loop({
    update(dt) {
      t += dt;
      if (end) { endT += dt; F.update(dt); return endT > 2 ? end : null; }
      spawn -= dt;
      if (spawn <= 0 && swim.length < 10) { spawn = rand(.5, 1.1); add(); }
      D.update(dt);
      for (const b of bubbles) { b.y -= b.v * dt; b.ph += dt; if (b.y < sea) { b.y = H + 10; b.x = rand(0, W); } }
      for (let i = swim.length - 1; i >= 0; i--) { const f = swim[i]; f.ph += dt; f.x += f.dir * f.v * dt; f.y += Math.sin(f.ph * 2) * 10 * dt; if (f.x < -150 || f.x > W + 150) swim.splice(i, 1); }
      // Thuyền chạy tới chỗ bé chạm, rồi thả câu
      if (hook.state === 'move') { boat.x = approach(boat.x, boat.tx, 4, dt); if (Math.random() < .5) D.emit(boat.x - Math.sign(boat.tx - boat.x) * S * .1, sea, rand(-40, 40), rand(-60, -20), {life: .5, r: 3, grow: 4, c: '#e7f5ff', k: 2, g: 300, a: .9}); hook.x = boat.x; if (Math.abs(boat.tx - boat.x) < 4) hook.state = 'down'; }
      else if (hook.state === 'down') {
        hook.y += 420 * dt;
        const f = swim.find(f => Math.hypot(f.x - hook.x, f.y - hook.y) < f.w * .5);
        if (f) {
          if (f.k === 'Jellyfish') { sfx('hit'); F.text(hook.x, hook.y - 20, 'Bị sứa chích!', '#da77f2'); hook.state = 'up'; }
          else { hook.fish = f; swim.splice(swim.indexOf(f), 1); hook.state = 'up'; sfx('pop'); for (let k = 0; k < 6; k++) D.emit(hook.x + rand(-10, 10), hook.y, rand(-30, 30), rand(-90, -40), {life: .8, r: 3, grow: 3, c: 'rgba(255,255,255,1)', a: .6}); }
        } else if (hook.y >= hook.ty) hook.state = 'up';
      } else if (hook.state === 'up') {
        hook.y -= (hook.fish && hook.fish.pts >= 5 ? 220 : 340) * dt;
        if (hook.y <= sea) {
          hook.y = sea; hook.state = 'idle';
          if (hook.fish) {
            const f = hook.fish;
            if (f.pts > 0) { score += f.pts; sfx(f.pts >= 5 ? 'win' : 'coin'); F.text(hook.x, sea - 60, '+' + f.pts, '#ffd43b'); D.sparks(hook.x, sea - 30, 12, '#ffe066', 240); }
            else F.text(hook.x, sea - 60, 'Chiếc giày cũ!', '#adb5bd');
            for (let k = 0; k < 10; k++) D.emit(hook.x + rand(-20, 20), sea, rand(-120, 120), rand(-260, -120), {life: .7, r: 3, grow: 0, c: '#d0ebff', k: 2, g: 700, a: 1});
            hook.fish = null;
          }
        }
      }
      if (hook.state === 'idle') hook.x = boat.x;
      if (t >= TIME && hook.state === 'idle') { end = {win: score >= need, score}; sfx(score >= need ? 'win' : 'pop'); }
      F.update(dt);
      return null;
    },
    draw() {
      sky(ctx, W, sea, th.sky[0], th.sky[1]);
      draw(ctx, th.sun, W * .85, sea * .4, S * .12);
      const g = ctx.createLinearGradient(0, sea, 0, H); g.addColorStop(0, '#4dabf7'); g.addColorStop(1, '#1864ab');
      ctx.fillStyle = g; ctx.fillRect(0, sea, W, H - sea);
      ctx.fillStyle = 'rgba(255,255,255,.35)';
      for (let x = -40; x < W + 40; x += 40) { ctx.beginPath(); ctx.arc(x + (t * 30) % 40, sea, 14, Math.PI, 0); ctx.fill(); }
      ctx.fillStyle = '#e9c46a'; ctx.beginPath(); ctx.ellipse(W / 2, H + 20, W * .7, 50, 0, Math.PI, 0); ctx.fill();
      // Đáy biển: cát, rong biển đung đưa, bọt nước nổi lên
      for (const w of weeds) { const f = fs?.frames?.[w.k]; if (!f) continue; const hh = S * .14 * w.s; ctx.save(); ctx.translate(w.x, H - 12); ctx.transform(1, 0, Math.sin(t * 1.5 + w.ph) * .15, 1, 0, 0); spr(ctx, fs, w.k, 0, -hh / 2, hh); ctx.restore(); }
      for (const b of bubbles) spr(ctx, fs, 'bubble_c', b.x + Math.sin(b.ph * 2) * 6, b.y, b.s, {alpha: .7});
      const drawFish = (f, x, y, rot = 0) => {
        const L = FLOOK[f.k], wig = Math.sin(f.ph * 9) * .08, flip = f.dir > 0;
        if (L && L[0] === 'a') {
          ctx.save(); ctx.translate(x, y); ctx.rotate(rot + wig * .5); ctx.scale(1 + wig * .5, 1);
          anim(ctx, L[1] === 'eel' ? fs : en, L[1], f.ph, 0, 0, f.h * (L[1] === 'eel' ? .45 : 1), {flip: L[1] === 'eel' ? !flip : flip});
          ctx.restore();
        } else if (L) { const puff = 1 + Math.max(0, Math.sin(f.ph * 2)) * .15; spr(ctx, fs, L[1], x, y, f.h * puff, {flip, rot}); }
        else if (f.k === 'Jellyfish') { const pk = 1 + Math.sin(f.ph * 4) * .1; draw(ctx, f.k, x, y + Math.sin(f.ph * 4) * 6, f.w * (2 - pk), f.h * pk, {rot}); }
        else draw(ctx, f.k, x, y, f.w * (1 + wig), f.h * (1 - wig * .5), {flip: flip && f.k !== 'Gem stone' && f.k !== 'Running shoe', rot: rot + (f.k === 'Gem stone' ? Math.sin(f.ph * 3) * .2 : 0)});
      };
      for (const f of swim) drawFish(f, f.x, f.y);
      // Dây câu
      ctx.strokeStyle = '#fff'; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(boat.x + S * .08, sea - S * .1); ctx.lineTo(hook.x, hook.y); ctx.stroke();
      ctx.strokeStyle = '#adb5bd'; ctx.lineWidth = 4; ctx.beginPath(); ctx.arc(hook.x - 6, hook.y, 8, 0, Math.PI); ctx.stroke();
      if (hook.fish) { hook.fish.ph += .016; drawFish(hook.fish, hook.x, hook.y + hook.fish.h * .4, Math.PI / 2 * (hook.fish.dir > 0 ? 1 : -1) + Math.sin(t * 14) * .25); }
      D.draw(ctx);
      // Thuyền nhấp nhô theo sóng, nghiêng khi chạy
      const bob = Math.sin(t * 2.2) * 4, roll = Math.sin(t * 1.7) * .05 + (boat.tx - boat.x) * -.0008;
      ctx.save(); ctx.translate(boat.x, sea + bob); ctx.rotate(roll); ctx.translate(-boat.x, -sea);
      draw(ctx, 'Sailboat', boat.x, sea - S * .08, S * .22);
      // Bé ngồi trên thuyền cầm cần câu
      drawFigure(ctx, boat.x - S * .04, sea - S * .09, S * .15, {c: heroOf(opts.hero), pose: 'sit', t, face: 1});
      ctx.restore();
      ctx.strokeStyle = '#8d5524'; ctx.lineWidth = 4; ctx.lineCap = 'round'; ctx.beginPath(); ctx.moveTo(boat.x - S * .005, sea - S * .14); ctx.lineTo(boat.x + S * .08, sea - S * .1); ctx.stroke();
      F.draw(ctx);
      hud(ctx, W, {score, lives: 0, time: Math.max(0, TIME - t)}); goalPill(ctx, W, score, need);
      if (t < 2.6) levelBanner(ctx, W, H, lv, `Câu ${need} điểm`, 'Chạm xuống biển để thả câu · Né con sứa');
      if (end) banner(ctx, W, H, endText(end.win, lv), `${score}/${need} điểm`);
    }
  }, opts.alive);
}

// ---------- Xây tháp: khối đung đưa, chạm để thả; phần thừa rơi mất ----------
export async function stacker(box, opts) {
  const lv = opts.level || 0, th = theme(lv), need = Math.min(40, 8 + Math.floor(lv * .55));
  const [[pz, tl, bgs]] = await Promise.all([sheets(['puzzle/puzzle', 'plat/tiles', 'plat/bg']), loadAll(['Cloud', 'Glowing star', 'Coin', 'Crown', th.sun])]);
  const {cv, ctx, W, H} = canvasIn(box);
  const S = Math.min(W, H), F = fx(), D = dust(160), SH = shaker();
  const bh = S * .07, COLS = ['#ff6b6b', '#ffa94d', '#ffd43b', '#69db7c', '#4dabf7', '#9775fa', '#f783ac'];
  // Khối kẹo bóng Kenney theo màu
  const PZ = {'#ff6b6b': 'rect_red', '#ffa94d': 'rect_yellow', '#ffd43b': 'rect_yellow', '#69db7c': 'rect_green', '#4dabf7': 'rect_blue', '#9775fa': 'rect_purple', '#f783ac': 'rect_red'};
  let land = 0, landI = -1;
  const tower = [{x: W / 2, w: W * .42}];
  let cur = null, cam = 0, score = 0, t = 0, end = null, endT = 0, falling = [], perfect = 0, lives = 2;
  const next = () => { const top = tower[tower.length - 1]; cur = {w: top.w, x: W * .15, dir: 1, v: Math.min(ramp(lv, 520, 680), ramp(lv, 210, 330) + tower.length * 14), y: 0}; };
  next();
  cv.addEventListener('pointerdown', () => {
    if (!cur || end) return;
    const top = tower[tower.length - 1];
    const l = Math.max(cur.x - cur.w / 2, top.x - top.w / 2), r = Math.min(cur.x + cur.w / 2, top.x + top.w / 2);
    const yTop = H * .82 - tower.length * bh;
    if (r - l < 8) {
      falling.push({x: cur.x, y: yTop, w: cur.w, vy: 0, vr: rand(-3, 3), r: 0, c: COLS[tower.length % COLS.length]}); sfx('wrong'); lives--; SH.add(6);
      if (lives <= 0) { end = {win: tower.length - 1 >= need, score}; } else { F.text(W / 2, H * .3, 'Thử lại!', '#fff'); next(); }
      return;
    }
    let w = r - l, x = (l + r) / 2;
    if (Math.abs(cur.x - top.x) < 6) { w = top.w; x = top.x; perfect++; sfx('power'); F.text(x, yTop + cam - 30, 'HOÀN HẢO!', '#ffd43b'); score += 2; if (perfect % 3 === 0) w = Math.min(W * .42, w + 20); D.sparks(x - w / 2, yTop + cam, 8, '#fff3bf', 220); D.sparks(x + w / 2, yTop + cam, 8, '#fff3bf', 220); }
    else { perfect = 0; sfx('pop'); const cutX = cur.x > top.x ? r + (cur.w - w) / 2 : l - (cur.w - w) / 2; falling.push({x: cutX, y: yTop, w: cur.w - w, vy: -120, vr: (cur.x > top.x ? 1 : -1) * rand(2, 4), r: 0, c: COLS[tower.length % COLS.length]}); }
    land = .3; landI = tower.length; SH.add(2.5);
    D.puff(x - w / 2, yTop + cam + bh * .4, 3, 'rgba(255,255,255,1)', 50, 5); D.puff(x + w / 2, yTop + cam + bh * .4, 3, 'rgba(255,255,255,1)', 50, 5);
    tower.push({x, w});
    score += 1;
    F.burst(x, yTop + cam, 8);
    next();
  });
  return loop({
    update(dt) {
      t += dt;
      if (end) { endT += dt; F.update(dt); return endT > 2 ? end : null; }
      if (cur) { cur.x += cur.dir * cur.v * dt; if (cur.x > W - cur.w / 2 - 10) cur.dir = -1; if (cur.x < cur.w / 2 + 10) cur.dir = 1; }
      const want = Math.max(0, tower.length * bh - H * .45);
      cam += (want - cam) * Math.min(1, dt * 4);
      for (let i = falling.length - 1; i >= 0; i--) { const f = falling[i]; f.vy += 1400 * dt; f.y += f.vy * dt; f.r += (f.vr || 0) * dt; if (f.y > H + cam + 200) falling.splice(i, 1); }
      land = Math.max(0, land - dt); SH.update(dt); D.update(dt);
      if (tower.length - 1 >= need) { end = {win: true, score: score + 20}; sfx('win'); }
      F.update(dt);
      return null;
    },
    draw() {
      const hgt = Math.min(1, cam / (H * 3));
      sky(ctx, W, H, hgt > .5 ? '#364fc7' : th.sky[0], hgt > .5 ? '#748ffc' : th.sky[1]);
      draw(ctx, th.sun, W * .85, H * .12 + cam * .1, S * .12);
      for (let k = 0; k < 4; k++) draw(ctx, 'Cloud', (k * 230 + 60) % W, ((k * 170 + cam * .5) % (H + 100)) - 50, 110, 66);
      ctx.save(); SH.apply(ctx); ctx.translate(0, cam);
      backHills(ctx, bgs, lv, 0, H * .82 + bh * .5 + 6, H * .3, W);
      groundTiles(ctx, tl, lv, 0, H * .82 + bh * .5, W, H * 1.5, Math.max(40, S * .07));
      const block = (x, y, w, c, sx = 1, sy = 1, rot = 0, a = 1) => {
        ctx.save(); ctx.translate(x, y + bh / 2); if (rot) ctx.rotate(rot); ctx.scale(sx, sy);
        if (pz) sprBox(ctx, pz, PZ[c] || 'rect_blue', 0, -bh / 2, w, bh - 2, a);
        else { ctx.fillStyle = c; roundRect(ctx, -w / 2, -bh, w, bh - 2, 8); ctx.fill(); }
        ctx.restore();
      };
      // Tầng vừa đặt nhún xuống, các tầng dưới nhún theo nhỏ dần
      tower.forEach((b, i) => {
        const y = H * .82 - i * bh, k = land > 0 && landI >= 0 ? Math.sin(land / .3 * Math.PI) * .12 * Math.max(0, 1 - (landI - i) * .25) : 0;
        block(b.x, y, b.w, COLS[i % COLS.length], 1 + k * .5, 1 - k);
      });
      if (cur) { const y = H * .82 - tower.length * bh; ctx.strokeStyle = 'rgba(255,255,255,.8)'; ctx.lineWidth = 2; ctx.setLineDash([6, 6]); ctx.beginPath(); ctx.moveTo(cur.x, 0 - cam); ctx.lineTo(cur.x, y - bh / 2); ctx.stroke(); ctx.setLineDash([]); block(cur.x, y + Math.sin(t * 6) * 3, cur.w, COLS[tower.length % COLS.length], 1, 1, cur.dir * Math.sin(t * 3) * .02); }
      for (const f of falling) block(f.x, f.y, f.w, f.c, 1, 1, f.r || 0, .85);
      ctx.restore();
      D.draw(ctx);
      F.draw(ctx);
      hud(ctx, W, {score, lives: 0, time: null});
      ctx.fillStyle = 'rgba(0,0,0,.28)'; roundRect(ctx, W / 2 - 70, 10, 140, 44, 22); ctx.fill();
      ctx.fillStyle = '#fff'; ctx.textAlign = 'center'; ctx.font = '800 26px "Baloo 2", sans-serif'; ctx.fillText(`🏢 ${tower.length - 1}/${need}`, W / 2, 42);
      hearts(ctx, W, lives);
      if (t < 2.6) levelBanner(ctx, W, H, lv, `Xây ${need} tầng`, 'Chạm để thả khối thật thẳng');
      if (end) banner(ctx, W, H, endText(end.win, lv), `${tower.length - 1} tầng · ${score} điểm`);
    }
  }, opts.alive);
}

// ---------- Phá gạch: kéo thanh đỡ, bóng phá gạch; gạch rơi quà (nhiều bóng, thanh dài, bóng lửa) ----------
export async function breakout(box, opts) {
  const lv = opts.level || 0, th = theme(lv), screens = lv < 10 ? 1 : 2;
  const [[pz, fxs]] = await Promise.all([sheets(['puzzle/puzzle', 'fxa/fx']), loadAll(['Coin', 'Fire', 'Glowing star', 'Red heart', 'Soccer ball', 'Sparkles'])]);
  const {cv, ctx, W, H} = canvasIn(box);
  const S = Math.min(W, H), F = fx(), D = dust(260), SH = shaker();
  const PZ = {'#ff6b6b': 'rect_red', '#ffa94d': 'rect_yellow', '#ffd43b': 'rect_yellow', '#69db7c': 'rect_green', '#4dabf7': 'rect_blue', '#9775fa': 'rect_purple', '#adb5bd': 'rect_grey', '#868e96': 'rect_grey'};
  const trail = Array.from({length: 8}, () => [0, 0]); let trailI = 0, padSq = 0;
  const pad = {x: W / 2, y: H * .9, w: S * ramp(lv, .26, .19), h: 18, tx: W / 2, big: 0};
  let balls = [], bricks = [], drops = [], score = 0, lives = HEARTS, lvl = 0, t = 0, end = null, endT = 0, fireT = 0, launched = false;
  const R = Math.max(9, S * .016), COLS = ['#ff6b6b', '#ffa94d', '#ffd43b', '#69db7c', '#4dabf7', '#9775fa'];
  // 8 kiểu xếp: đầy, ô cờ, kim tự tháp, sọc, kim cương, khung, cột, lỗ ngẫu nhiên
  const SKIP = [
    () => false, (r, c) => (r + c) % 3 === 0, (r, c, R, C) => Math.abs(c - (C - 1) / 2) > R - r + 1, r => r % 2 === 1,
    (r, c, R, C) => Math.abs(c - (C - 1) / 2) / (C / 2) + Math.abs(r - (R - 1) / 2) / (R / 2) > 1.05,
    (r, c, R, C) => r > 0 && r < R - 1 && c > 0 && c < C - 1 && !(r === Math.floor(R / 2) && Math.abs(c - (C - 1) / 2) < 1.5),
    (r, c) => c % 3 === 1, () => Math.random() < .28
  ];
  const build = () => {
    bricks = [];
    const pat = lv < 10 ? lv % SKIP.length : (lv * 2 + lvl) % SKIP.length;
    const cols = W > H ? 10 : 7, rows = 3 + Math.min(5, Math.floor(lv / 8)) + (pat === 3 ? 2 : 0), bw = (W - 40) / cols, bhh = Math.min(30, H * .045);
    const hard = Math.floor(lv / 12);
    for (let r = 0; r < rows; r++) for (let c = 0; c < cols; c++) {
      if (SKIP[pat](r, c, rows, cols)) continue;
      const hp = r < hard ? (lv >= 30 && r === 0 ? 3 : 2) : 1;
      bricks.push({x: 20 + c * bw + bw / 2, y: 110 + r * (bhh + 6), w: bw - 6, h: bhh, hp, c: hp > 1 ? (hp > 2 ? '#868e96' : '#adb5bd') : COLS[r % COLS.length], col: COLS[r % COLS.length]});
    }
    if (!bricks.length) build();
  };
  const serve = () => { balls = [{x: pad.x, y: pad.y - 30, vx: 0, vy: 0}]; launched = false; };
  build(); serve();
  const mv = pointer(cv, x => { pad.tx = x; });
  cv.addEventListener('pointerdown', e => { cv.setPointerCapture(e.pointerId); mv(e); });
  cv.addEventListener('pointermove', e => { if (e.buttons || e.pointerType !== 'mouse') mv(e); });
  cv.addEventListener('pointerup', () => { if (!launched && !end) { launched = true; const sp = S * .75 * ramp(lv, 1, 1.45); balls[0].vx = sp * rand(-.4, .4); balls[0].vy = -sp; sfx('jump'); } });
  return loop({
    update(dt) {
      t += dt;
      if (end) { endT += dt; F.update(dt); return endT > 2 ? end : null; }
      pad.big = Math.max(0, pad.big - dt); fireT = Math.max(0, fireT - dt); padSq = Math.max(0, padSq - dt); SH.update(dt); D.update(dt);
      for (const br of bricks) if (br.hitT) br.hitT = Math.max(0, br.hitT - dt);
      if (balls[0] && launched) { trail[trailI][0] = balls[0].x; trail[trailI][1] = balls[0].y; trailI = (trailI + 1) % trail.length; }
      if (fireT > 0) for (const b of balls) if (Math.random() < .6) D.emit(b.x, b.y, rand(-30, 30), rand(-30, 30), {life: .35, r: R * .7, grow: 4, c: Math.random() < .5 ? '#ff922b' : '#ffd43b', a: .8});
      const pw = pad.w * (pad.big > 0 ? 1.6 : 1);
      pad.x += (Math.max(pw / 2, Math.min(W - pw / 2, pad.tx)) - pad.x) * Math.min(1, dt * 16);
      if (!launched) { balls[0].x = pad.x; balls[0].y = pad.y - 26; }
      for (let i = balls.length - 1; i >= 0; i--) {
        const b = balls[i];
        for (let k = 0; k < 3; k++) {
          b.x += b.vx * dt / 3; b.y += b.vy * dt / 3;
          if (b.x < R) { b.x = R; b.vx = Math.abs(b.vx); } if (b.x > W - R) { b.x = W - R; b.vx = -Math.abs(b.vx); }
          if (b.y < 70 + R) { b.y = 70 + R; b.vy = Math.abs(b.vy); }
          if (b.vy > 0 && b.y + R > pad.y - pad.h / 2 && b.y < pad.y + pad.h && Math.abs(b.x - pad.x) < pw / 2 + R) {
            const off = (b.x - pad.x) / (pw / 2), sp = Math.hypot(b.vx, b.vy) * 1.01;
            b.vx = sp * off * .8; b.vy = -Math.sqrt(Math.max(1, sp * sp - b.vx * b.vx)); sfx('tap'); padSq = .15; D.sparks(b.x, pad.y - pad.h / 2, 5, '#a5d8ff', 160);
          }
          for (let j = bricks.length - 1; j >= 0; j--) {
            const br = bricks[j];
            if (Math.abs(b.x - br.x) < br.w / 2 + R && Math.abs(b.y - br.y) < br.h / 2 + R) {
              if (fireT <= 0) { if (Math.abs(b.x - br.x) / br.w > Math.abs(b.y - br.y) / br.h) b.vx *= -1; else b.vy *= -1; }
              if (--br.hp <= 0 || fireT > 0) {
                bricks.splice(j, 1); score++; sfx('pop'); D.debris(br.x, br.y, 7, br.col, 240); D.sparks(br.x, br.y, 6, '#fff', 200); SH.add(1.8);
                if (Math.random() < .15) drops.push({k: pick(['multi', 'big', 'fire', 'heart', 'multi']), x: br.x, y: br.y});
              } else { br.c = br.hp > 1 ? '#adb5bd' : br.col; br.hitT = .15; sfx('tap'); D.sparks(b.x, b.y, 4, '#ced4da', 140); }
              break;
            }
          }
        }
        if (b.y > H + 30) balls.splice(i, 1);
      }
      if (!balls.length) { lives--; sfx('hit'); SH.add(8); if (lives <= 0) end = {win: false, score}; else serve(); }
      for (let i = drops.length - 1; i >= 0; i--) {
        const d = drops[i]; d.y += 180 * dt;
        if (d.y > H + 30) { drops.splice(i, 1); continue; }
        if (Math.abs(d.y - pad.y) < 24 && Math.abs(d.x - pad.x) < pw / 2 + 16) {
          drops.splice(i, 1); sfx('power');
          if (d.k === 'multi') { const add = balls.slice(0, 3).flatMap(b => [{...b, vx: b.vx + 160}, {...b, vx: b.vx - 160}]); balls.push(...add); F.text(d.x, d.y - 30, 'NHIỀU BÓNG!', '#ffd43b'); }
          else if (d.k === 'big') { pad.big = 12; F.text(d.x, d.y - 30, 'THANH DÀI!', '#4dabf7'); }
          else if (d.k === 'fire') { fireT = 8; F.text(d.x, d.y - 30, 'BÓNG LỬA!', '#ff922b'); }
          else { lives = Math.min(HEARTS, lives + 1); F.text(d.x, d.y - 30, '+❤', '#ff6b6b'); }
        }
      }
      if (!bricks.length) {
        score += 10; lvl++; sfx('win'); F.text(W / 2, H * .5, 'QUA MÀN!', '#ffd43b');
        if (lvl >= screens) end = {win: true, score}; else { build(); serve(); drops = []; }
      }
      F.update(dt);
      return null;
    },
    draw() {
      ctx.save(); SH.apply(ctx);
      sky(ctx, W, H, '#212529', th.edge);
      for (const br of bricks) {
        const k = br.hitT ? 1 + br.hitT * 1.2 : 1;
        if (pz) sprBox(ctx, pz, PZ[br.c] || PZ[br.col] || 'rect_blue', br.x, br.y, br.w * k, br.h * k);
        else { ctx.fillStyle = br.c; roundRect(ctx, br.x - br.w / 2, br.y - br.h / 2, br.w, br.h, 6); ctx.fill(); }
        if (br.hp > 1) { ctx.fillStyle = 'rgba(0,0,0,.35)'; ctx.font = `800 ${br.h * .6}px "Baloo 2", sans-serif`; ctx.textAlign = 'center'; ctx.fillText(br.hp, br.x, br.y + br.h * .22); }
      }
      for (const d of drops) {
        const im = {multi: 'Sparkles', big: 'Glowing star', fire: 'Fire', heart: 'Red heart'}[d.k];
        ctx.fillStyle = 'rgba(255,255,255,.2)'; ctx.beginPath(); ctx.arc(d.x, d.y, 20 + Math.sin(t * 8) * 2, 0, 7); ctx.fill(); draw(ctx, im, d.x, d.y, 32, 32, {rot: Math.sin(t * 5 + d.x) * .3});
      }
      const pw = pad.w * (pad.big > 0 ? 1.6 : 1), psq = padSq > 0 ? Math.sin(padSq / .15 * Math.PI) * .25 : 0;
      if (pz) sprBox(ctx, pz, 'paddleBlu', pad.x, pad.y + psq * 4, pw * (1 + psq * .1), pad.h * 1.5 * (1 - psq));
      else { ctx.fillStyle = '#4dabf7'; roundRect(ctx, pad.x - pw / 2, pad.y - pad.h / 2, pw, pad.h, 9); ctx.fill(); }
      // Vệt bóng
      if (launched && balls[0] && fireT <= 0) for (let i = 0; i < trail.length; i++) { const [x, y] = trail[(trailI + i) % trail.length]; ctx.globalAlpha = i / trail.length * .35; ctx.fillStyle = '#74c0fc'; ctx.beginPath(); ctx.arc(x, y, R * (.4 + i / trail.length * .5), 0, 7); ctx.fill(); }
      ctx.globalAlpha = 1;
      D.draw(ctx);
      for (const b of balls) {
        if (fireT > 0) draw(ctx, 'Fire', b.x, b.y - 4, R * 3.2);
        else if (pz) spr(ctx, pz, 'ballBlue', b.x, b.y, R * 2.2);
        else { ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.arc(b.x, b.y, R, 0, 7); ctx.fill(); }
      }
      ctx.restore();
      F.draw(ctx);
      hud(ctx, W, {score, lives: 0, time: null}); hearts(ctx, W, lives);
      ctx.fillStyle = 'rgba(255,255,255,.8)'; ctx.font = '800 22px "Baloo 2", sans-serif'; ctx.textAlign = 'center'; ctx.fillText(`Cấp ${lv + 1} · Màn ${Math.min(lvl + 1, screens)}/${screens}`, W / 2, 40);
      if (!launched && !end) { ctx.fillStyle = '#fff'; ctx.font = '700 24px "Baloo 2", sans-serif'; ctx.fillText('Kéo thanh rồi thả tay để bắn bóng', W / 2, H * .7); }
      if (t < 2.6 && !launched) levelBanner(ctx, W, H, lv, screens > 1 ? 'Phá hết gạch 2 màn' : 'Phá hết gạch', th.vi);
      if (end) banner(ctx, W, H, end.win ? endText(true, lv) : 'HẾT BÓNG!', `${score} điểm`);
    }
  }, opts.alive);
}

// ---------- Chim bay: chạm để vỗ cánh, bay qua khe giữa hai thân cây, ăn xu ----------
export async function flappy(box, opts) {
  const lv = opts.level || 0, th = theme(lv), need = 10 + Math.floor(lv / 2), wobble = lv >= 15;
  const [[fl, tl, bgs, fxs]] = await Promise.all([sheets(['creatures/flyers', 'plat/tiles', 'plat/bg', 'fxa/fx']), loadAll(['Baby chick', 'Coin', 'Cloud', 'Glowing star', th.sun])]);
  const {cv, ctx, W, H} = canvasIn(box);
  const S = Math.min(W, H), F = fx(), ground = H * .9, D = dust(160), SH = shaker();
  let scroll = 0, flapT = 0;
  const bird = {x: W * .25, y: H * .45, vy: 0, w: S * .1, h: S * .1, inv: 0};
  const pipes = [], coins = [];
  let score = 0, lives = HEARTS, t = 0, started = false, spawn = 0, end = null, endT = 0, passed = 0;
  const gapH = () => Math.max(S * ramp(lv, .3, .25), S * ramp(lv, .42, .32) - passed * 3);
  cv.addEventListener('pointerdown', () => { if (end) return; started = true; bird.vy = -S * 1.15; sfx('jump'); flapT = .25; for (let k = 0; k < 3; k++) D.emit(bird.x - bird.w * .3, bird.y, rand(-120, -40), rand(20, 90), {life: .5, r: 3, grow: 3, c: '#fff3bf', k: 2, g: 200, a: 1}); });
  return loop({
    update(dt) {
      t += dt;
      if (end) { endT += dt; F.update(dt); return endT > 2 ? end : null; }
      D.update(dt); SH.update(dt); flapT = Math.max(0, flapT - dt);
      if (!started) { bird.y = H * .45 + Math.sin(t * 4) * 10; scroll += S * .2 * dt; F.update(dt); return null; }
      bird.vy += S * 3 * dt; bird.y += bird.vy * dt; bird.inv = Math.max(0, bird.inv - dt);
      const v = S * .38 * ramp(lv, 1, 1.45) + passed * 2;
      scroll += v * dt;
      spawn -= dt;
      if (spawn <= 0) {
        spawn = 1.7 * ramp(lv, 1, .85);
        const gh = gapH(), gy = rand(110 + gh / 2, ground - 40 - gh / 2);
        // Từ cấp 16 có khe di chuyển lên xuống
        pipes.push({x: W + 60, gy, gy0: gy, gh, w: S * .14, done: false, mv: wobble && Math.random() < ramp(lv, .2, .6) ? Math.min(gy - 110 - gh / 2, ground - 40 - gh / 2 - gy, S * .12) : 0, ph: rand(0, 6)});
        coins.push({x: W + 60, y: gy, w: 36, h: 36});
      }
      for (let i = pipes.length - 1; i >= 0; i--) {
        const p = pipes[i]; p.x -= v * dt; if (p.mv) { p.ph += dt * 1.6; p.gy = p.gy0 + Math.sin(p.ph) * p.mv; }
        if (p.x < -100) { pipes.splice(i, 1); continue; }
        if (!p.done && p.x < bird.x) { p.done = true; passed++; score++; sfx('tap'); D.sparks(bird.x, p.gy, 6, '#b2f2bb', 160); }
        const inX = Math.abs(p.x - bird.x) < p.w / 2 + bird.w * .35;
        const inGap = bird.y - bird.h * .35 > p.gy - p.gh / 2 && bird.y + bird.h * .35 < p.gy + p.gh / 2;
        if (inX && !inGap && bird.inv <= 0) hurt();
      }
      for (let i = coins.length - 1; i >= 0; i--) { const c = coins[i]; c.x -= v * dt; if (c.x < -50) { coins.splice(i, 1); continue; } if (hit(bird, c, .9)) { score += 2; sfx('coin'); F.text(c.x, c.y - 20, '+2', '#ffd43b'); D.sparks(c.x, c.y, 6, '#ffe066', 160); coins.splice(i, 1); } }
      if (bird.y > ground - bird.h / 2) { bird.y = ground - bird.h / 2; bird.vy = -S * .9; if (bird.inv <= 0) hurt(); }
      if (bird.y < bird.h / 2) { bird.y = bird.h / 2; bird.vy = 0; }
      if (passed >= need && !end) { end = {win: true, score: score + 10}; sfx('win'); }
      F.update(dt);
      return null;
      function hurt() { lives--; bird.inv = 1.5; sfx('hit'); SH.add(9); for (let k = 0; k < 8; k++) D.emit(bird.x, bird.y, rand(-160, 160), rand(-200, 40), {life: .9, r: 4, grow: 0, c: pick(['#ffd43b', '#fff3bf', '#fab005']), k: 2, g: 500, a: 1}); if (lives <= 0) end = {win: false, score}; }
    },
    draw() {
      ctx.save(); SH.apply(ctx);
      sky(ctx, W, H, th.sky[0], th.sky[1]);
      draw(ctx, th.sun, W * .85, H * .13, S * .12);
      // Nền nhiều lớp: mây chậm, đồi vừa, cây/khe nhanh, đất nhanh nhất
      for (let k = 0; k < 4; k++) draw(ctx, 'Cloud', ((k * 260 - scroll * .08) % (W + 200) + W + 200) % (W + 200) - 100, 70 + k * 40, 110, 66);
      backHills(ctx, bgs, lv, scroll * .25, ground + 6, H * .32, W);
      for (const p of pipes) {
        for (const [y0, y1] of [[0, p.gy - p.gh / 2], [p.gy + p.gh / 2, ground]]) {
          // Thân cây gỗ + tán lá (gradient chỉ theo trục x nên dùng chung được, tạo 1 lần mỗi cột)
          const g = ctx.createLinearGradient(p.x - p.w / 2, 0, p.x + p.w / 2, 0); g.addColorStop(0, '#8d5524'); g.addColorStop(.5, '#c08552'); g.addColorStop(1, '#8d5524');
          ctx.fillStyle = g; ctx.fillRect(p.x - p.w / 2, y0, p.w, y1 - y0);
          ctx.fillStyle = 'rgba(0,0,0,.12)'; for (let yy = y0 + 20; yy < y1 - 10; yy += 46) ctx.fillRect(p.x - p.w * .3, yy, p.w * .15, 18);
          const cy = y0 === 0 ? y1 : y0;
          ctx.fillStyle = '#2f9e44'; roundRect(ctx, p.x - p.w * .72, cy - 16, p.w * 1.44, 32, 14); ctx.fill();
          ctx.fillStyle = '#51cf66'; roundRect(ctx, p.x - p.w * .68, cy - 14, p.w * 1.36, 20, 10); ctx.fill();
        }
      }
      for (const c of coins) coin(ctx, fxs, t + c.x * .01, c.x, c.y, c.w);
      groundTiles(ctx, tl, lv, scroll, ground - 4, W, H + 20, Math.max(40, S * .07));
      D.draw(ctx);
      const blink = bird.inv > 0 && Math.floor(bird.inv * 10) % 2 === 0;
      // Chim vỗ cánh nhanh khi vừa chạm, ngóc lên/chúi xuống theo vận tốc
      if (!blink) {
        const rot = Math.max(-.5, Math.min(.9, bird.vy / (S * 1.6))), stretch = flapT > 0 ? 1 + Math.sin(flapT / .25 * Math.PI) * .1 : 1;
        ctx.save(); ctx.translate(bird.x, bird.y); ctx.rotate(rot); ctx.scale(2 - stretch, stretch);
        if (fl) anim(ctx, fl, bird.inv > 1 ? 'hit' : 'fly', t * (flapT > 0 ? 2 : 1), 0, 0, bird.h * 1.35);
        else draw(ctx, 'Baby chick', 0, 0, bird.w * 1.3, bird.h * 1.3, {flip: true});
        ctx.restore();
      }
      ctx.restore();
      F.draw(ctx);
      hud(ctx, W, {score, lives: 0, time: null}); hearts(ctx, W, lives);
      ctx.fillStyle = 'rgba(0,0,0,.28)'; roundRect(ctx, W / 2 - 60, 10, 120, 44, 22); ctx.fill();
      ctx.fillStyle = '#fff'; ctx.textAlign = 'center'; ctx.font = '800 26px "Baloo 2", sans-serif'; ctx.fillText(`${passed}/${need}`, W / 2, 42);
      if (!started) levelBanner(ctx, W, H, lv, `Bay qua ${need} khe`, 'Chạm màn hình để vỗ cánh');
      if (end) banner(ctx, W, H, end.win ? endText(true, lv) : 'HẾT LƯỢT!', `${score} điểm`);
    }
  }, opts.alive);
}
