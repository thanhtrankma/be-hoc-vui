// Khu vui chơi: danh sách game thưởng sau giờ học. Game hành động ở funracer/funshooter/funhero, game vui nhộn ở funmore,
// game trí tuệ ở funlogic. Vẽ bằng canvas, hình là Fluent Emoji 3D. Mỗi lượt ~1 phút.
import {sfx} from '../audio.js?v=4c51d34a6e';
import {coding_, flow_, pipes_, schulte_} from './funlogic.js?v=4c51d34a6e';
import {racer} from './funracer.js?v=4c51d34a6e';
import {shooter} from './funshooter.js?v=4c51d34a6e';
import {hero} from './funhero.js?v=4c51d34a6e';
import {catcher, whack, fishing, stacker, breakout, flappy} from './funmore.js?v=4c51d34a6e';
import {snake, gallery, tank, blocks, jumper} from './funnew1.js?v=4c51d34a6e';
import {runner, frogger, pong, pacman, match3} from './funnew2.js?v=4c51d34a6e';
import {fighter, hockey, tug, soccer, volley} from './funvs1.js?v=4c51d34a6e';
import {snowball, tron, sumo, caro, connect4} from './funvs2.js?v=4c51d34a6e';
import {lanes, swim, hoops, hurdles, dance, golf} from './funnew3.js?v=4c51d34a6e';
import {pizza, farm, firefight, hidden} from './funnew4.js?v=4c51d34a6e';
import {trains, truckload, balloons} from './funnew5.js?v=4c51d34a6e';
import {hunt} from './funhunt.js?v=4c51d34a6e';
import {MAX_LV, banner, canvasIn, draw, fx, hud, loadAll, loop, pick, rand, ramp, roundRect, theme} from './funcore.js?v=4c51d34a6e';

// ---------- Game: Ná thần kỳ (kéo – ngắm – thả, rèn độ chính xác) ----------
async function slingLevel(box, opts, last) {
  const TG = ['Alien monster', 'Ghost', 'Bullseye'];
  const lv = opts.level || 0, th = theme(lv);
  await loadAll([...TG, 'Soccer ball', 'Cloud', 'Glowing star', th.sun]);
  const {cv, ctx, W, H} = canvasIn(box);
  const S = Math.min(W, H);
  const ground = H * .86, anchor = {x: W * .17, y: ground - S * .24}, maxPull = S * .2, R = S * .035;
  const G = S * 1.9, POWER = 8.2;
  // Cấp: nhiều mục tiêu hơn, mục tiêu di chuyển nhanh hơn, thêm tường (cấp 36+ có tường bay), ít bóng dư, đường ngắm ngắn dần.
  const nT = Math.min(7, 3 + Math.floor(lv / 6)), moving = lv >= 3, mvSp = ramp(lv, 1.2, 2.6), mvAmp = ramp(lv, .05, .1);
  const targets = [];
  for (let i = 0; i < nT; i++) {
    const x = W * (.52 + .4 * (i + .5) / nT) + rand(-20, 20), y = ground - rand(.08, .5) * H;
    targets.push({k: pick(TG), x, y, y0: y, w: S * .1, h: S * .1, ph: rand(0, 6), alive: true});
  }
  const walls = [];
  if (lv >= 1) walls.push({x: W * .42, y: ground - S * .26, w: S * .04, h: S * .26});
  if (lv >= 15) walls.push({x: W * .66, y: ground - S * .17, w: S * .04, h: S * .17});
  if (lv >= 35) walls.push({x: W * .32, y: ground - S * .55, y0: ground - S * .55, w: S * .04, h: S * .16, fly: true, ph: 0});
  let ball = {x: anchor.x, y: anchor.y, vx: 0, vy: 0, fly: false, t: 0}, drag = null, balls = nT + Math.max(1, 3 - Math.floor(lv / 20)), score = 0, end = null, endT = 0, t = 0;
  const F = fx(), clouds = Array.from({length: 4}, () => ({x: rand(0, W), y: rand(20, H * .3), s: rand(70, 120)}));
  const pos = e => { const r = cv.getBoundingClientRect(); return {x: e.clientX - r.left, y: e.clientY - r.top}; };
  cv.addEventListener('pointerdown', e => {
    if (ball.fly || end || balls <= 0) return;
    const p = pos(e);
    if (Math.hypot(p.x - anchor.x, p.y - anchor.y) < S * .2) { drag = p; cv.setPointerCapture(e.pointerId); }
  });
  cv.addEventListener('pointermove', e => { if (drag) drag = pos(e); });
  const pullVec = () => {
    let dx = drag.x - anchor.x, dy = drag.y - anchor.y;
    const d = Math.hypot(dx, dy);
    if (d > maxPull) { dx *= maxPull / d; dy *= maxPull / d; }
    return {dx, dy};
  };
  cv.addEventListener('pointerup', () => {
    if (!drag) return;
    const {dx, dy} = pullVec(); drag = null;
    if (Math.hypot(dx, dy) < S * .03) { ball.x = anchor.x; ball.y = anchor.y; return; }
    ball = {x: anchor.x + dx, y: anchor.y + dy, vx: -dx * POWER, vy: -dy * POWER, fly: true, t: 0};
    balls--; sfx('shoot');
  });
  const resetBall = () => {
    ball = {x: anchor.x, y: anchor.y, vx: 0, vy: 0, fly: false, t: 0};
    if (targets.every(tg => !tg.alive)) { end = {win: true, score: score + balls * 3}; sfx('win'); }
    else if (balls <= 0) end = {win: false, score};
  };
  return loop({
    update(dt) {
      t += dt;
      for (const c of clouds) { c.x -= 12 * dt; if (c.x < -120) c.x = W + 120; }
      for (const tg of targets) if (moving && tg.alive) { tg.ph += dt; tg.y = tg.y0 + Math.sin(tg.ph * mvSp) * S * mvAmp; }
      for (const w of walls) if (w.fly) { w.ph += dt; w.y = w.y0 + Math.sin(w.ph * 1.3) * S * .2; }
      if (end) { endT += dt; F.update(dt); return endT > 2 ? end : null; }
      if (ball.fly) {
        // Chia nhỏ bước để bóng nhanh không xuyên qua mục tiêu.
        for (let k = 0; k < 4; k++) {
          const d = dt / 4;
          ball.vy += G * d; ball.x += ball.vx * d; ball.y += ball.vy * d; ball.t += d;
          for (const tg of targets) if (tg.alive && Math.abs(ball.x - tg.x) < tg.w / 2 + R && Math.abs(ball.y - tg.y) < tg.h / 2 + R) {
            tg.alive = false; score += 10; sfx('boom'); F.burst(tg.x, tg.y, 22); F.star(tg.x, tg.y); F.text(tg.x, tg.y - 40, '+10', '#ffd43b');
          }
          for (const w of walls) if (ball.x + R > w.x && ball.x - R < w.x + w.w && ball.y + R > w.y && ball.y - R < w.y + w.h) { ball.vx = -Math.abs(ball.vx) * .4; ball.x = w.x - R; sfx('pop'); }
          if (ball.y + R > ground) { ball.y = ground - R; ball.vy *= -.35; ball.vx *= .7; if (Math.abs(ball.vy) < 60) { ball.vy = 0; } }
        }
        if (ball.x > W + 60 || ball.x < -60 || ball.t > 4 || (ball.vy === 0 && Math.abs(ball.vx) < 30)) resetBall();
      }
      F.update(dt);
      return null;
    },
    draw() {
      const sky = ctx.createLinearGradient(0, 0, 0, ground);
      sky.addColorStop(0, th.sky[0]); sky.addColorStop(1, th.sky[1]);
      ctx.fillStyle = sky; ctx.fillRect(0, 0, W, H);
      draw(ctx, th.sun, W * .88, H * .14, S * .14);
      for (const c of clouds) draw(ctx, 'Cloud', c.x, c.y, c.s, c.s * .6);
      ctx.fillStyle = th.ground; ctx.fillRect(0, ground, W, H - ground);
      ctx.fillStyle = th.edge; ctx.fillRect(0, ground, W, 8);
      for (const w of walls) { ctx.fillStyle = '#a0522d'; roundRect(ctx, w.x, w.y, w.w, w.h, 6); ctx.fill(); ctx.fillStyle = 'rgba(0,0,0,.15)'; for (let y = w.y + 14; y < w.y + w.h; y += 22) ctx.fillRect(w.x, y, w.w, 3); }
      for (const tg of targets) {
        if (!tg.alive) continue;
        ctx.fillStyle = '#c08552'; roundRect(ctx, tg.x - tg.w * .6, tg.y + tg.h * .45, tg.w * 1.2, 12, 5); ctx.fill();
        if (!moving) { ctx.fillStyle = '#a0522d'; ctx.fillRect(tg.x - 5, tg.y + tg.h * .45 + 12, 10, ground - tg.y - tg.h * .45 - 12); }
        draw(ctx, tg.k, tg.x, tg.y, tg.w, tg.h);
      }
      // Ná
      const sx = anchor.x, sy = anchor.y;
      ctx.strokeStyle = '#8d5524'; ctx.lineWidth = 12; ctx.lineCap = 'round';
      ctx.beginPath(); ctx.moveTo(sx, ground); ctx.lineTo(sx, sy + S * .06); ctx.lineTo(sx - S * .05, sy - S * .02); ctx.moveTo(sx, sy + S * .06); ctx.lineTo(sx + S * .05, sy - S * .02); ctx.stroke();
      let bx = ball.x, by = ball.y;
      if (drag) { const {dx, dy} = pullVec(); bx = anchor.x + dx; by = anchor.y + dy;
        // Đường ngắm: dài ở cấp thấp, ngắn dần khi lên cấp.
        let px = bx, py = by, vx = -dx * POWER, vy = -dy * POWER;
        const dots = Math.round(Math.max(6, 34 - lv * .9));
        ctx.fillStyle = 'rgba(255,255,255,.95)';
        for (let i = 0; i < dots; i++) { for (let k = 0; k < 3; k++) { vy += G * .012; px += vx * .012; py += vy * .012; } ctx.beginPath(); ctx.arc(px, py, Math.max(2, 6 - i * .15), 0, 7); ctx.fill(); }
      }
      if (!ball.fly) { ctx.strokeStyle = '#5c3d1e'; ctx.lineWidth = 5; ctx.beginPath(); ctx.moveTo(sx - S * .05, sy - S * .02); ctx.lineTo(bx, by); ctx.lineTo(sx + S * .05, sy - S * .02); ctx.stroke(); }
      if (balls > 0 || ball.fly) draw(ctx, 'Soccer ball', bx, by, R * 2.2, R * 2.2, {rot: ball.fly ? ball.t * 10 : 0});
      for (let i = 0; i < balls - (ball.fly ? 0 : 1); i++) draw(ctx, 'Soccer ball', 30 + i * 30, ground + 30, 24);
      F.draw(ctx);
      hud(ctx, W, {score, lives: 0, time: null});
      if (t < 2.5 && !end) banner(ctx, W, H, `CẤP ${lv + 1}`, `${th.vi} · Bắn trúng ${nT} mục tiêu`);
      if (end) banner(ctx, W, H, end.win ? (last ? '🎯 TRÚNG HẾT!' : `⭐ LÊN CẤP ${Math.min(MAX_LV, lv + 2)}!`) : 'HẾT BÓNG!', `${end.score} điểm`);
    }
  }, opts.alive);
}

// Một lượt Ná: tối đa 3 cấp liên tiếp; trúng hết thì lên cấp, hết bóng thì dừng.
async function sling(box, opts) {
  let total = 0;
  for (let k = 0; k < 3; k++) {
    box.replaceChildren();
    const r = await slingLevel(box, {...opts, level: Math.min(MAX_LV - 1, opts.level + k)}, k === 2);
    if (!r) return null;
    total += r.score;
    if (!r.win) return {win: k > 0, score: total, lvUp: k > 0, ups: k};
    if (opts.levelUp) opts.levelUp();
  }
  return {win: true, score: total, lvUp: true, ups: 3};
}

// Game một lượt = một cấp: thắng (đạt mục tiêu cấp) thì lên cấp và tự chơi luôn cấp sau,
// mỗi vé tối đa LEVELS_PER_TICKET cấp; thua thì dừng và hiện bảng kết quả.
export const LEVELS_PER_TICKET = 3;
export const leveled = run => async (box, opts) => {
  let total = 0, ups = 0, last = null;
  for (let k = 0; k < LEVELS_PER_TICKET; k++) {
    box.replaceChildren();
    const r = await run(box, opts);
    if (!r) return null;
    if (r.pvp) return r;  // hai người chơi: không lên cấp
    // Kho đồ (súng, skill...) mang sang cấp sau và lưu vào hồ sơ, thắng hay thua đều giữ
    if (r.carry) { opts.carry = r.carry; if (opts.saveGear) opts.saveGear(r.carry); }
    total += r.score || 0; last = r;
    if (!r.win) break;
    ups++;
    if (opts.levelUp) opts.levelUp();
    if (opts.level + 1 >= MAX_LV) break;
    opts.level++;  // opts dùng chung giữa các cấp (vd. xe đã chọn ở Đua xe)
  }
  return {...last, score: total, win: ups > 0, lvUp: ups > 0, ups};
};

export const FUN_GAMES = [
  {id: 'racer', hot: true, kind: 'action', img: 'Racing car', vi: 'Đua xe tốc độ', en: 'Speed racer', color: '#ff6b6b', run: leveled(racer), levels: true},
  {id: 'hunt', hot: true, kind: 'action', img: 'Crossed swords', vi: 'Săn quái vật', en: 'Monster hunt', color: '#7048e8', run: leveled(hunt), levels: true},
  {id: 'shooter', hot: true, kind: 'action', img: 'Rocket', vi: 'Phi thuyền diệt quái', en: 'Space blaster', color: '#5f3dc4', run: leveled(shooter), levels: true},
  {id: 'hero', hot: true, kind: 'action', img: 'Man superhero', vi: 'Siêu nhân diệt quái vật', en: 'Super hero', color: '#1c7ed6', run: leveled(hero), levels: true},
  {id: 'sling', kind: 'action', img: 'Bullseye', vi: 'Ná thần kỳ', en: 'Slingshot', color: '#e8590c', run: sling, levels: true},
  {id: 'catch', kind: 'casual', img: 'Basket', vi: 'Hứng trái cây', en: 'Fruit catch', color: '#2f9e44', run: leveled(catcher), levels: true},
  {id: 'whack', kind: 'casual', img: 'Hammer', vi: 'Đập quái vật', en: 'Whack a monster', color: '#e8590c', run: leveled(whack), levels: true},
  {id: 'fishing', kind: 'casual', img: 'Tropical fish', vi: 'Câu cá', en: 'Fishing', color: '#1c7ed6', run: leveled(fishing), levels: true},
  {id: 'stack', kind: 'casual', img: 'Building construction', vi: 'Xây tháp', en: 'Tower stack', color: '#f08c00', run: leveled(stacker), levels: true},
  {id: 'breakout', kind: 'casual', img: 'Brick', vi: 'Phá gạch', en: 'Brick breaker', color: '#495057', run: leveled(breakout), levels: true},
  {id: 'flappy', kind: 'casual', img: 'Baby chick', vi: 'Chim bay', en: 'Flappy chick', color: '#fab005', run: leveled(flappy), levels: true},
  {id: 'gallery', kind: 'action', img: 'Water pistol', vi: 'Bắn bia', en: 'Target shooting', color: '#c92a2a', run: leveled(gallery), levels: true},
  {id: 'tank', hot: true, kind: 'action', img: 'Military helmet', vi: 'Xe tăng dũng cảm', en: 'Brave tank', color: '#2b8a3e', run: leveled(tank), levels: true},
  {id: 'runner', kind: 'action', img: 'T-Rex', vi: 'Khủng long chạy', en: 'Dino run', color: '#5c940d', run: leveled(runner), levels: true},
  {id: 'pacman', kind: 'action', img: 'Ghost', vi: 'Ăn đậu né ma', en: 'Dot muncher', color: '#364fc7', run: leveled(pacman), levels: true},
  {id: 'snake', kind: 'casual', img: 'Snake', vi: 'Rắn săn mồi', en: 'Snake', color: '#2f9e44', run: leveled(snake), levels: true},
  {id: 'jumper', kind: 'casual', img: 'Cloud', vi: 'Nhảy lên mây', en: 'Cloud jump', color: '#4dabf7', run: leveled(jumper), levels: true},
  {id: 'frogger', kind: 'casual', img: 'Frog', vi: 'Ếch qua đường', en: 'Frog crossing', color: '#37b24d', run: leveled(frogger), levels: true},
  {id: 'pong', kind: 'casual', img: 'Ping pong', vi: 'Bóng bàn', en: 'Ping pong', color: '#e8590c', run: leveled(pong), levels: true},
  {id: 'blocks', kind: 'brain', img: 'Puzzle piece', vi: 'Xếp gạch', en: 'Block drop', color: '#7048e8', run: leveled(blocks), levels: true},
  {id: 'match3', kind: 'brain', img: 'Gem stone', vi: 'Ghép 3 hình', en: 'Match three', color: '#d6336c', run: leveled(match3), levels: true},
  {id: 'fighter', kind: 'vs', img: 'Boxing glove', vi: 'Võ đài', en: 'Fighter', color: '#e03131', run: leveled(fighter), levels: true},
  {id: 'hockey', kind: 'vs', img: 'Ice hockey', vi: 'Khúc côn cầu', en: 'Air hockey', color: '#1c7ed6', run: leveled(hockey), levels: true},
  {id: 'tug', kind: 'vs', img: 'Flexed biceps', vi: 'Kéo co', en: 'Tug of war', color: '#a0522d', run: leveled(tug), levels: true},
  {id: 'soccer', kind: 'vs', img: 'Soccer ball', vi: 'Bóng đá đầu to', en: 'Head soccer', color: '#2f9e44', run: leveled(soccer), levels: true},
  {id: 'volley', kind: 'vs', img: 'Volleyball', vi: 'Bóng chuyền bãi biển', en: 'Beach volley', color: '#f08c00', run: leveled(volley), levels: true},
  {id: 'snowball', kind: 'vs', img: 'Snowman', vi: 'Ném tuyết', en: 'Snowball fight', color: '#74c0fc', run: leveled(snowball), levels: true},
  {id: 'tron', kind: 'vs', img: 'Motorcycle', vi: 'Mô tô ánh sáng', en: 'Light bikes', color: '#3b5bdb', run: leveled(tron), levels: true},
  {id: 'sumo', kind: 'vs', img: 'Person wrestling', vi: 'Đấu sumo', en: 'Sumo', color: '#d6336c', run: leveled(sumo), levels: true},
  {id: 'caro', kind: 'vs', img: 'Cross mark', vi: 'Cờ caro', en: 'Tic-tac-toe', color: '#495057', run: leveled(caro), levels: true},
  {id: 'connect4', kind: 'vs', img: 'Red circle', vi: 'Nối bốn', en: 'Connect four', color: '#c92a2a', run: leveled(connect4), levels: true},
  {id: 'coding', kind: 'brain', img: 'Robot', vi: 'Lập trình robot', en: 'Code the robot', color: '#0ca678', run: (b, o) => coding_(b, o), levels: true},
  {id: 'flow', kind: 'brain', img: 'Rainbow', vi: 'Nối dây màu', en: 'Connect colors', color: '#d6336c', run: (b, o) => flow_(b, o), levels: true},
  {id: 'pipes', kind: 'brain', img: 'Droplet', vi: 'Dẫn nước', en: 'Water pipes', color: '#1971c2', run: (b, o) => pipes_(b, o), levels: true},
  {id: 'schulte', kind: 'brain', img: 'Input numbers', vi: 'Bảng số thần tốc', en: 'Number rush', color: '#f08c00', run: (b, o) => schulte_(b, o), levels: true},
  // Đợt 15: game mới, nhân vật sprite Kenney có hoạt ảnh (funnew3/4/5.js)
  {id: 'lanes', kind: 'action', img: 'Person running', vi: 'Chạy 3 làn', en: 'Lane runner', color: '#f76707', run: leveled(lanes), levels: true},
  {id: 'hoops', kind: 'action', img: 'Basketball', vi: 'Ném bóng rổ', en: 'Basketball', color: '#e8590c', run: leveled(hoops), levels: true},
  {id: 'hurdles', kind: 'action', img: 'Sports medal', vi: 'Chạy vượt rào', en: 'Hurdle race', color: '#d9480f', run: leveled(hurdles), levels: true},
  {id: 'firefight', kind: 'action', img: 'Fire engine', vi: 'Lính cứu hoả nhí', en: 'Firefighter', color: '#e03131', run: leveled(firefight), levels: true},
  {id: 'swim', kind: 'casual', img: 'Blowfish', vi: 'Cá con đại dương', en: 'Ocean swim', color: '#1971c2', run: leveled(swim), levels: true},
  {id: 'dance', kind: 'casual', img: 'Woman dancing', vi: 'Nhảy theo nhạc', en: 'Dance beat', color: '#9c36b5', run: leveled(dance), levels: true},
  {id: 'farm', kind: 'casual', img: 'Seedling', vi: 'Nông trại vui vẻ', en: 'Happy farm', color: '#5c940d', run: leveled(farm), levels: true},
  {id: 'balloons', kind: 'casual', img: 'Balloon', vi: 'Bong bóng số', en: 'Number balloons', color: '#f03e3e', run: leveled(balloons), levels: true},
  {id: 'pizza', kind: 'brain', img: 'Pizza', vi: 'Tiệm pizza', en: 'Pizza shop', color: '#e67700', run: leveled(pizza), levels: true},
  {id: 'golf', kind: 'brain', img: 'Flag in hole', vi: 'Golf mini', en: 'Mini golf', color: '#2b8a3e', run: leveled(golf), levels: true},
  {id: 'hidden', kind: 'brain', img: 'Magnifying glass tilted left', vi: 'Tìm đồ vật', en: 'Hidden objects', color: '#5f3dc4', run: leveled(hidden), levels: true},
  {id: 'trains', kind: 'brain', img: 'Locomotive', vi: 'Bẻ ghi tàu hoả', en: 'Train switch', color: '#364fc7', run: leveled(trains), levels: true},
  {id: 'truckload', kind: 'brain', img: 'Delivery truck', vi: 'Xếp hàng lên xe', en: 'Load the truck', color: '#a0522d', run: leveled(truckload), levels: true}
];
