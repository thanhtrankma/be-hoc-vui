// Thế giới phiêu lưu: 5 vùng có cách chơi riêng.
// Vùng 3 Hang Mỏ (mê cung), 4 Xứ Tuyết (đánh theo lượt), 5 Sa Mạc (đào kho báu), 7 Rừng Kẹo (giữ bánh), 8 Núi Lửa (nhảy qua dung nham).
import {BASE_IMGS, buttons, canvasIn, clamp, dist, draw, drawHero, drawPotionCount, endBanner, foeStats, fx, hpBar, bossBar, loadAll, loop,
  multi, pick, potionUse, rand, roundRect, sfx, strike, taken, topHud, zoneIntro, PET_RIG, E, fade, camera, drawMob, fxb, loadRpgSheets, spr, sprA, drawCoin} from './rpgcore.js?v=4c51d34a6e';
import {prerender} from './motionb.js?v=4c51d34a6e';
import {petBuddy} from './figure.js?v=4c51d34a6e';

// Khung chung: tải hình, canvas, máu, bình máu, màn mở đầu, kết thúc. init(G) trả {update(dt), draw(), done(), goal()}.
async function shell(box, Z, cfg, init) {
  await loadAll([Z.heroImg, Z.weaponImg, ...BASE_IMGS, ...cfg.imgs]);
  const SP = await loadRpgSheets();
  const {cv, ctx, W, H} = canvasIn(box);
  const S = Math.min(W, H), M = multi(cv), F = fx(), FB = fxb(), C = camera();
  let ghosts = [], flash = 0;
  const pot = {id: 'pot', x: W - 44, y: 104, r: 30, label: '🧪', c: '#69db7c', ...(cfg.pot ? cfg.pot(W, H, S) : {})};
  const B = buttons(M, cfg.noPotion ? [] : [pot]);
  const G = {Z, W, H, S, F, FB, C, SP, M, cv, ctx, B, t: 0,
    // Quái vừa chết: vẽ hoạt ảnh bật lên, xoay, mờ dần (toạ độ màn hình). v = {img | sheet+anim/frame, x, y, size, flip, pixel}
    die(v) { ghosts.push({...v, dieT: 0, t: G.t}); FB.ring(v.x, v.y, v.size * .6, '#fff', 6); C.shake(v.boss ? 14 : 3); if (v.boss) C.stop(.25); }, gold: 0, xp: 0, kills: 0, end: null, endT: 0, introT: 2.4,
    hero: {hp: cfg.hp || Z.st.maxhp, max: cfg.hp || Z.st.maxhp, inv: 0, x: W / 2, y: H / 2},
    hurt(d, x = this.hero.x, y = this.hero.y, raw) { if (this.end) return 0; const v = raw ? d : taken(d, Z.st.def); this.hero.hp -= v; this.hero.inv = .5; sfx('hit'); FB.num(x, y - 30, `-${v}`, {c: '#ff6b6b'}); C.shake(6); flash = .35; return v; },
    num(x, y, d, crit) { FB.num(x, y, crit ? `${d}!` : String(d), {crit}); FB.sparks(x, y + 20, crit ? 9 : 5, crit ? '#ffe066' : '#fff'); C.shake(crit ? 4 : 2); C.stop(.04); },
    loot(g, x, y) { const v = Math.round(g * Z.st.goldMul); this.gold += v; sfx('coin'); F.text(x, y - 20, `+${v}`, '#ffd43b'); },
    kill(boss) { this.kills++; this.xp += Math.round((3 + Z.r * 2) * (boss ? 10 : 1)); },
    keys: new Set()
  };
  const kd = e => G.keys.add(e.key.toLowerCase()), ku = e => G.keys.delete(e.key.toLowerCase());
  addEventListener('keydown', kd); addEventListener('keyup', ku);
  const game = init(G);
  const res = await loop({
    update(rdt) {
      C.update(rdt); const dt = rdt * C.scale(rdt); flash = Math.max(0, flash - rdt);
      G.t += dt; F.update(dt); FB.update(dt); G.hero.inv = Math.max(0, G.hero.inv - dt);
      for (const g of ghosts) g.dieT += dt * 2; ghosts = ghosts.filter(g => g.dieT < 1);
      if (G.end) { G.endT += dt; if (G.endT > 2) { removeEventListener('keydown', kd); removeEventListener('keyup', ku); return {win: G.end === 'win', gold: G.gold, xp: G.xp, kills: G.kills, potions: Z.potions}; } return null; }
      if (G.introT > 0) { G.introT -= dt; return null; }
      if (B.hit('pot')) potionUse(Z, G.hero, F);
      if (Z.st.regen && !cfg.noPotion) G.hero.hp = Math.min(G.hero.max, G.hero.hp + G.hero.max * Z.st.regen * dt);
      game.update(dt);
      if (G.hero.hp <= 0) { G.hero.hp = 0; G.end = 'lose'; sfx('wrong'); }
      else if (game.done()) { G.end = 'win'; sfx('win'); F.burst(W / 2, H / 2, 60); }
      else if (game.lose) { G.end = 'lose'; sfx('wrong'); }
      return null;
    },
    draw() {
      C.begin(ctx);
      game.draw();
      for (const g of ghosts) drawMob(ctx, g.img, g, g.sheet ? {sheet: SP[g.sheet], anim: g.anim, frame: g.frame, pixel: g.pixel} : {});
      FB.draw(ctx);
      C.end(ctx);
      F.draw(ctx);
      if (flash > 0) { const gr = ctx.createRadialGradient(W / 2, H / 2, S * .3, W / 2, H / 2, Math.max(W, H) * .75); gr.addColorStop(0, 'rgba(255,0,0,0)'); gr.addColorStop(1, `rgba(255,30,30,${flash * 1.2})`); ctx.fillStyle = gr; ctx.fillRect(0, 0, W, H); }
      topHud(ctx, W, Z, G.hero.hp, G.hero.max, G.gold, game.goal());
      if (!cfg.noPotion) { B.draw(ctx); drawPotionCount(ctx, pot, Z.potions); }
      if (G.introT > 0) zoneIntro(ctx, W, H, Z, cfg.name, cfg.goalText, cfg.hint);
      if (G.end) endBanner(ctx, W, H, G.end === 'win', G.gold);
      fade(ctx, W, H, G.t, G.end ? G.endT : 0);
    }
  }, Z.alive);
  removeEventListener('keydown', kd); removeEventListener('keyup', ku);
  return res;
}

// ---------- 3. Hang Mỏ: mê cung, đào đá tìm ngọc, tìm chìa khoá rồi tới cửa; trùm Nhện Chúa canh cửa ----------
export const mine = (box, Z) => shell(box, Z, {
  name: 'Hang Mỏ', goalText: Z.boss ? 'Đánh bại Nhện Chúa canh cửa' : 'Tìm 🔑 chìa khoá rồi tới 🚪 cửa',
  hint: 'Bấm mũi tên hoặc vuốt để đi · đi vào đá để đào · đi vào dơi để đánh',
  imgs: ['Rock', 'Gem stone', 'Old key', 'Door', 'Bat', 'Spider', 'Pick', 'Fire'],
  pot: (W, H, S) => { const br = Math.min(40, S * .07); return {x: W - br * 2.6 - 10 - br * 3.4, y: H - br * 1.2 - 10}; }
}, G => {
  const {W, H, S, ctx, M, F} = G;
  let C = Z.s >= 3 ? 15 : 13, R = Z.s >= 3 ? 9 : 7;
  if (H > W) [C, R] = [R, C];  // màn dọc: mê cung dựng đứng cho ô to hơn
  const br = Math.min(40, S * .07), padW = br * 6.2 + 20, padH = br * 6 + 20, land = W > H;
  const topB = !land && Z.boss ? 40 : 0;  // màn dọc: chừa chỗ thanh máu trùm ở trên
  const aw = land ? W - padW - 24 : W - 24, ah = (land ? H - 96 : H - 96 - padH) - topB;
  const cs = Math.floor(Math.min(aw / C, ah / R)), ox = 12 + Math.round((aw - C * cs) / 2), oy = 80 + topB + Math.round((ah - R * cs) / 2);
  // Mê cung: 0 trống, 1 tường, 2 đá đào được
  const g = Array.from({length: R}, () => Array(C).fill(1));
  const stack = [[1, 1]]; g[1][1] = 0;
  while (stack.length) {
    const [x, y] = stack[stack.length - 1];
    const nb = [[2, 0], [-2, 0], [0, 2], [0, -2]].map(([dx, dy]) => [x + dx, y + dy, dx, dy]).filter(([nx, ny]) => nx > 0 && ny > 0 && nx < C - 1 && ny < R - 1 && g[ny][nx] === 1);
    if (!nb.length) { stack.pop(); continue; }
    const [nx, ny, dx, dy] = pick(nb); g[y + dy / 2][x + dx / 2] = 0; g[ny][nx] = 0; stack.push([nx, ny]);
  }
  const gems = new Set();
  for (let y = 1; y < R - 1; y++) for (let x = 1; x < C - 1; x++) if (g[y][x] === 1 && Math.random() < .3) { g[y][x] = 2; if (Math.random() < .45) gems.add(`${x},${y}`); }
  const bfs = (sx, sy) => { const d = Array.from({length: R}, () => Array(C).fill(-1)); const q = [[sx, sy]]; d[sy][sx] = 0; while (q.length) { const [x, y] = q.shift(); for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const nx = x + dx, ny = y + dy; if (g[ny]?.[nx] === 0 && d[ny][nx] < 0) { d[ny][nx] = d[y][x] + 1; q.push([nx, ny]); } } } return d; };
  const d0 = bfs(1, 1); let far = [1, 1];
  for (let y = 0; y < R; y++) for (let x = 0; x < C; x++) if (d0[y][x] > d0[far[1]][far[0]]) far = [x, y];
  const key = Z.boss ? null : {x: far[0], y: far[1]};
  const dk = bfs(far[0], far[1]); let door = [1, 1], best = -1;
  for (let y = 0; y < R; y++) for (let x = 0; x < C; x++) { const v = Math.min(dk[y][x], d0[y][x] * 1.2); if (dk[y][x] > 0 && d0[y][x] > 3 && v > best) { best = v; door = [x, y]; } }
  if (Z.boss) door = far;
  const me = {x: 1, y: 1, px: 1, py: 1, face: 1, swing: 0};
  // Hang vẽ sẵn bằng ô Tiny Dungeon (pixel): tường gạch đá, nền đất; đá đào được vẽ riêng
  const DT = G.SP['kenney-tiny-dungeon/dungeon'], TL = G.SP['kenney-platformer/tiles'];
  const cave = DT?.img.naturalWidth ? prerender(W, H, b => {
    b.fillStyle = '#2b1d16'; b.fillRect(0, 0, W, H); b.imageSmoothingEnabled = false;
    for (let y = 0; y < R; y++) for (let x = 0; x < C; x++) {
      const fr = DT.frames[g[y][x] === 1 ? (y === R - 1 || g[y + 1]?.[x] !== 1 ? 't40' : 't57') : ((x * 7 + y * 3) % 5 ? 't0' : 't12')];
      b.drawImage(DT.img, fr[0], fr[1], fr[2], fr[3], ox + x * cs, oy + y * cs, cs, cs);
    }
  }) : null;
  let hasKey = !!Z.boss, moveT = 0, held = null;
  const foes = [];
  const open = (x, y) => g[y]?.[x] === 0;
  const randOpen = minD => { for (let k = 0; k < 200; k++) { const x = 1 + Math.floor(rand(0, C - 2)), y = 1 + Math.floor(rand(0, R - 2)); if (open(x, y) && d0[y][x] >= minD && !(x === door[0] && y === door[1])) return [x, y]; } return null; };
  for (let i = 0; i < (Z.boss ? 1 : 2 + Z.s); i++) { const p = randOpen(5); if (p) foes.push({x: p[0], y: p[1], px: p[0], py: p[1], img: 'Bat', ...foeStats(2, Z.s, .8), cd: rand(.5, 1), hurt: 0}); }
  let boss = null;
  if (Z.boss) { boss = {x: door[0], y: door[1], px: door[0], py: door[1], img: 'Spider', boss: true, ...foeStats(2, 5, 8), cd: 2, sp: 4, hurt: 0}; boss.max = boss.hp; foes.push(boss); }
  for (const f of foes) f.max = f.hp;
  // Điều khiển: nút mũi tên, vuốt, phím
  const bx = W - br * 2.9 - 10, by = H - br * 2.9 - 6;
  const pad = buttons(M, [{id: 'u', x: bx, y: by - br * 1.6, r: br, label: '⬆'}, {id: 'd', x: bx, y: by + br * 1.6, r: br, label: '⬇'}, {id: 'l', x: bx - br * 1.8, y: by, r: br, label: '◀'}, {id: 'r', x: bx + br * 1.8, y: by, r: br, label: '▶'}]);
  M.on('up', p => { if (p.btn) return; const dx = p.x - p.sx, dy = p.y - p.sy; if (Math.hypot(dx, dy) < 25) return; held = null; tryMove(Math.abs(dx) > Math.abs(dy) ? [Math.sign(dx), 0] : [0, Math.sign(dy)]); });
  const at = (x, y) => foes.find(f => !f.dead && f.x === x && f.y === y);
  function tryMove([dx, dy]) {
    const nx = me.x + dx, ny = me.y + dy; if (dx) me.face = dx;
    const f = at(nx, ny);
    if (f) { const s = strike(Z.st); f.hp -= s.d; f.hurt = .2; me.swing = .25; sfx('hit'); G.FB.slash(ox + (me.x + .5) * cs, oy + (me.y + .5) * cs, cs * .7, Math.atan2(dy, dx), dx < 0 ? -1 : 1);
      G.num(ox + (nx + .5) * cs, oy + ny * cs - 10, s.d, s.crit);
      if (f.hp <= 0) { f.dead = true; G.die({sheet: 'kenney-tiny-dungeon/dungeon', frame: f.img === 'Spider' ? 't122' : 't120', pixel: true, x: ox + (nx + .5) * cs, y: oy + (ny + .5) * cs, size: cs * (f.boss ? 1.5 : .85), boss: f.boss}); G.kill(f.boss); F.burst(ox + (nx + .5) * cs, oy + (ny + .5) * cs, f.boss ? 40 : 14); G.loot((2 + Z.r * 3) * (f.boss ? 15 : 1), ox + (nx + .5) * cs, oy + ny * cs); sfx(f.boss ? 'boom' : 'pop'); }
      return; }
    if (g[ny]?.[nx] === 2) { g[ny][nx] = 0; me.swing = .25; sfx('boom'); G.C.shake(3); G.FB.dust(ox + (nx + .5) * cs, oy + (ny + .8) * cs, 5, 0, 'rgba(173,181,189,.8)'); F.burst(ox + (nx + .5) * cs, oy + (ny + .5) * cs, 10, ['#868e96', '#adb5bd', '#ced4da']); if (gems.has(`${nx},${ny}`)) { G.loot(4 + Z.r * 3, ox + (nx + .5) * cs, oy + ny * cs); F.star(ox + (nx + .5) * cs, oy + ny * cs); } return; }
    if (!open(nx, ny)) return;
    if (nx === door[0] && ny === door[1] && !hasKey) { F.text(ox + (nx + .5) * cs, oy + ny * cs, Z.boss ? '' : 'Cần 🔑', '#fff'); return; }
    me.px = me.x; me.py = me.y; me.x = nx; me.y = ny; me.mt = 0;
    if (key && !hasKey && nx === key.x && ny === key.y) { hasKey = true; sfx('correct'); F.burst(ox + (nx + .5) * cs, oy + (ny + .5) * cs, 24); F.text(ox + (nx + .5) * cs, oy + ny * cs, 'Có chìa khoá!', '#ffd43b'); }
  }
  let won = false;
  return {
    update(dt) {
      me.swing = Math.max(0, me.swing - dt); me.mt = (me.mt ?? 1) + dt;
      moveT -= dt;
      const dir = pad.down('u') || G.keys.has('arrowup') || G.keys.has('w') ? [0, -1] : pad.down('d') || G.keys.has('arrowdown') || G.keys.has('s') ? [0, 1] : pad.down('l') || G.keys.has('arrowleft') || G.keys.has('a') ? [-1, 0] : pad.down('r') || G.keys.has('arrowright') || G.keys.has('d') ? [1, 0] : null;
      if (dir && moveT <= 0) { tryMove(dir); moveT = .2; }
      if (!dir) moveT = 0;
      for (const f of foes) {
        if (f.dead) continue; f.hurt = Math.max(0, f.hurt - dt); f.cd -= dt; f.mt = (f.mt ?? 1) + dt;
        if (f.cd > 0) continue;
        const near = Math.abs(f.x - me.x) + Math.abs(f.y - me.y);
        if (f.boss) {
          f.cd = 1.3;
          if (near === 1) { G.hurt(f.dmg, ox + (me.x + .5) * cs, oy + me.y * cs); }
          f.sp -= 1.3; if (f.sp <= 0 && foes.filter(x => !x.dead).length < 4) { f.sp = 5; const p = randOpen(2); if (p) foes.push({x: p[0], y: p[1], px: p[0], py: p[1], img: 'Spider', ...foeStats(2, 2, .6), cd: 1, hurt: 0, small: true}); foes[foes.length - 1].max = foes[foes.length - 1].hp; }
          continue;
        }
        f.cd = rand(.55, .85);
        const opts = [[1, 0], [-1, 0], [0, 1], [0, -1]].filter(([dx, dy]) => open(f.x + dx, f.y + dy) && !at(f.x + dx, f.y + dy) && !(f.x + dx === door[0] && f.y + dy === door[1]));
        if (near === 1) { G.hurt(f.dmg, ox + (me.x + .5) * cs, oy + me.y * cs); f.cd = 1.1; continue; }
        if (!opts.length) continue;
        let mv = pick(opts);
        if (near < 5) mv = opts.reduce((b, o) => Math.abs(f.x + o[0] - me.x) + Math.abs(f.y + o[1] - me.y) < Math.abs(f.x + b[0] - me.x) + Math.abs(f.y + b[1] - me.y) ? o : b);
        if (f.x + mv[0] === me.x && f.y + mv[1] === me.y) continue;
        f.px = f.x; f.py = f.y; f.x += mv[0]; f.y += mv[1]; f.mt = 0;
      }
      if (boss && boss.dead) hasKey = true;
      if (hasKey && me.x === door[0] && me.y === door[1]) won = true;
      if (boss && boss.dead) won = true;
    },
    draw() {
      if (cave) {
        ctx.drawImage(cave, 0, 0, W, H);
        for (let y = 0; y < R; y++) for (let x = 0; x < C; x++) if (g[y][x] === 2) {
          const X = ox + (x + .5) * cs, Y = oy + (y + .5) * cs;
          if (!spr(ctx, TL, 'rock', X, Y, cs * .95)) draw(ctx, 'Rock', X, Y, cs * .95);
          if (gems.has(`${x},${y}`) && Math.sin(G.t * 4 + x * 3 + y) > .7) draw(ctx, 'Sparkles', X + cs * .25, Y - cs * .25, cs * .35);
        }
      } else for (let y = 0; y < R; y++) for (let x = 0; x < C; x++) {
        const X = ox + x * cs, Y = oy + y * cs;
        if (g[y][x] === 1) { ctx.fillStyle = '#4e342e'; ctx.fillRect(X, Y, cs, cs); ctx.fillStyle = '#3e2723'; ctx.fillRect(X + 2, Y + cs * .6, cs - 4, cs * .35); }
        else { ctx.fillStyle = (x + y) % 2 ? '#a1887f' : '#9c8075'; ctx.fillRect(X, Y, cs, cs); if (g[y][x] === 2) draw(ctx, 'Rock', X + cs / 2, Y + cs / 2, cs * .95); }
        if (g[y][x] === 2 && gems.has(`${x},${y}`) && Math.sin(G.t * 4 + x * 3 + y) > .7) draw(ctx, 'Sparkles', X + cs * .75, Y + cs * .25, cs * .35);
      }
      const P = o => { const k = E.outCubic(Math.min(1, (o.mt ?? 1) / .14)); return [ox + (o.px + (o.x - o.px) * k + .5) * cs, oy + (o.py + (o.y - o.py) * k + .5) * cs]; };
      if (!spr(ctx, DT, hasKey ? 't46' : 't45', ox + (door[0] + .5) * cs, oy + (door[1] + .5) * cs, cs, {pixel: true})) draw(ctx, 'Door', ox + (door[0] + .5) * cs, oy + (door[1] + .5) * cs, cs * .95);
      if (key && !hasKey) { const kx = ox + (key.x + .5) * cs, ky = oy + (key.y + .5) * cs + Math.sin(G.t * 4) * 4; if (!spr(ctx, TL, 'key_yellow', kx, ky, cs * .8, {rot: Math.sin(G.t * 2) * .2})) draw(ctx, 'Old key', kx, ky, cs * .8); }
      for (const f of foes) if (!f.dead) {
        const [x, y] = P(f), sz = cs * (f.boss ? 1.5 : .85);
        // Dơi + nhện Tiny Dungeon (pixel), bay nhấp nhô, nháy sáng khi trúng đòn
        f.v = f.v || {}; Object.assign(f.v, {x, y, size: sz, t: G.t + f.x * .7, hurt: f.hurt, flip: me.x > f.x, fly: f.img === 'Bat', moving: (f.mt ?? 1) < .3, atk: 0});
        drawMob(ctx, f.img, f.v, DT ? {sheet: DT, frame: f.img === 'Spider' ? 't122' : 't120', pixel: true} : {});
        if (!f.boss && f.hp < f.max) hpBar(ctx, x - cs * .4, y - cs * .55, cs * .8, 7, f.hp, f.max);
      }
      const [hx, hy] = P(me);
      drawHero(ctx, hx, hy - cs * .05, cs * .9, Z, {face: me.face, swing: me.swing, hurt: G.hero.inv, t: G.t, moving: (me.mt ?? 1) < .2});
      if (hasKey && key && !spr(ctx, TL, 'key_yellow', hx + cs * .35, hy - cs * .4, cs * .4)) draw(ctx, 'Old key', hx + cs * .35, hy - cs * .4, cs * .4);
      pad.draw(ctx);
      if (boss && !boss.dead) bossBar(ctx, W, H, boss, 'Nhện Chúa', land ? H - 30 : 98);
    },
    done: () => won,
    goal: () => Z.boss ? null : hasKey ? '🚪 Tới cửa!' : '🔑 Tìm chìa khoá'
  };
});

// ---------- 4. Xứ Tuyết: đánh theo lượt; ⚔️ bấm đúng lúc vạch ở giữa để đánh mạnh; trùm Voi Ma Mút ----------
export const snow = (box, Z) => shell(box, Z, {
  name: 'Xứ Tuyết', goalText: Z.boss ? 'Đánh bại Voi Ma Mút' : `Thắng ${2 + Math.floor(Z.s / 3)} đợt quái`,
  hint: 'Đến lượt bé: chọn ⚔️ Đánh, ❄️ Phép hoặc 🛡 Đỡ',
  imgs: ['Wolf', 'Polar bear', 'Snowman', 'Mammoth', 'Snowflake', 'Evergreen tree', 'Snow-capped mountain', 'Shield']
}, G => {
  const {W, H, S, ctx, M, F} = G;
  const waves = Z.boss ? [['Wolf', 'Mammoth', 'Wolf']] : Array.from({length: 2 + Math.floor(Z.s / 3)}, (_, i) => Array.from({length: Math.min(3, 1 + Math.floor((Z.s + i + 1) / 2))}, () => pick(Z.s >= 2 ? ['Wolf', 'Polar bear', 'Snowman'] : ['Wolf', 'Snowman'])));
  let wave = 0, foes = [], state = 'choose', stT = 0, mana = 2, defend = false, target = 0, turn = 0, bar = 0, barDir = 1, mult = 1, act = null, queue = [], msg = '';
  const hx = W * .24, hy = H * .58;
  const spawn = () => {
    const list = waves[wave];
    foes = list.map((k, i) => { const boss = k === 'Mammoth'; const s = foeStats(3, Z.s, boss ? 7 : k === 'Polar bear' ? 2.2 : 1.6); const n = list.length;
      return {img: k, boss, name: boss ? 'Voi Ma Mút' : '', ...s, max: s.hp, x: W * .72 + (n > 1 ? (i - (n - 1) / 2) * W * .1 : 0) * (i % 2 ? 1 : -1) * 0 + (i - (n - 1) / 2) * W * .07, y: hy + (i - (n - 1) / 2) * H * .17, size: S * (boss ? .3 : .15), hurt: 0, lunge: 0}; });
    target = foes.findIndex(f => f.boss); if (target < 0) target = 0;
  };
  spawn();
  const br = Math.min(50, S * .08), by = H - br - 18;
  const acts = [{id: 'atk', x: W / 2 - br * 3.4, y: by, r: br, label: '⚔️', c: '#ff922b'}, {id: 'mag', x: W / 2 - br * 1.1, y: by, r: br, label: '❄️', c: '#74c0fc'}, {id: 'def', x: W / 2 + br * 1.2, y: by, r: br, label: '🛡', c: '#adb5bd'}, {id: 'go', x: W / 2, y: by, r: br * 1.3, label: '👊', c: '#ff922b', hidden: true}];
  const AB = buttons(M, acts);
  M.on('down', p => { if (p.btn) return; if (state === 'timing') { stopBar(); return; } if (state === 'choose') foes.forEach((f, i) => { if (f.hp > 0 && dist(p, f) < f.size * .6) { target = i; sfx('tap'); } }); });
  const alive = () => foes.filter(f => f.hp > 0);
  const hitFoe = (f, d, crit) => { f.hp -= d; f.hurt = .3; G.num(f.x, f.y - f.size * .6, d, crit); if (f.hp <= 0) { f.hp = 0; G.die({img: f.img, x: f.x, y: f.y, size: f.size, boss: f.boss}); G.kill(f.boss); sfx(f.boss ? 'boom' : 'pop'); F.burst(f.x, f.y, f.boss ? 40 : 16, ['#fff', '#a5d8ff', '#74c0fc']); G.loot((2 + Z.r * 3) * (f.boss ? 15 : 1.5), f.x, f.y); } };
  function stopBar() { const off = Math.abs(bar); mult = off < .18 ? 1.6 : off < .55 ? 1 : .6; msg = off < .18 ? 'TUYỆT VỜI!' : off < .55 ? 'Tốt!' : 'Hơi lệch'; state = 'hero'; stT = 0; act = 'atk'; sfx(off < .18 ? 'star' : 'tap'); }
  function enemyPhase() { queue = alive().map(f => f); state = 'enemy'; stT = 0; }
  const ensureTarget = () => { if (!foes[target] || foes[target].hp <= 0) target = foes.findIndex(f => f.hp > 0); };
  let won = false;
  return {
    update(dt) {
      stT += dt; for (const f of foes) { f.hurt = Math.max(0, f.hurt - dt); f.lunge = Math.max(0, f.lunge - dt); }
      for (const a of acts) a.hidden = a.id === 'go' ? state !== 'timing' : state !== 'choose';
      if (state === 'choose') {
        ensureTarget();
        if (AB.hit('atk')) { state = 'timing'; bar = -1; barDir = 1; sfx('tap'); }
        else if (AB.hit('mag')) { if (mana >= 2) { mana -= 2; act = 'mag'; state = 'hero'; stT = 0; sfx('power'); } else { sfx('wrong'); F.text(W / 2, H * .3, 'Cần 2 ❄️', '#fff'); } }
        else if (AB.hit('def')) { defend = true; G.hero.hp = Math.min(G.hero.max, G.hero.hp + G.hero.max * .08); F.text(hx, hy - 60, '🛡 Đỡ', '#fff'); act = null; state = 'pet'; stT = 0; }
      } else if (state === 'timing') {
        bar += barDir * dt * (1.4 + Z.s * .12); if (bar > 1) { bar = 1; barDir = -1; } if (bar < -1) { bar = -1; barDir = 1; }
        if (AB.hit('go') || G.keys.has(' ')) stopBar();
      } else if (state === 'hero') {
        if (stT > .35 && act) {
          if (act === 'atk') { const f = foes[target]; const s = strike(Z.st, mult); hitFoe(f, s.d, s.crit); sfx('hit'); F.text(hx, hy - 80, msg, '#ffd43b'); }
          else { for (const f of alive()) { const s = strike(Z.st, .9); hitFoe(f, s.d, s.crit); } F.burst(W * .72, hy, 50, ['#fff', '#d0ebff', '#74c0fc']); sfx('boom'); }
          act = null;
        }
        if (stT > .9) { state = 'pet'; stT = 0; }
      } else if (state === 'pet') {
        if (stT > .2 && Z.pet && !G.petDone) {
          G.petDone = true; ensureTarget(); const f = foes[target];
          if (Z.pet === 'dog' && f) { hitFoe(f, Math.round(Z.st.atk * .4)); sfx('bark'); }
          else if (Z.pet === 'fairy') { G.hero.hp = Math.min(G.hero.max, G.hero.hp + G.hero.max * .06); F.text(hx, hy - 60, '+máu', '#69db7c'); }
          else if (Z.pet === 'dragon') { for (const x of alive()) hitFoe(x, Math.round(Z.st.atk * .3)); F.burst(W * .72, hy, 20, ['#ff922b', '#ffd43b']); }
        }
        if (stT > (Z.pet ? .8 : .1)) { G.petDone = false; if (!alive().length) { wave++; if (wave >= waves.length) won = true; else { spawn(); state = 'banner'; stT = 0; } } else enemyPhase(); }
      } else if (state === 'enemy') {
        const f = queue[0];
        if (!f) { turn++; mana = Math.min(4, mana + 1); defend = false; state = 'choose'; stT = 0; }
        else if (stT > .65) {
          queue.shift(); stT = 0;
          if (f.hp > 0) { f.lunge = .35; const big = f.boss && turn % 3 === 2; const d = taken(Math.round(f.dmg * (big ? 1.6 : 1)), Z.st.def) * (defend ? .5 : 1); G.hurt(Math.max(1, Math.round(d)), hx, hy, true); if (big) { F.text(hx, hy - 90, 'DẬM ĐẤT!', '#ff8787'); sfx('boom'); } }
        }
      } else if (state === 'banner') { if (stT > 1.4) state = 'choose'; }
    },
    draw() {
      const g = ctx.createLinearGradient(0, 0, 0, H); g.addColorStop(0, '#a5d8ff'); g.addColorStop(1, '#f8f9fa'); ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
      draw(ctx, 'Snow-capped mountain', W * .3, H * .32, S * .4); draw(ctx, 'Snow-capped mountain', W * .75, H * .28, S * .5);
      ctx.fillStyle = '#fff'; ctx.fillRect(0, H * .45, W, H);
      const TL = G.SP['kenney-platformer/tiles'], ts = S * .08;
      if (TL?.img.naturalWidth) for (let x = 0; x < W + ts; x += ts) spr(ctx, TL, 'terrain_snow_block_top', x, H * .45 + ts / 2, ts);
      for (let i = 0; i < 4; i++) draw(ctx, 'Evergreen tree', (i * W / 3.5 + 40) % W, H * .45 - S * .03, S * .1);
      for (let i = 0; i < 30; i++) { ctx.fillStyle = 'rgba(255,255,255,.9)'; ctx.beginPath(); ctx.arc((i * 97 + G.t * 20) % W, (i * 61 + G.t * 40) % H, 3, 0, 7); ctx.fill(); }
      const lx = state === 'hero' && stT < .7 ? hx + Math.sin(Math.min(1, stT / .7) * Math.PI) * (W * .3) : hx;
      const dash = state === 'hero' && act === 'atk' && stT < .3;
      drawHero(ctx, lx, hy, S * .2, Z, {face: 1, swing: state === 'hero' && stT > .3 && stT < .55 ? .25 - (stT - .3) : 0, hurt: G.hero.inv, t: G.t, pose: dash ? 'run' : defend ? 'block' : state === 'hero' && act === 'mag' ? 'cheer' : null});
      if (defend) draw(ctx, 'Shield', hx + S * .1, hy, S * .1);
      if (Z.pet) { G.petRig = G.petRig || petBuddy(PET_RIG[Z.pet] || 'dog'); G.petRig.update(1 / 60, false); G.petRig.draw(ctx, hx - S * .14, hy + S * .1, S * .045); }
      foes.forEach((f, i) => {
        if (f.hp <= 0) return;
        const x = f.x - E.bump(f.lunge / .35) * W * .12;
        if (i === target && state === 'choose') { ctx.strokeStyle = '#ffd43b'; ctx.lineWidth = 4; ctx.beginPath(); ctx.ellipse(f.x, f.y + f.size * .42, f.size * .45, f.size * .13, 0, 0, 7); ctx.stroke(); draw(ctx, 'Glowing star', f.x, f.y - f.size * .75 + Math.sin(G.t * 5) * 4, 26); }
        // Thở nhẹ khi đứng, co người lấy đà rồi lao tới khi tấn công, dẹt + nháy khi trúng
        f.v = f.v || {}; Object.assign(f.v, {x, y: f.y, size: f.size, t: G.t + i, hurt: Math.min(.15, f.hurt), flip: false, moving: false, wind: f.lunge > .25 ? (.35 - f.lunge) / .1 : 0, atk: f.lunge > 0 && f.lunge <= .25 ? 1 - f.lunge / .25 : 0});
        drawMob(ctx, f.img, f.v);
        if (!f.boss) hpBar(ctx, f.x - f.size * .4, f.y - f.size * .62, f.size * .8, 10, f.hp, f.max);
      });
      const bs = foes.find(f => f.boss && f.hp > 0); if (bs) bossBar(ctx, W, H * .82, bs, bs.name);
      if (bs && turn % 3 === 1 && state === 'choose') { ctx.fillStyle = '#c92a2a'; ctx.font = '800 20px "Baloo 2", sans-serif'; ctx.textAlign = 'center'; ctx.fillText('Voi ma mút đang lấy đà! Bấm 🛡 Đỡ', W / 2, H * .25); }
      // Năng lượng phép
      ctx.textAlign = 'left'; ctx.font = '800 18px "Baloo 2", sans-serif'; ctx.fillStyle = '#1864ab'; ctx.fillText('Phép:', 16, H * .25 + 40);
      for (let i = 0; i < 4; i++) draw(ctx, 'Snowflake', 80 + i * 30, H * .25 + 34, 26, 26, {alpha: i < mana ? 1 : .2});
      if (state === 'choose') { ctx.fillStyle = '#212529'; ctx.font = '800 20px "Baloo 2", sans-serif'; ctx.textAlign = 'center'; ctx.fillText('Lượt của bé! Chạm quái để chọn', W / 2, by - br - 14); }
      if (state === 'timing') {
        const bw = Math.min(520, W * .8), bx = W / 2 - bw / 2, y = H * .3;
        ctx.fillStyle = '#ff8787'; roundRect(ctx, bx, y, bw, 30, 15); ctx.fill();
        ctx.fillStyle = '#ffd43b'; ctx.fillRect(bx + bw * .225, y, bw * .55, 30); ctx.fillStyle = '#51cf66'; ctx.fillRect(bx + bw * .41, y, bw * .18, 30);
        ctx.fillStyle = '#212529'; ctx.fillRect(bx + bw * (bar + 1) / 2 - 4, y - 8, 8, 46);
        ctx.font = '800 20px "Baloo 2", sans-serif'; ctx.textAlign = 'center'; ctx.fillText('Bấm 👊 khi vạch ở ô XANH!', W / 2, y - 16);
      }
      if (state === 'banner') { ctx.fillStyle = 'rgba(0,0,0,.35)'; ctx.fillRect(0, H / 2 - 40, W, 80); ctx.fillStyle = '#fff'; ctx.font = '800 40px "Baloo 2", sans-serif'; ctx.textAlign = 'center'; ctx.fillText(`Đợt ${wave + 1}`, W / 2, H / 2 + 14); }
      AB.draw(ctx);
    },
    done: () => won,
    goal: () => Z.boss ? null : `❄️ Đợt ${Math.min(wave + 1, waves.length)}/${waves.length}`
  };
});

// ---------- 5. Sa Mạc: đào cát tìm kho báu (ô càng đỏ càng gần), gặp bọ cạp thì chạm để đánh; trùm Bọ Cạp Vua chui lên chui xuống ----------
export const desert = (box, Z) => shell(box, Z, {
  name: 'Sa Mạc', goalText: Z.boss ? 'Chạm Bọ Cạp Vua mỗi khi nó chui lên' : `Đào được ${3 + Math.floor(Z.s / 2)} kho báu`,
  hint: 'Chạm ô cát để đào · 🔥 đỏ là gần kho báu, ❄️ xanh là xa',
  imgs: ['Scorpion', 'Money bag', 'Gem stone', 'Wrapped gift', 'Cactus', 'Camel', 'Desert', 'Sun with face', 'Hole']
}, G => {
  const {W, H, S, ctx, M, F} = G;
  const C = Z.s >= 3 ? 8 : 7, R = 5, NT = Z.boss ? 0 : 3 + Math.floor(Z.s / 2), NS = Z.boss ? 0 : 2 + Math.floor(Z.s / 2);
  const cs = Math.floor(Math.min((W - 40) / C, (H - 200) / R)), ox = Math.round((W - C * cs) / 2), oy = 110 + Math.round((H - 190 - R * cs) / 2);
  const cells = Array.from({length: R}, (_, y) => Array.from({length: C}, (_, x) => ({x, y, dug: false, has: null})));
  const all = cells.flat(), free = () => all.filter(c => !c.has);
  for (let i = 0; i < NT; i++) pick(free()).has = pick(['Money bag', 'Gem stone', 'Wrapped gift']);
  for (let i = 0; i < NS; i++) pick(free()).has = 'Scorpion';
  let digs = NT * 4 + 5 + NS, found = 0, fight = null, digT = null, boss = null;
  if (Z.boss) { boss = {...foeStats(4, 5, 9), name: 'Bọ Cạp Vua', cell: null, up: 0, cd: 1.2, stings: 0}; boss.max = boss.hp; }
  const cellAt = p => { const x = Math.floor((p.x - ox) / cs), y = Math.floor((p.y - oy) / cs); return cells[y]?.[x]; };
  const heat = c => { let d = 99; for (const o of all) if (o.has && o.has !== 'Scorpion' && !o.dug) d = Math.min(d, Math.abs(o.x - c.x) + Math.abs(o.y - c.y)); return d; };
  M.on('down', p => {
    if (p.btn || G.introT > 0) return;
    if (boss) { const c = cellAt(p); if (boss.cell && boss.up > 0 && c === boss.cell) { const s = strike(Z.st); boss.hp -= s.d; boss.up = 0; boss.hide = .3; sfx('hit'); G.num(p.x, p.y - 30, s.d, s.crit); F.burst(p.x, p.y, 16, ['#ffd8a8', '#fab005']); if (boss.hp <= 0) { G.die({img: 'Scorpion', x: p.x, y: p.y, size: cs * 1.3, boss: true}); G.kill(true); G.loot((2 + Z.r * 3) * 15, p.x, p.y); sfx('boom'); } } return; }
    if (fight) { if (dist(p, fight) < cs * .8) { const s = strike(Z.st); fight.hp -= s.d; fight.hurt = .2; sfx('hit'); G.num(fight.x, fight.y - cs * .4, s.d, s.crit); if (fight.hp <= 0) { G.die({img: 'Scorpion', x: fight.x, y: fight.y, size: cs * 1.1}); G.kill(); G.loot((2 + Z.r * 3) * 1.5, fight.x, fight.y); F.burst(fight.x, fight.y, 16); sfx('pop'); fight = null; } } return; }
    const c = cellAt(p); if (!c || c.dug || digT || digs <= 0) return;
    digT = {c, t: 0}; sfx('tap');
  });
  return {
    update(dt) {
      if (boss) {
        if (boss.hp <= 0) return;
        boss.cd -= dt;
        if (boss.up > 0) { boss.up -= dt; if (boss.up <= 0) { boss.stings++; G.hurt(boss.dmg, boss.cell ? ox + (boss.cell.x + .5) * cs : W / 2, oy + (boss.cell?.y || 0) * cs); boss.cell = null; boss.cd = .8; } }
        else if (boss.cd <= 0) { boss.cell = pick(all); boss.up = boss.upMax = Math.max(.9, 1.9 - Z.s * .1 - (1 - boss.hp / boss.max) * .6); boss.cd = rand(.5, 1); sfx('pop'); G.FB.dust(ox + (boss.cell.x + .5) * cs, oy + (boss.cell.y + .8) * cs, 6, 0, 'rgba(250,176,5,.7)'); }
        return;
      }
      if (fight) { fight.hurt = Math.max(0, fight.hurt - dt); fight.cd -= dt; fight.atkT = Math.max(0, (fight.atkT || 0) - dt); if (fight.cd <= 0) { fight.cd = 1.4; fight.atkT = .35; G.hurt(fight.dmg, fight.x, fight.y); } }
      if (digT) {
        digT.t += dt;
        if (digT.t > .3) {
          const c = digT.c; c.dug = true; digs--; digT = null;
          const X = ox + (c.x + .5) * cs, Y = oy + (c.y + .5) * cs;
          F.burst(X, Y, 10, ['#ffd8a8', '#fab005', '#e8590c']); G.FB.dust(X, Y + cs * .3, 4, 0, 'rgba(250,176,5,.6)'); G.C.shake(1.5);
          if (c.has === 'Scorpion') { const s = foeStats(4, Z.s, 1.2); fight = {x: X, y: Y, ...s, max: s.hp, cd: 1, hurt: 0}; sfx('wrong'); F.text(X, Y - cs * .5, 'Bọ cạp!', '#ff8787'); }
          else if (c.has) { found++; G.loot(8 + Z.r * 6, X, Y); F.star(X, Y); sfx('correct'); G.xp += 5; }
          else { const h = heat(c); sfx(h <= 1 ? 'star' : 'pop'); }
        }
      }
    },
    draw() {
      const g = ctx.createLinearGradient(0, 0, 0, H); g.addColorStop(0, '#ffa94d'); g.addColorStop(.35, '#ffe8cc'); g.addColorStop(1, '#ffd8a8'); ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
      draw(ctx, 'Sun with face', W * .9, 100, S * .1); draw(ctx, 'Cactus', 40, H - 60, S * .1); draw(ctx, 'Camel', W - 70, H - 60, S * .12);
      for (const c of all) {
        const X = ox + c.x * cs, Y = oy + c.y * cs;
        const TL = G.SP['kenney-platformer/tiles'];
        if (!c.dug) {
          // Ô cát Kenney; ô đang đào rung lắc
          const sh = digT && digT.c === c ? Math.sin(G.t * 60) * 3 : 0;
          if (!spr(ctx, TL, 'terrain_sand_block_center', X + cs / 2 + sh, Y + cs / 2, cs - 4)) { ctx.fillStyle = (c.x + c.y) % 2 ? '#f6c98a' : '#f0bd78'; roundRect(ctx, X + 3, Y + 3, cs - 6, cs - 6, 10); ctx.fill(); }
          continue;
        }
        ctx.fillStyle = '#c9a27a'; roundRect(ctx, X + 3, Y + 3, cs - 6, cs - 6, 10); ctx.fill();
        ctx.fillStyle = '#8d6e63'; ctx.beginPath(); ctx.ellipse(X + cs / 2, Y + cs * .55, cs * .34, cs * .22, 0, 0, 7); ctx.fill();
        if (c.has && c.has !== 'Scorpion') draw(ctx, c.has, X + cs / 2, Y + cs / 2, cs * .7);
        else if (!c.has) { const h = heat(c); const col = h <= 1 ? '#fa5252' : h === 2 ? '#ff922b' : h === 3 ? '#fcc419' : '#74c0fc'; ctx.fillStyle = col; ctx.beginPath(); ctx.arc(X + cs / 2, Y + cs / 2, cs * .28, 0, 7); ctx.fill(); ctx.font = `${cs * .3}px sans-serif`; ctx.textAlign = 'center'; ctx.fillStyle = '#fff'; ctx.fillText(h <= 1 ? '🔥' : h >= 4 && h < 99 ? '❄️' : '', X + cs / 2, Y + cs * .6); }
      }
      if (digT) { const c = digT.c; draw(ctx, 'Pick', ox + (c.x + .6) * cs, oy + (c.y + .4) * cs, cs * .6, cs * .6, {rot: Math.sin(digT.t * 30) * .5}); }
      if (fight) { fight.v = fight.v || {}; Object.assign(fight.v, {x: fight.x, y: fight.y, size: cs * 1.1, t: G.t, hurt: Math.min(.15, fight.hurt), flip: false, moving: true, atk: fight.atkT > 0 ? 1 - fight.atkT / .35 : 0}); drawMob(ctx, 'Scorpion', fight.v); hpBar(ctx, fight.x - cs * .45, fight.y - cs * .65, cs * .9, 10, fight.hp, fight.max); ctx.fillStyle = '#c92a2a'; ctx.font = '800 20px "Baloo 2", sans-serif'; ctx.textAlign = 'center'; ctx.fillText('Chạm bọ cạp để đánh!', W / 2, oy - 12); }
      if (boss && boss.hp > 0) {
        if (boss.cell && boss.up > 0) {
          // Trồi lên khỏi hố (outBack), sắp chích thì rung
          const X = ox + (boss.cell.x + .5) * cs, Y = oy + (boss.cell.y + .5) * cs, age = (boss.upMax || 1) - boss.up, k = E.outBack(Math.min(1, age / .3)), warn = boss.up < .35 ? Math.sin(G.t * 50) * 3 : 0;
          draw(ctx, 'Hole', X, Y + cs * .25, cs * .9);
          ctx.save(); ctx.beginPath(); ctx.rect(X - cs, Y - cs * 1.4, cs * 2, cs * 1.65); ctx.clip();
          draw(ctx, 'Scorpion', X + warn, Y - cs * .1 + (1 - k) * cs, cs * 1.3); draw(ctx, 'Crown', X + warn, Y - cs * .7 + (1 - k) * cs, cs * .4);
          ctx.restore();
        }
        bossBar(ctx, W, H, boss, boss.name);
      }
      if (!boss) { ctx.fillStyle = 'rgba(0,0,0,.3)'; roundRect(ctx, 14, H - 54, 170, 40, 20); ctx.fill(); draw(ctx, 'Pick', 38, H - 34, 28); ctx.fillStyle = '#fff'; ctx.font = '800 20px "Baloo 2", sans-serif'; ctx.textAlign = 'left'; ctx.fillText(`Còn ${digs} lượt đào`, 56, H - 27); }
    },
    done: () => boss ? boss.hp <= 0 : found >= NT,
    goal: () => Z.boss ? null : `💰 ${found}/${NT}`,
    // hết lượt đào mà chưa đủ thì thua
    get lose() { return digs <= 0 && found < NT && !digT; }
  };
});

// ---------- 7. Rừng Kẹo: đặt lính kẹo dọc đường giữ chiếc bánh; chạm quái để đánh thêm; trùm Nhện Kẹo ----------
const TOWERS = [
  {id: 'pop', img: 'Lollipop', vi: 'Kẹo mút', cost: 30, range: .26, rate: .7, dmg: .45, shot: 'Candy'},
  {id: 'ice', img: 'Ice cream', vi: 'Kem lạnh', cost: 40, range: .22, rate: 1.1, dmg: .25, shot: 'Snowflake', slow: true},
  {id: 'boom', img: 'Doughnut', vi: 'Bom bánh', cost: 60, range: .24, rate: 1.7, dmg: .6, shot: 'Doughnut', splash: .1}
];
export const candy = (box, Z) => shell(box, Z, {
  name: 'Rừng Kẹo', goalText: Z.boss ? 'Giữ bánh, đánh bại Nhện Kẹo' : `Giữ bánh qua ${3 + Math.floor(Z.s / 2)} đợt sâu bọ`,
  hint: 'Chọn lính ở dưới rồi chạm ô tròn để đặt · chạm lính để nâng cấp',
  imgs: ['Ant', 'Lady beetle', 'Cockroach', 'Spider', 'Birthday cake', 'Candy', 'Lollipop', 'Ice cream', 'Doughnut', 'Snowflake', 'Cookie', 'Mushroom'],
  noPotion: true, hp: 10
}, G => {
  const {W, H, S, ctx, M, F} = G;
  const top = 120, bot = H - 120;
  const pts = [[-30, top + 20], [W * .3, top + 20], [W * .3, bot], [W * .62, bot], [W * .62, top + 20], [W * .88, top + 20], [W * .88, (top + bot) / 2]].map(([x, y]) => ({x, y}));
  const segs = []; let total = 0;
  for (let i = 0; i < pts.length - 1; i++) { const l = dist(pts[i], pts[i + 1]); segs.push({a: pts[i], b: pts[i + 1], l, s: total}); total += l; }
  const posAt = d => { for (const sg of segs) if (d <= sg.s + sg.l) { const k = (d - sg.s) / sg.l; return {x: sg.a.x + (sg.b.x - sg.a.x) * k, y: sg.a.y + (sg.b.y - sg.a.y) * k}; } return pts[pts.length - 1]; };
  const slots = [[.15, top + 90], [.45, top + 70], [.45, bot - 60], [.2, (top + bot) / 2], [.76, (top + bot) / 2 + 30], [.46, (top + bot) / 2], [.76, top + 90], [.15, bot - 10]].map(([x, y]) => ({x: W * x, y, t: null}));
  const NW = Z.boss ? 3 : 3 + Math.floor(Z.s / 2);
  let candy = 70 + Z.s * 10, wave = 0, toSpawn = 0, spT = 0, breakT = 2.5, sel = 0, foes = [], shots = [], tapCd = 0, bossOut = false;
  const startWave = () => { toSpawn = 6 + Z.s + wave * 2; spT = 0; };
  const bw = Math.min(110, (W - 40) / 3.4), bh = 62;
  const selBtns = TOWERS.map((t, i) => ({...t, x: W / 2 + (i - 1) * (bw + 10), y: H - bh / 2 - 12}));
  M.on('down', p => {
    if (G.introT > 0) return;
    for (const [i, b] of selBtns.entries()) if (Math.abs(p.x - b.x) < bw / 2 && Math.abs(p.y - b.y) < bh / 2) { sel = i; sfx('tap'); return; }
    for (const sl of slots) if (dist(p, sl) < S * .055) {
      if (!sl.t) { const T = TOWERS[sel]; if (candy >= T.cost) { candy -= T.cost; sl.t = {...T, lv: 1, cd: 0}; sfx('power'); F.burst(sl.x, sl.y, 14); } else { sfx('wrong'); F.text(sl.x, sl.y - 30, 'Thiếu kẹo', '#fff'); } }
      else if (sl.t.lv < 3) { const c = Math.round(sl.t.cost * .7 * sl.t.lv); if (candy >= c) { candy -= c; sl.t.lv++; sfx('star'); F.text(sl.x, sl.y - 30, `Cấp ${sl.t.lv}!`, '#ffd43b'); } else { sfx('wrong'); F.text(sl.x, sl.y - 30, `Cần ${c} 🍬`, '#fff'); } }
      return;
    }
    if (tapCd > 0) return;
    for (const f of foes) if (!f.dead && dist(p, f) < f.size * .7) { tapCd = .25; const s = strike(Z.st, .5); hurtFoe(f, s.d, s.crit); sfx('hit'); return; }
  });
  function hurtFoe(f, d, crit) { if (f.dead) return; f.hp -= d; f.hurt = .15; G.FB.num(f.x, f.y - f.size * .6, crit ? `${d}!` : String(d), {crit, size: 20}); if (f.hp <= 0) { f.dead = true; G.die({img: f.img, sheet: f.sheet ? 'kenney-platformer/enemies' : null, anim: f.sheet, x: f.x, y: f.y, size: f.size * 1.3, flip: f.flip, boss: f.boss}); G.kill(f.boss); candy += f.boss ? 0 : 7; F.burst(f.x, f.y, f.boss ? 40 : 10); sfx(f.boss ? 'boom' : 'pop'); if (Math.random() < .35 || f.boss) G.loot((2 + Z.r * 3) * (f.boss ? 15 : 1), f.x, f.y); } }
  let won = false;
  return {
    update(dt) {
      tapCd -= dt;
      if (breakT > 0) { breakT -= dt; if (breakT <= 0) startWave(); }
      else if (toSpawn > 0) { spT -= dt; if (spT <= 0) { spT = Math.max(.45, .95 - Z.s * .06); toSpawn--; const k = pick(Z.s >= 2 ? ['Ant', 'Ant', 'Lady beetle', 'Cockroach'] : ['Ant', 'Ant', 'Lady beetle']); const s = foeStats(6, Z.s, k === 'Cockroach' ? .9 : k === 'Lady beetle' ? .6 : .35); foes.push({img: k, sheet: k === 'Ant' ? 'mouse' : k === 'Lady beetle' ? 'ladybug' : 'snail', d: 0, t: rand(0, 2), ...s, max: s.hp, spd: S * (k === 'Ant' ? .16 : k === 'Lady beetle' ? .12 : .1), size: S * (k === 'Cockroach' ? .08 : .065), slow: 0, hurt: 0}); } }
      else if (!foes.some(f => !f.dead)) {
        if (Z.boss && wave === NW - 1 && !bossOut) { bossOut = true; const s = foeStats(6, 5, 6); foes.push({img: 'Spider', boss: true, name: 'Nhện Kẹo', d: 0, t: 0, ...s, max: s.hp, spd: S * .05, size: S * .16, slow: 0, hurt: 0}); }
        else if (wave + 1 >= NW) won = true;
        else { wave++; breakT = 2.5; candy += 15; }
      }
      for (const f of foes) {
        if (f.dead) continue; f.hurt = Math.max(0, f.hurt - dt); f.slow = Math.max(0, f.slow - dt);
        f.t += dt; const px = f.x ?? 0; f.d += f.spd * (f.slow > 0 ? .5 : 1) * dt; Object.assign(f, posAt(f.d)); if (Math.abs(f.x - px) > .01) f.flip = f.x > px;
        if (f.d >= total) { f.dead = true; G.hurt(f.boss ? 5 : 1, W * .88, (top + bot) / 2, true); }
      }
      for (const sl of slots) {
        const t = sl.t; if (!t) continue; t.cd -= dt; if (t.cd > 0) continue;
        let tg = null, bd = S * t.range * (1 + (t.lv - 1) * .15); for (const f of foes) if (!f.dead) { const d = dist(f, sl); if (d < bd && (!tg || f.d > tg.d)) tg = f; }
        if (tg) { t.cd = t.rate; shots.push({x: sl.x, y: sl.y, tg, t, sp: S * 1.4}); }
      }
      for (const s of shots) {
        if (s.tg.dead) { s.done = true; continue; }
        const a = Math.atan2(s.tg.y - s.y, s.tg.x - s.x); s.x += Math.cos(a) * s.sp * dt; s.y += Math.sin(a) * s.sp * dt;
        if (dist(s, s.tg) < 14) { s.done = true; const d = Math.round(Z.st.atk * s.t.dmg * (1 + (s.t.lv - 1) * .5));
          if (s.t.splash) { for (const f of foes) if (dist(f, s.tg) < S * s.t.splash) hurtFoe(f, d); F.burst(s.x, s.y, 10, ['#f783ac', '#ffd43b']); } else hurtFoe(s.tg, d);
          if (s.t.slow) s.tg.slow = 1.5; }
      }
      shots = shots.filter(s => !s.done); foes = foes.filter(f => !f.dead);
    },
    draw() {
      ctx.fillStyle = '#fff0f6'; ctx.fillRect(0, 0, W, H);
      for (let i = 0; i < 16; i++) { ctx.fillStyle = i % 2 ? '#ffdeeb' : '#fcc2d7'; ctx.beginPath(); ctx.arc((i * 211) % W, 70 + (i * 131) % (H - 70), 40, 0, 7); ctx.fill(); }
      ctx.strokeStyle = '#e599f7'; ctx.lineWidth = S * .09; ctx.lineJoin = 'round'; ctx.lineCap = 'round';
      ctx.beginPath(); pts.forEach((p, i) => i ? ctx.lineTo(p.x, p.y) : ctx.moveTo(p.x, p.y)); ctx.stroke();
      ctx.strokeStyle = '#fff'; ctx.lineWidth = 3; ctx.setLineDash([10, 12]); ctx.stroke(); ctx.setLineDash([]);
      const end = pts[pts.length - 1]; draw(ctx, 'Birthday cake', end.x, end.y + S * .04, S * .16);
      for (const sl of slots) {
        if (!sl.t) { ctx.fillStyle = 'rgba(255,255,255,.85)'; ctx.strokeStyle = '#f06595'; ctx.lineWidth = 3; ctx.setLineDash([6, 5]); ctx.beginPath(); ctx.arc(sl.x, sl.y, S * .05, 0, 7); ctx.fill(); ctx.stroke(); ctx.setLineDash([]); ctx.fillStyle = '#f06595'; ctx.font = '800 22px "Baloo 2", sans-serif'; ctx.textAlign = 'center'; ctx.fillText('+', sl.x, sl.y + 8); continue; }
        ctx.fillStyle = '#f06595'; ctx.beginPath(); ctx.arc(sl.x, sl.y, S * .055, 0, 7); ctx.fill();
        draw(ctx, sl.t.img, sl.x, sl.y, S * .085);
        for (let i = 0; i < sl.t.lv; i++) draw(ctx, 'Glowing star', sl.x - 14 + i * 14, sl.y + S * .06, 14);
      }
      const EN = G.SP['kenney-platformer/enemies'];
      for (const f of foes) { const sz0 = f.size; f.size = sz0 * 1.3; f.moving = true; drawMob(ctx, f.img, f, f.sheet && EN ? {sheet: EN, anim: f.sheet} : {}); f.size = sz0; if (f.slow > 0) draw(ctx, 'Snowflake', f.x + f.size * .3, f.y - f.size * .3, 16); if (!f.boss && f.hp < f.max) hpBar(ctx, f.x - f.size * .4, f.y - f.size * .6, f.size * .8, 6, f.hp, f.max); }
      for (const s of shots) draw(ctx, s.t.shot, s.x, s.y, 22, 22, {rot: G.t * 10});
      for (const [i, b] of selBtns.entries()) {
        ctx.fillStyle = i === sel ? '#ffd43b' : 'rgba(255,255,255,.92)'; ctx.strokeStyle = '#f06595'; ctx.lineWidth = i === sel ? 4 : 2; roundRect(ctx, b.x - bw / 2, b.y - bh / 2, bw, bh, 14); ctx.fill(); ctx.stroke();
        draw(ctx, b.img, b.x - bw * .3, b.y, 38); ctx.fillStyle = '#212529'; ctx.textAlign = 'left'; ctx.font = '800 15px "Baloo 2", sans-serif'; ctx.fillText(b.vi, b.x - bw * .1, b.y - 4); ctx.fillText(`${b.cost} 🍬`, b.x - bw * .1, b.y + 16);
      }
      ctx.fillStyle = 'rgba(0,0,0,.3)'; roundRect(ctx, W - 118, 62, 106, 40, 20); ctx.fill(); draw(ctx, 'Candy', W - 94, 82, 28); ctx.fillStyle = '#fff'; ctx.font = '800 22px "Baloo 2", sans-serif'; ctx.textAlign = 'left'; ctx.fillText(String(candy), W - 74, 91);
      if (breakT > 0 && G.introT <= 0) { ctx.fillStyle = 'rgba(0,0,0,.3)'; ctx.fillRect(0, H / 2 - 34, W, 68); ctx.fillStyle = '#fff'; ctx.font = '800 32px "Baloo 2", sans-serif'; ctx.textAlign = 'center'; ctx.fillText(Z.boss && wave === NW - 1 ? 'Đợt cuối: Nhện Kẹo!' : `Đợt ${wave + 1} sắp tới · đặt lính đi!`, W / 2, H / 2 + 11); }
      const bs = foes.find(f => f.boss); if (bs) bossBar(ctx, W, H - 80, bs, bs.name);
    },
    done: () => won,
    goal: () => `🎂 Đợt ${Math.min(wave + 1, NW)}/${NW}`
  };
});

// ---------- 8. Núi Lửa: chạy nhảy qua dung nham, chém thằn lằn, tới cờ; trùm Khủng Long Dung Nham ----------
export const volcano = (box, Z) => shell(box, Z, {
  name: 'Núi Lửa', goalText: Z.boss ? 'Đánh bại Khủng Long Dung Nham' : 'Vượt dung nham tới lá cờ 🏁',
  hint: '◀ ▶ để chạy · ⬆ để nhảy · ⚔️ để chém · rơi vào lửa sẽ mất máu',
  imgs: ['Lizard', 'Fire', 'T-Rex', 'Chequered flag', 'Volcano', 'Rock', 'Coin', 'Crown']
}, G => {
  const {W, H, S, ctx, M, F} = G;
  const gy = H * .8, grav = S * 3, jv = S * 1.35, sp = S * .5 * Z.st.spd, hs = S * .12;
  const len = Z.boss ? W * 1.6 : W * (2.6 + Z.s * .5);
  const plats = [], lavas = [], lizards = [], coins = [];
  let x = 0;
  plats.push({x: -200, y: gy, w: W * .6 + 200});
  x = W * .6;
  while (x < len - W * .5) {
    const gap = S * rand(.12, .2 + Z.s * .012);
    lavas.push({x, w: gap, ft: rand(1, 3)}); x += gap;
    const w = S * rand(.35, .7); const y = gy - (Math.random() < .35 ? S * rand(.06, .14) : 0);
    plats.push({x, y, w}); if (w > S * .5 && Math.random() < .4 + Z.s * .08) { const s = foeStats(7, Z.s); lizards.push({x: x + w / 2, y, x0: x + 20, x1: x + w - 20, dir: 1, ...s, max: s.hp, hurt: 0}); }
    if (Math.random() < .5) plats.push({x: x + w * .2, y: y - S * .3, w: S * .2, float: true});
    for (let i = 0; i < 3; i++) coins.push({x: x + w * (.25 + i * .25), y: y - S * .12});
    x += w;
  }
  plats.push({x, y: gy, w: W * 1.2}); const flagX = Z.boss ? x + W * .9 : x + S * .4;
  let boss = null;
  if (Z.boss) { const s = foeStats(7, 5, 10); boss = {x: x + W * .7, y: gy, vy: 0, dir: -1, ...s, max: s.hp, cd: 2, hurt: 0, name: 'Khủng Long Dung Nham', size: S * .3}; }
  const fireballs = [];
  const me = {x: 60, y: gy, vy: 0, ground: true, face: 1, swing: 0, safe: 60};
  let cam = 0, atkCd = 0, won = false;
  const br = Math.min(52, S * .085), by = H - br - 16;
  const B = buttons(M, [{id: 'l', x: br + 16, y: by, r: br, label: '◀'}, {id: 'r', x: br * 3.4 + 16, y: by, r: br, label: '▶'}, {id: 'j', x: W - br - 16, y: by, r: br * 1.1, label: '⬆', c: '#4dabf7'}, {id: 'a', x: W - br * 3.5 - 16, y: by, r: br, label: '⚔️', c: '#ff922b'}]);
  const K = k => G.keys.has(k);
  const groundAt = (px, py, vy) => { for (const p of plats) if (px > p.x - 10 && px < p.x + p.w + 10 && py >= p.y - 2 && py - vy * .02 <= p.y + 14) return p; return null; };
  return {
    update(dt) {
      me.swing = Math.max(0, me.swing - dt); atkCd -= dt;
      const dir = (B.down('r') || K('arrowright') || K('d') ? 1 : 0) - (B.down('l') || K('arrowleft') || K('a') ? 1 : 0);
      me.x += dir * sp * dt; if (dir) me.face = dir; me.x = Math.max(20, me.x);
      if (boss && !boss.dead) me.x = Math.min(me.x, boss.x + W * .4);
      if ((B.hit('j') || K('arrowup') || K('w') || K(' ')) && me.ground) { me.vy = -jv; me.ground = false; sfx('jump'); }
      me.vy += grav * dt; me.y += me.vy * dt;
      const p = me.vy >= 0 ? groundAt(me.x, me.y, me.vy) : null;
      if (p) { if (!me.ground && me.vy > S * .8) G.FB.dust(me.x - cam, p.y, 5); me.y = p.y; me.vy = 0; me.ground = true; if (!p.float) me.safe = Math.min(Math.max(p.x + 30, me.x), p.x + p.w - 30); } else me.ground = false;
      if (me.y > gy + S * .12) { G.hurt(Math.round(G.hero.max * .12), me.x - cam, gy, true); G.hero.inv = 1.5; me.x = me.safe; me.y = gy - S * .4; me.vy = 0; sfx('wrong'); }
      if (B.hit('a') && atkCd <= 0) {
        atkCd = .3; me.swing = .25; sfx('flip'); G.FB.slash(me.x - cam + me.face * hs * .2, me.y - hs * .5, hs * .7, me.face > 0 ? 0 : Math.PI, me.face);
        const tg = [...lizards.filter(l => !l.dead), ...(boss && !boss.dead ? [boss] : [])];
        for (const l of tg) if (Math.abs(l.x - (me.x + me.face * hs * .5)) < hs * (l === boss ? 1.6 : 1) && Math.abs(l.y - me.y) < hs * 1.2) {
          const s = strike(Z.st); l.hp -= s.d; l.hurt = .2; sfx('hit'); l.x += me.face * 14;
          G.num(l.x - cam, l.y - hs, s.d, s.crit);
          if (l.hp <= 0) { l.dead = true; G.die(l === boss ? {img: 'T-Rex', x: l.x - cam, y: l.y - boss.size * .45, size: boss.size, flip: boss.dir > 0, boss: true} : {sheet: 'kenney-platformer/enemies', anim: 'slime_fire', x: l.x - cam, y: l.y - hs * .4, size: hs * .9, flip: l.dir > 0}); G.kill(l === boss); F.burst(l.x - cam, l.y - hs / 2, l === boss ? 40 : 14); G.loot((2 + Z.r * 3) * (l === boss ? 15 : 1), l.x - cam, l.y - hs); sfx(l === boss ? 'boom' : 'pop'); }
        }
      }
      for (const l of lizards) { if (l.dead) continue; l.t = (l.t || 0) + dt; l.hurt = Math.max(0, l.hurt - dt); l.x += l.dir * S * .1 * dt; if (l.x < l.x0 || l.x > l.x1) l.dir *= -1; if (Math.abs(l.x - me.x) < hs * .6 && Math.abs(l.y - me.y) < hs * .5 && !G.hero.inv) G.hurt(l.dmg, me.x - cam, me.y - hs); }
      for (const lv of lavas) { lv.ft -= dt; if (lv.ft <= 0) { lv.ft = rand(2.2, 3.6) - Z.s * .15; fireballs.push({x: lv.x + lv.w / 2, y: gy + 30, vy: -S * rand(1.1, 1.4), warn: .6}); } }
      for (const f of fireballs) { if (f.warn > 0) { f.warn -= dt; continue; } f.vy += grav * .8 * dt; f.y += f.vy * dt; if (!G.hero.inv && Math.hypot(f.x - me.x, f.y - (me.y - hs / 2)) < hs * .55) { f.dead = true; G.hurt(foeStats(7, Z.s).dmg, me.x - cam, me.y - hs); } if (f.y > gy + 60 && f.vy > 0) f.dead = true; }
      for (let i = fireballs.length - 1; i >= 0; i--) if (fireballs[i].dead) fireballs.splice(i, 1);
      for (const c of coins) if (!c.got && Math.abs(c.x - me.x) < hs * .5 && Math.abs(c.y - (me.y - hs / 2)) < hs * .6) { c.got = true; G.loot(1 + Z.r, c.x - cam, c.y); }
      if (boss && !boss.dead) {
        boss.hurt = Math.max(0, boss.hurt - dt); boss.cd -= dt; boss.atkT = Math.max(0, (boss.atkT || 0) - dt); boss.t = (boss.t || 0) + dt; boss.vy += grav * dt; boss.y = Math.min(gy, boss.y + boss.vy * dt); if (boss.y >= gy) { boss.vy = 0; if (boss.jumped) { boss.jumped = false; G.C.shake(10); G.FB.dust(boss.x - cam, gy, 10); sfx('boom'); } }
        boss.dir = me.x < boss.x ? -1 : 1; boss.x += boss.dir * S * .08 * dt;
        if (boss.cd <= 0) { boss.cd = boss.hp < boss.max / 2 ? 1.6 : 2.3; boss.atkT = .35; if (Math.random() < .5) { boss.vy = -S * 1.1; boss.jumped = true; } else { for (const k of [-1, 0, 1]) fireballs.push({x: boss.x, y: boss.y - boss.size * .6, vy: -S * (.9 + k * .15), vx: boss.dir * S * (.35 + k * .1), warn: 0, arc: true}); sfx('boom'); } }
        if (Math.abs(boss.x - me.x) < boss.size * .4 && me.y > boss.y - boss.size * .7) G.hero.inv || G.hurt(boss.dmg, me.x - cam, me.y - hs);
      }
      for (const f of fireballs) if (f.arc) f.x += f.vx * dt;
      cam += (clamp(me.x - W * .35, 0, flagX + W * .3 - W) - cam) * Math.min(1, dt * 6);
      if (!Z.boss && me.x >= flagX) won = true;
      if (boss && boss.dead) won = true;
    },
    draw() {
      const g = ctx.createLinearGradient(0, 0, 0, H); g.addColorStop(0, '#c92a2a'); g.addColorStop(1, '#ffc078'); ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
      for (let i = 0; i < 4; i++) draw(ctx, 'Volcano', ((i * W * .45 - cam * .3) % (W * 1.8) + W * 1.8) % (W * 1.8) - W * .2, gy - S * .25, S * .5, S * .5, {alpha: .5});
      ctx.save(); ctx.translate(-cam, 0);
      const TL = G.SP['kenney-platformer/tiles'], EN = G.SP['kenney-platformer/enemies'], ts = Math.round(S * .085), okT = TL?.img.naturalWidth;
      // Dung nham: dải sóng lava Kenney trôi ngang + bọt nổi
      ctx.fillStyle = '#ff6b00'; ctx.fillRect(cam, gy + 10, W, H);
      if (okT) { const x0 = Math.floor(cam / ts) * ts - ts + (G.t * 25) % ts; for (let x = x0; x < cam + W + ts; x += ts) { spr(ctx, TL, 'lava_top', x + ts / 2, gy + 10 + ts / 2, ts); for (let y = gy + 10 + ts; y < H; y += ts) spr(ctx, TL, 'lava', x + ts / 2, y + ts / 2, ts); } }
      for (let i = 0; i < 20; i++) { ctx.fillStyle = 'rgba(255,224,102,.7)'; ctx.beginPath(); ctx.arc(cam + (i * 97 + G.t * 30) % W, gy + 26 + Math.sin(G.t * 3 + i) * 6, 5, 0, 7); ctx.fill(); }
      // Nền đá: ô đất Kenney (mặt trên + thân), bục nổi là mây đá
      for (const p of plats) {
        if (p.x > cam + W || p.x + p.w < cam) continue;
        if (!okT) { ctx.fillStyle = '#5c3d2e'; roundRect(ctx, p.x, p.y, p.w, p.float ? 18 : H - p.y, 8); ctx.fill(); ctx.fillStyle = '#8d6e63'; ctx.fillRect(p.x, p.y, p.w, 8); continue; }
        ctx.save(); ctx.beginPath(); ctx.rect(p.x, p.y - ts, p.w, H); ctx.clip();
        const n = Math.ceil(p.w / ts);
        for (let i = 0; i < n; i++) {
          const x = p.x + i * ts + ts / 2;
          if (x < cam - ts || x > cam + W + ts) continue;
          if (p.float) spr(ctx, TL, n === 1 ? 'terrain_stone_cloud_middle' : i === 0 ? 'terrain_stone_cloud_left' : i === n - 1 ? 'terrain_stone_cloud_right' : 'terrain_stone_cloud_middle', x, p.y + ts / 2 - 4, ts);
          else { spr(ctx, TL, 'terrain_dirt_block_top', x, p.y + ts / 2, ts); for (let y = p.y + ts; y < H; y += ts) spr(ctx, TL, 'terrain_dirt_block_center', x, y + ts / 2, ts); }
        }
        ctx.restore();
      }
      for (const c of coins) if (!c.got) drawCoin(ctx, G.SP, c.x, c.y + Math.sin(G.t * 4 + c.x) * 3, 28, G.t + c.x * .01);
      for (const l of lizards) if (!l.dead) {
        l.v = l.v || {}; Object.assign(l.v, {x: l.x, y: l.y - hs * .4, size: hs * .9, t: l.t || 0, hurt: Math.min(.15, l.hurt), flip: l.dir > 0, moving: true});
        drawMob(ctx, 'Lizard', l.v, EN ? {sheet: EN, anim: 'slime_fire'} : {});
        if (l.hp < l.max) hpBar(ctx, l.x - hs * .4, l.y - hs * .9, hs * .8, 7, l.hp, l.max);
      }
      for (const f of fireballs) { if (f.warn > 0) { ctx.fillStyle = 'rgba(255,255,255,.7)'; ctx.beginPath(); ctx.arc(f.x, gy + 14 + Math.sin(G.t * 30) * 3, 10, 0, 7); ctx.fill(); continue; } const a = Math.atan2(f.vy, f.vx || 0); if (!spr(ctx, TL, 'fireball', f.x, f.y, hs * .55, {rot: a + Math.PI})) draw(ctx, 'Fire', f.x, f.y, hs * .6, hs * .6, {rot: f.vy > 0 ? Math.PI : 0}); }
      if (!Z.boss || (boss && boss.dead)) { if (!sprA(ctx, TL, 'flag_green', G.t, flagX, gy - S * .08, S * .18)) draw(ctx, 'Chequered flag', flagX, gy - S * .1, S * .16); }
      if (boss && !boss.dead) {
        boss.v = boss.v || {}; Object.assign(boss.v, {x: boss.x, y: boss.y - boss.size * .45, size: boss.size, t: boss.t || 0, hurt: Math.min(.15, boss.hurt), flip: boss.dir > 0, moving: boss.vy === 0, atk: boss.atkT > 0 ? 1 - boss.atkT / .35 : 0});
        drawMob(ctx, 'T-Rex', boss.v); draw(ctx, 'Crown', boss.x, boss.y - boss.size * 1.0, boss.size * .25);
      }
      drawHero(ctx, me.x, me.y - hs * .45, hs, Z, {face: me.face, swing: me.swing, hurt: G.hero.inv, t: G.t, moving: me.ground && (B.down('l') || B.down('r') || G.keys.has('arrowleft') || G.keys.has('arrowright')), pose: !me.ground && !(me.swing > 0) ? 'jump' : null});
      ctx.restore();
      if (!Z.boss) { const k = clamp(me.x / flagX, 0, 1), pw = Math.min(300, W * .4); const py = W < 700 ? 112 : 66; ctx.fillStyle = 'rgba(0,0,0,.3)'; roundRect(ctx, W / 2 - pw / 2, py, pw, 16, 8); ctx.fill(); ctx.fillStyle = '#ffd43b'; roundRect(ctx, W / 2 - pw / 2 + 2, py + 2, (pw - 4) * k, 12, 6); ctx.fill(); draw(ctx, 'Chequered flag', W / 2 + pw / 2 + 14, py + 8, 24); }
      if (boss && !boss.dead) bossBar(ctx, W, H, boss, boss.name, W < 700 ? 132 : 90);
      B.draw(ctx);
    },
    done: () => won,
    goal: () => null
  };
});
