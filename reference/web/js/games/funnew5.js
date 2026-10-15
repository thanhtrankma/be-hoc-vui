// Game mới (đợt 15, phần 3): Bẻ ghi tàu hoả, Xếp hàng lên xe tải, Bong bóng số.
import {sfx} from '../audio.js?v=4c51d34a6e';
import {banner, canvasIn, draw, endText, fx, goalPill, hud, levelBanner, loadAll, loop, pick, rand, ramp, roundRect, theme} from './funcore.js?v=4c51d34a6e';
import {drawAnim, drawFrame} from './sheets.js?v=4c51d34a6e';
import {hearts, kidOf, pill, shadow, sheets, skyFill, taps} from './funnew3.js?v=4c51d34a6e';

const shuffle = a => { for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; };

// ---------- 11. Bẻ ghi tàu hoả: tàu mang cờ màu chạy từ trái sang, chạm vào chỗ rẽ để bẻ ghi, đưa tàu về ga cùng màu. ----------
const TCOL = [['flagR', '#fa5252'], ['flagB', '#339af0'], ['flagG', '#40c057'], ['flagY', '#fab005']];
export async function trains(box, opts) {
  const lv = opts.level || 0, th = theme(lv), need = Math.round(ramp(lv, 6, 20)), kid = kidOf(opts);
  const nSt = lv < 10 ? 2 : lv < 30 ? 3 : 4;
  const SH = await sheets([kid, 'items']);
  await loadAll(['Locomotive', 'House', 'Red heart', 'Coin', 'Deciduous tree', 'Evergreen tree']);
  const {cv, ctx, W, H} = canvasIn(box);
  const S = Math.min(W, H), F = fx(), bot = opts.bot;
  const top = W < 640 ? 130 : 90, y0 = top + 40, y1 = H - 40, midY = (y0 + y1) / 2;
  const xs = W * .1, xe = W - Math.min(110, W * .17);
  // Cây rẽ nhánh: nút {x,y, kids:[a,b], sw:0|1} hoặc lá {station:i}
  const leafY = Array.from({length: nSt}, (_, i) => y0 + (y1 - y0) * (i + .5) / nSt);
  let root;
  const J = (x, a, b) => ({x, y: 0, kids: [a, b], sw: 0});
  const Lf = i => ({station: i, x: xe, y: leafY[i]});
  if (nSt === 2) root = J(W * .42, Lf(0), Lf(1));
  else if (nSt === 3) root = J(W * .32, Lf(0), J(W * .58, Lf(1), Lf(2)));
  else root = J(W * .3, J(W * .58, Lf(0), Lf(1)), J(W * .58, Lf(2), Lf(3)));
  const fixY = n => { if (n.kids) { n.kids.forEach(fixY); n.y = (n.kids[0].y + n.kids[1].y) / 2; } return n.y; };
  fixY(root);
  const juncs = []; (function walk(n) { if (n.kids) { juncs.push(n); n.kids.forEach(walk); } })(root);
  // Đường đi từ điểm a tới b: ngang rồi chéo rồi ngang.
  const seg = (a, b) => { const mx = a.x + (b.x - a.x) * .25, nx = a.x + (b.x - a.x) * .7; return [[a.x, a.y], [mx, a.y], [nx, b.y], [b.x, b.y]]; };
  const colors = shuffle(TCOL.slice()).slice(0, nSt);
  const speed = S * ramp(lv, .2, .36), every = ramp(lv, 5.5, 2.4);
  const trainsA = [];
  let done = 0, lives = 3, t = 0, end = null, endT = 0, spawn = 1.2;
  const startP = {x: xs - 60, y: root.y};
  const newTrain = () => trainsA.push({c: Math.floor(Math.random() * nSt), node: root, pts: [[startP.x, startP.y], [root.x, root.y]], i: 0, x: startP.x, y: startP.y, ang: 0, gone: 0});
  taps(cv, {onTap: (x, y) => {
    if (t < 2 || end) return;
    const j = juncs.find(j => Math.hypot(j.x - x, j.y - y) < S * .09);
    if (j) { j.sw ^= 1; sfx('flip'); }
  }});
  const arrive = tr => {
    const n = tr.node;
    if (n.station != null) {
      tr.gone = 1;
      if (n.station === tr.c) { done++; sfx('correct'); F.burst(n.x, n.y, 18, [colors[tr.c][1], '#fff']); F.text(n.x - 40, n.y - 40, `${done}/${need}`, '#ffd43b'); if (done >= need) { end = {win: true, score: done * 8 + lives * 5}; sfx('win'); } }
      else { lives--; sfx('wrong'); F.text(n.x - 40, n.y - 40, 'Sai ga!', '#ff8787'); if (lives <= 0) end = {win: false, score: done * 8}; }
      return;
    }
    const next = n.kids[n.sw];
    tr.pts = seg(n, next); tr.i = 0; tr.node = next;
  };
  return loop({
    update(dt) {
      t += dt; F.update(dt);
      if (end) { endT += dt; return endT > 2 ? end : null; }
      if (t < 2) return null;
      spawn -= dt;
      if (spawn <= 0) { spawn = every * rand(.9, 1.15); newTrain(); }
      for (let k = trainsA.length - 1; k >= 0; k--) {
        const tr = trainsA[k];
        if (tr.gone) { tr.gone += dt; if (tr.gone > 1.2) trainsA.splice(k, 1); continue; }
        let mv = speed * dt;
        while (mv > 0 && !tr.gone) {
          const [bx, by] = tr.pts[tr.i + 1], dx = bx - tr.x, dy = by - tr.y, d = Math.hypot(dx, dy);
          if (d > .01) tr.ang = Math.atan2(dy, dx);
          if (d <= mv) { tr.x = bx; tr.y = by; mv -= d; tr.i++; if (tr.i >= tr.pts.length - 1) arrive(tr); }
          else { tr.x += dx / d * mv; tr.y += dy / d * mv; mv = 0; }
        }
      }
      if (bot) for (const tr of trainsA) if (!tr.gone && tr.node.kids) {
        // tìm nhánh dẫn tới ga đúng màu
        const has = (n, c) => n.station != null ? n.station === tr.c : has(n.kids[0], c) || has(n.kids[1], c);
        tr.node.sw = has(tr.node.kids[0]) ? 0 : 1;
      }
      return null;
    },
    draw() {
      skyFill(ctx, W, H, th);
      ctx.fillStyle = th.ground; ctx.fillRect(0, y0 - 30, W, H - y0 + 30);
      for (let i = 0; i < 5; i++) draw(ctx, i % 2 ? 'Evergreen tree' : 'Deciduous tree', W * (.3 + i * .12), y0 - 10, S * .07, undefined, {alpha: .7});
      // Đường ray
      const rail = pts => {
        ctx.strokeStyle = 'rgba(206,212,218,.85)'; ctx.lineWidth = 26; ctx.lineCap = 'round'; ctx.lineJoin = 'round'; ctx.beginPath(); ctx.moveTo(...pts[0]); for (const p of pts.slice(1)) ctx.lineTo(...p); ctx.stroke();
        ctx.strokeStyle = '#5c3d2e'; ctx.lineWidth = 18; ctx.lineCap = 'butt'; ctx.setLineDash([6, 10]);
        ctx.beginPath(); ctx.moveTo(...pts[0]); for (const p of pts.slice(1)) ctx.lineTo(...p); ctx.stroke(); ctx.setLineDash([]);
        ctx.strokeStyle = '#495057'; ctx.lineWidth = 5; ctx.beginPath(); ctx.moveTo(...pts[0]); for (const p of pts.slice(1)) ctx.lineTo(...p); ctx.stroke();
      };
      rail([[0, root.y], [root.x, root.y]]);
      (function walk(n) { if (n.kids) n.kids.forEach(c => { rail(seg(n, c)); walk(c); }); })(root);
      // Ga: nhà + cờ màu
      (function walk(n) {
        if (n.kids) return n.kids.forEach(walk);
        const [fk, col] = colors[n.station];
        ctx.fillStyle = col; roundRect(ctx, n.x - 8, n.y - S * .06, W - n.x, S * .12, 14); ctx.fill();
        draw(ctx, 'House', n.x + S * .06, n.y - S * .01, S * .1);
        drawAnim(ctx, SH.items, fk, t, n.x + S * .03, n.y - S * .075, S * .07);
      })(root);
      // Chỗ bẻ ghi: vòng tròn + mũi tên chỉ nhánh đang mở
      for (const j of juncs) {
        const c = j.kids[j.sw], a = Math.atan2(c.y - j.y, (c.x - j.x) * .45);
        ctx.fillStyle = 'rgba(255,255,255,.9)'; ctx.beginPath(); ctx.arc(j.x, j.y, S * .05, 0, 7); ctx.fill();
        ctx.strokeStyle = '#212529'; ctx.lineWidth = 3; ctx.stroke();
        ctx.save(); ctx.translate(j.x, j.y); ctx.rotate(a); ctx.fillStyle = '#e8590c';
        ctx.beginPath(); ctx.moveTo(S * .035, 0); ctx.lineTo(-S * .015, -S * .022); ctx.lineTo(-S * .015, S * .022); ctx.fill(); ctx.fillRect(-S * .03, -S * .008, S * .03, S * .016); ctx.restore();
      }
      for (const tr of trainsA) {
        const a = tr.gone ? Math.max(0, 1 - tr.gone) : 1, s = S * .11;
        draw(ctx, 'Locomotive', tr.x, tr.y - s * .3, s, s, {flip: true, rot: tr.ang * .8, alpha: a});
        drawAnim(ctx, SH.items, colors[tr.c][0], t, tr.x - s * .1, tr.y - s * .9, s * .5, {alpha: a});
      }
      const kh = Math.min(S * .24, 190);
      shadow(ctx, W * .1, root.y - 12, kh * .45);
      drawAnim(ctx, SH[kid], end?.win ? 'cheer' : 'work', t, W * .1, root.y - 12, kh);
      F.draw(ctx);
      hud(ctx, W, {score: done, lives: 0, time: null}); hearts(ctx, W, lives);
      goalPill(ctx, W, done, need);
      if (t < 2) levelBanner(ctx, W, H, lv, `Đưa ${need} tàu về đúng ga`, 'Chạm vòng tròn để bẻ ghi · Tàu cờ màu nào về ga màu đó');
      if (end) banner(ctx, W, H, end.win ? endText(true, lv) : 'TÀU ĐI LẠC RỒI!', `${done}/${need} tàu`);
    }
  }, opts.alive);
}

// ---------- 12. Xếp hàng lên xe tải: kéo các khối hàng vào thùng xe cho kín chỗ, xe chạy đi giao hàng. ----------
const CARGO = ['Package', 'Wrapped gift', 'Watermelon', 'Pineapple', 'Teddy bear', 'Soccer ball', 'Basket', 'Books', 'Potted plant', 'Red apple', 'Basketball', 'Guitar'];
const PCOL = ['#ffd8a8', '#d0ebff', '#d3f9d8', '#ffe3e3', '#f3d9fa', '#fff3bf', '#c5f6fa', '#e9ecef'];
// Chia lưới thành các khối liền nhau (luôn xếp kín được).
function partition(cols, rows, maxSz) {
  const id = Array.from({length: rows}, () => Array(cols).fill(-1)), pieces = [];
  const cells = shuffle(Array.from({length: cols * rows}, (_, i) => [i % cols, Math.floor(i / cols)]));
  for (const [c, r] of cells) {
    if (id[r][c] >= 0) continue;
    const k = pieces.length, want = 1 + Math.floor(Math.random() * maxSz), pc = [[c, r]];
    id[r][c] = k;
    while (pc.length < want) {
      const opts = [];
      for (const [x, y] of pc) for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const nx = x + dx, ny = y + dy; if (nx >= 0 && ny >= 0 && nx < cols && ny < rows && id[ny][nx] < 0) opts.push([nx, ny]); }
      if (!opts.length) break;
      const [nx, ny] = pick(opts); id[ny][nx] = k; pc.push([nx, ny]);
    }
    const mx = Math.min(...pc.map(p => p[0])), my = Math.min(...pc.map(p => p[1]));
    pieces.push({cells: pc.map(([x, y]) => [x - mx, y - my]), w: Math.max(...pc.map(p => p[0])) - mx + 1, h: Math.max(...pc.map(p => p[1])) - my + 1, home: [mx, my]});
  }
  return pieces;
}
export async function truckload(box, opts) {
  const lv = opts.level || 0, kid = kidOf(opts);
  const cols = Math.min(7, 3 + Math.floor(lv / 12)), rows = lv < 8 ? 2 : lv < 30 ? 3 : 4, maxSz = lv < 5 ? 2 : lv < 25 ? 3 : 4;
  const needTrucks = lv < 10 ? 2 : 3;
  const SH = await sheets([kid, 'items']);
  await loadAll([...CARGO, 'Delivery truck', 'Coin', 'Factory', 'Deciduous tree']);
  const {cv, ctx, W, H} = canvasIn(box);
  const S = Math.min(W, H), F = fx(), bot = opts.bot;
  const top = W < 640 ? 112 : 70;
  const trayTop = H * .56;
  const cs = Math.min((W * .66) / cols, (trayTop - top - 70) / rows, 96);
  const bed = {x: W * .08, y: trayTop - 40 - cs * rows, w: cs * cols, h: cs * rows};
  let pieces = [], grid = null, trucks = 0, t = 0, end = null, endT = 0, drag = null, leave = 0, arrive = 1, botT = 0;
  let time = Math.round(ramp(lv, 75, 100) * needTrucks / 2);
  const ts = Math.min(cs, 84, (W - 64) / 6), kh = Math.min(S * .24, 170);
  const layoutTray = () => {
    // Xếp khay: các khối chưa đặt, theo hàng
    let x = 16, y = trayTop + 16, rowH = 0;
    for (const p of pieces) if (!p.placed) {
      const pw = p.w * ts, phh = p.h * ts;
      if (x + pw > W - 16 - kh * .7) { x = 16; y += rowH + 14; rowH = 0; }
      p.tx = x; p.ty = y; x += pw + 16; rowH = Math.max(rowH, phh);
    }
  };
  const newLoad = () => {
    pieces = shuffle(partition(cols, rows, maxSz)).map((p, i) => ({...p, img: CARGO[i % CARGO.length], col: PCOL[i % PCOL.length], placed: null}));
    grid = Array.from({length: rows}, () => Array(cols).fill(false));
    layoutTray();
  };
  newLoad();
  const fits = (p, gx, gy) => p.cells.every(([x, y]) => gx + x >= 0 && gy + y >= 0 && gx + x < cols && gy + y < rows && !grid[gy + y][gx + x]);
  const place = (p, gx, gy) => {
    p.placed = [gx, gy]; for (const [x, y] of p.cells) grid[gy + y][gx + x] = true; sfx('pop'); layoutTray();
    if (grid.every(r => r.every(Boolean))) { trucks++; leave = .001; sfx('correct'); F.burst(bed.x + bed.w / 2, bed.y, 24); F.text(bed.x + bed.w / 2, bed.y - 30, `${trucks}/${needTrucks}`, '#ffd43b'); }
  };
  const pieceAt = (x, y) => [...pieces].reverse().find(p => !p.placed && p.cells.some(([cx, cy]) => x >= p.tx + cx * ts && x <= p.tx + (cx + 1) * ts && y >= p.ty + cy * ts && y <= p.ty + (cy + 1) * ts));
  taps(cv, {
    onDown: (x, y) => { if (t < 2 || end || leave || arrive > 0) return; const p = pieceAt(x, y); if (p) { drag = {p, ox: (x - p.tx) / ts * cs, oy: (y - p.ty) / ts * cs, x, y}; sfx('tap'); } },
    onMove: (x, y) => { if (drag) { drag.x = x; drag.y = y; } },
    onUp: () => {
      if (!drag) return;
      const {p} = drag, gx = Math.round((drag.x - drag.ox - bed.x) / cs), gy = Math.round((drag.y - drag.oy - bed.y) / cs);
      drag = null;
      if (fits(p, gx, gy)) place(p, gx, gy); else sfx('wrong');
    }
  });
  const cell = (ctx, x, y, s, p) => { ctx.fillStyle = p.col; roundRect(ctx, x + 2, y + 2, s - 4, s - 4, 8); ctx.fill(); ctx.strokeStyle = 'rgba(0,0,0,.2)'; ctx.lineWidth = 2; ctx.stroke(); draw(ctx, p.img, x + s / 2, y + s / 2, s * .72); };
  const drawPiece = (x, y, s, p) => { for (const [cx, cy] of p.cells) cell(ctx, x + cx * s, y + cy * s, s, p); };
  return loop({
    update(dt) {
      t += dt; F.update(dt);
      if (end) { endT += dt; return endT > 2 ? end : null; }
      if (t < 2) return null;
      if (arrive > 0) { arrive = Math.max(0, arrive - dt * 1.4); return null; }
      if (leave) {
        leave += dt;
        if (leave > 1.3) { leave = 0; if (trucks >= needTrucks) { end = {win: true, score: trucks * 20 + Math.round(time)}; sfx('win'); } else { newLoad(); arrive = 1; } }
        return null;
      }
      time -= dt;
      if (bot && (botT += dt) > .4) { botT = 0; const p = pieces.find(p => !p.placed); if (p && fits(p, ...p.home)) place(p, ...p.home); }
      if (time <= 0 && !end) { time = 0; end = {win: false, score: trucks * 20}; sfx('wrong'); }
      return null;
    },
    draw() {
      const g = ctx.createLinearGradient(0, 0, 0, trayTop); g.addColorStop(0, '#a5d8ff'); g.addColorStop(1, '#e7f5ff'); ctx.fillStyle = g; ctx.fillRect(0, 0, W, trayTop);
      draw(ctx, 'Factory', W * .86, bed.y - 10, S * .2); draw(ctx, 'Deciduous tree', W * .66, bed.y + 10, S * .14);
      ctx.fillStyle = '#868e96'; ctx.fillRect(0, bed.y + bed.h + cs * .35, W, trayTop - bed.y - bed.h - cs * .35);
      // Xe tải: thùng (lưới) + đầu xe hình Fluent, chạy vào/ra
      const off = leave ? (leave / 1.3) ** 2 * W : arrive > 0 ? -arrive * W : 0;
      const bx = bed.x + off;
      ctx.fillStyle = '#5c3d2e'; roundRect(ctx, bx - 8, bed.y - 8, bed.w + 16, bed.h + 22, 10); ctx.fill();
      ctx.fillStyle = '#8d5524'; ctx.fillRect(bx, bed.y, bed.w, bed.h);
      ctx.strokeStyle = 'rgba(255,255,255,.18)'; ctx.lineWidth = 2;
      for (let c = 0; c <= cols; c++) { ctx.beginPath(); ctx.moveTo(bx + c * cs, bed.y); ctx.lineTo(bx + c * cs, bed.y + bed.h); ctx.stroke(); }
      for (let r = 0; r <= rows; r++) { ctx.beginPath(); ctx.moveTo(bx, bed.y + r * cs); ctx.lineTo(bx + bed.w, bed.y + r * cs); ctx.stroke(); }
      const tk = Math.min(Math.max(cs * 1.6, bed.h * .9), (W - bed.x - bed.w - 6) / .92);
      draw(ctx, 'Delivery truck', bx + bed.w + tk * .42, bed.y + bed.h + 14 - tk * .4, tk, tk * .85, {flip: true});
      for (const wx of [bx + cs * .6, bx + bed.w - cs * .6]) { ctx.fillStyle = '#212529'; ctx.beginPath(); ctx.arc(wx, bed.y + bed.h + 16, cs * .3, 0, 7); ctx.fill(); ctx.fillStyle = '#adb5bd'; ctx.beginPath(); ctx.arc(wx, bed.y + bed.h + 16, cs * .12, 0, 7); ctx.fill(); }
      for (const p of pieces) if (p.placed) drawPiece(bx + p.placed[0] * cs, bed.y + p.placed[1] * cs, cs, p);
      // Bóng xem trước chỗ thả
      if (drag) {
        const gx = Math.round((drag.x - drag.ox - bed.x) / cs), gy = Math.round((drag.y - drag.oy - bed.y) / cs), ok = fits(drag.p, gx, gy);
        ctx.fillStyle = ok ? 'rgba(64,192,87,.45)' : 'rgba(250,82,82,.3)';
        for (const [cx, cy] of drag.p.cells) { const x = bed.x + (gx + cx) * cs, y = bed.y + (gy + cy) * cs; if (gx + cx >= 0 && gy + cy >= 0 && gx + cx < cols && gy + cy < rows) ctx.fillRect(x + 2, y + 2, cs - 4, cs - 4); }
      }
      ctx.fillStyle = '#e9ecef'; ctx.fillRect(0, trayTop, W, H - trayTop);
      ctx.fillStyle = '#ced4da'; ctx.fillRect(0, trayTop, W, 6);
      for (const p of pieces) if (!p.placed && (!drag || drag.p !== p)) drawPiece(p.tx, p.ty, ts, p);
      drawAnim(ctx, SH[kid], end?.win || leave ? 'cheer' : drag ? 'hold' : 'idle', t, W - kh * .4, H - 6, kh);
      if (drag) drawPiece(drag.x - drag.ox, drag.y - drag.oy, cs, drag.p);
      F.draw(ctx);
      hud(ctx, W, {score: trucks, lives: 0, time});
      goalPill(ctx, W, trucks, needTrucks);
      if (t < 2) levelBanner(ctx, W, H, lv, `Xếp kín ${needTrucks} xe tải`, 'Kéo khối hàng thả vào thùng xe cho kín chỗ');
      if (end) banner(ctx, W, H, end.win ? endText(true, lv) : 'HẾT GIỜ!', `${trucks}/${needTrucks} xe`);
    }
  }, opts.alive);
}

// ---------- 13. Bong bóng số: bóng bay mang số bay lên, chạm vỡ theo thứ tự 1, 2, 3... (cấp cao đếm cách 2, 5, 10
// hoặc đếm lùi). Ong và bọ rùa bay ngang, chạm nhầm thì mất tim. Bé đứng dưới vỗ tay. ----------
export async function balloons(box, opts) {
  const lv = opts.level || 0, th = theme(lv), kid = kidOf(opts);
  const mode = lv < 15 ? {a: 1, d: 1} : lv < 30 ? {a: 2, d: 2} : lv < 45 ? {a: 5, d: 5} : {a: 20, d: -1};
  const len = Math.min(lv < 15 ? 5 + Math.floor(lv / 3) : 10, mode.d < 0 ? 20 : 10);
  const seq = Array.from({length: len}, (_, i) => mode.d < 0 ? mode.a - i : mode.a + i * mode.d);
  const SH = await sheets([kid, 'critters']);
  await loadAll(['Balloon', 'Red heart', 'Coin', 'Cloud', th.sun]);
  const {cv, ctx, W, H} = canvasIn(box);
  const S = Math.min(W, H), F = fx(), bot = opts.bot;
  const bs = S * ramp(lv, .15, .11), ground = H * .92;
  const HUES = ['#ff6b6b', '#4dabf7', '#51cf66', '#fcc419', '#cc5de8', '#ff922b'];
  const ups = [], bugs = [];
  let idx = 0, lives = 3, t = 0, end = null, endT = 0, spawn = 0, cheer = 0, botT = 0;
  const H0 = [H * .35, H * .55, H * .75];
  const pool = () => { // số đang cần luôn có mặt; thêm số nhiễu trong dãy
    const want = seq[idx]; const on = ups.filter(u => !u.pop);
    if (!on.some(u => u.n === want)) return want;
    const later = seq.slice(idx + 1, idx + 4); return later.length && Math.random() < .7 ? pick(later) : want + pick([1, -1, 3]) * Math.max(1, Math.abs(mode.d));
  };
  const vy = S * ramp(lv, .1, .2);
  taps(cv, {onTap: (x, y) => {
    if (t < 2 || end) return;
    for (const b of bugs) if (Math.hypot(b.x - x, b.y - y) < S * .06) { lives--; sfx('hit'); F.text(x, y, 'Ối!', '#ff8787'); if (lives <= 0) end = {win: false, score: idx * 5}; return; }
    const u = ups.find(u => !u.pop && Math.hypot(u.x - x, u.y - y) < bs * .55);
    if (!u) return;
    if (u.n === seq[idx]) {
      u.pop = .001; idx++; cheer = .8; sfx('pop'); F.burst(u.x, u.y, 16, [u.c, '#fff']);
      if (idx >= seq.length) { end = {win: true, score: idx * 5 + lives * 5}; sfx('win'); }
    } else { lives--; sfx('wrong'); u.shake = .4; F.text(u.x, u.y - bs * .6, `Tìm số ${seq[idx]}`, '#fff'); if (lives <= 0) end = {win: false, score: idx * 5}; }
  }});
  return loop({
    update(dt) {
      t += dt; F.update(dt); cheer = Math.max(0, cheer - dt);
      if (end) { endT += dt; return endT > 2 ? end : null; }
      if (t < 2) return null;
      spawn -= dt;
      if (spawn <= 0 && ups.filter(u => !u.pop).length < Math.round(ramp(lv, 4, 7))) {
        spawn = rand(.6, 1.1);
        ups.push({n: pool(), x: rand(bs, W - bs), y: H0.length ? H0.pop() : H + bs, c: pick(HUES), ph: rand(0, 6), pop: 0, shake: 0, v: vy * rand(.85, 1.2)});
      }
      for (let i = ups.length - 1; i >= 0; i--) {
        const u = ups[i]; u.ph += dt; u.shake = Math.max(0, u.shake - dt);
        if (u.pop) { u.pop += dt; if (u.pop > .3) ups.splice(i, 1); continue; }
        u.y -= u.v * dt; u.x += Math.sin(u.ph * 1.3) * 18 * dt;
        if (u.y < -bs) {
          ups.splice(i, 1);
          // Từ cấp 6: để bóng đang cần bay mất thì mất một tim.
          if (lv >= 5 && u.n === seq[idx] && !ups.some(o => !o.pop && o.n === u.n)) { lives--; sfx('wrong'); F.text(W / 2, 90, 'Bóng bay mất rồi!', '#fff'); if (lives <= 0) { end = {win: false, score: idx * 5}; return null; } }
        }
      }
      if (lv >= 8 && Math.random() < dt * ramp(lv, .15, .45) && bugs.length < 3) { const l = Math.random() < .5; bugs.push({k: pick(['bee', 'ladyfly']), x: l ? -40 : W + 40, y: rand(H * .25, H * .7), vx: (l ? 1 : -1) * S * rand(.2, .35)}); }
      for (let i = bugs.length - 1; i >= 0; i--) { const b = bugs[i]; b.x += b.vx * dt; if (b.x < -60 || b.x > W + 60) bugs.splice(i, 1); }
      if (bot && (botT += dt) > .5) { botT = 0; const u = ups.find(u => !u.pop && u.n === seq[idx] && u.y < H - bs); if (u) { cv.dispatchEvent(new PointerEvent('pointerdown', {clientX: u.x + cv.getBoundingClientRect().left, clientY: u.y + cv.getBoundingClientRect().top})); cv.dispatchEvent(new PointerEvent('pointerup', {clientX: u.x + cv.getBoundingClientRect().left, clientY: u.y + cv.getBoundingClientRect().top})); } }
      return null;
    },
    draw() {
      skyFill(ctx, W, H, th);
      draw(ctx, th.sun, W * .86, H * .14, S * .12);
      draw(ctx, 'Cloud', (t * 12) % (W + 200) - 100, H * .2, S * .2, S * .12, {alpha: .8});
      ctx.fillStyle = th.ground; ctx.fillRect(0, ground, W, H - ground); ctx.fillStyle = th.edge; ctx.fillRect(0, ground, W, 6);
      for (const u of ups) {
        const sx = u.shake ? Math.sin(u.shake * 60) * 6 : 0, k = u.pop ? 1 + u.pop * 3 : 1, a = u.pop ? 1 - u.pop / .3 : 1;
        ctx.strokeStyle = 'rgba(0,0,0,.35)'; ctx.lineWidth = 1.5; ctx.beginPath(); ctx.moveTo(u.x + sx, u.y + bs * .48); ctx.quadraticCurveTo(u.x + sx + Math.sin(u.ph * 2) * 10, u.y + bs * .8, u.x + sx, u.y + bs * 1.1); ctx.stroke();
        draw(ctx, 'Balloon', u.x + sx, u.y, bs * k, bs * 1.1 * k, {alpha: a});
        if (!u.pop) { ctx.font = `800 ${Math.round(bs * .36)}px "Baloo 2", sans-serif`; ctx.textAlign = 'center'; ctx.lineWidth = 6; ctx.strokeStyle = 'rgba(0,0,0,.45)'; ctx.strokeText(u.n, u.x + sx, u.y + bs * .03); ctx.fillStyle = '#fff'; ctx.fillText(u.n, u.x + sx, u.y + bs * .03); }
      }
      for (const b of bugs) drawAnim(ctx, SH.critters, b.k, t, b.x, b.y, S * .08, {flip: b.vx > 0});
      const kh = Math.min(S * .22, H * .16);
      shadow(ctx, W * .5, ground + 4, kh * .5);
      drawAnim(ctx, SH[kid], end?.win || cheer > 0 ? 'cheer' : 'idle', t, W * .5, ground + 4, kh);
      F.draw(ctx);
      hud(ctx, W, {score: idx, lives: 0, time: null}); hearts(ctx, W, lives);
      pill(ctx, W, end ? `✔ ${seq.length}/${seq.length}` : `🎈 Tìm số ${seq[idx]}`, W < 640 ? 62 : 10, 200);
      // Dãy số đã chạm
      const dw = Math.min(40, (W - 40) / seq.length);
      seq.forEach((n, i) => { ctx.fillStyle = i < idx ? '#2f9e44' : 'rgba(0,0,0,.2)'; roundRect(ctx, W / 2 - dw * seq.length / 2 + i * dw + 2, (W < 640 ? 112 : 60), dw - 4, 26, 8); ctx.fill(); ctx.fillStyle = '#fff'; ctx.font = '800 15px "Baloo 2", sans-serif'; ctx.textAlign = 'center'; ctx.fillText(i < idx ? n : '?', W / 2 - dw * seq.length / 2 + i * dw + dw / 2, (W < 640 ? 112 : 60) + 19); });
      if (t < 2) levelBanner(ctx, W, H, lv, mode.d < 0 ? `Đếm lùi từ ${mode.a}` : mode.d > 1 ? `Đếm cách ${mode.d}: ${seq.slice(0, 3).join(', ')}...` : `Chạm bóng theo thứ tự 1 → ${seq[seq.length - 1]}`, 'Chạm đúng số bóng bay · Đừng chạm vào ong');
      if (end) banner(ctx, W, H, end.win ? endText(true, lv) : 'HẾT TIM RỒI!', `${idx}/${seq.length} quả bóng`);
    }
  }, opts.alive);
}
