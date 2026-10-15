// Game trí tuệ ở Khu vui chơi: lập trình robot, nối dây màu, dẫn nước, bảng số thần tốc.
// Đề sinh ngẫu nhiên theo cấp độ, luôn có lời giải. Mỗi lượt 3 câu đố (bảng số: 2 bảng).
import {h, img, shuffle, wait} from '../ui.js?v=4c51d34a6e';
import {sfx, sayPhrase, say, tpl} from '../audio.js?v=4c51d34a6e';
import {MAX_LV} from './funcore.js?v=4c51d34a6e';
import {BOT, figureEl} from './figure.js?v=4c51d34a6e';

const DIRS = {u: [0, -1], r: [1, 0], d: [0, 1], l: [-1, 0]};
// Hoạt ảnh nhỏ bằng Web Animations (đợt 15): nảy, bật, gợn. Máy cũ không có .animate thì bỏ qua.
const BACK = 'cubic-bezier(.34,1.56,.64,1)';
const anim = (el, kf, o) => { try { return el && el.animate ? el.animate(kf, o) : null; } catch (_) { return null; } };
const popIn = (el, d = 260, delay = 0) => anim(el, [{transform: 'scale(.4)', opacity: .3}, {transform: 'scale(1)', opacity: 1}], {duration: d, delay, easing: BACK, fill: 'backwards'});
const bounce = (el, k = 1.18, d = 300, delay = 0) => anim(el, [{transform: 'scale(1)'}, {transform: `scale(${k})`}, {transform: 'scale(1)'}], {duration: d, delay, easing: 'ease-out'});
const ARROW = {u: '⬆️', r: '➡️', d: '⬇️', l: '⬅️'};

function header(box, title) {
  const prog = h('div', {class: 'lg-prog'});
  const lvl = h('span', {class: 'lg-lvl'});
  const head = h('div', {class: 'lg-head'}, h('b', {}, title), lvl, prog);
  const area = h('div', {class: 'lg-area'});
  box.replaceChildren(h('div', {class: 'lg'}, head, area));
  return {area, lvl, prog: (i, n) => prog.replaceChildren(...Array.from({length: n}, (_, k) => h('i', {class: k < i ? 'done' : k === i ? 'now' : ''})))};
}

// Mỗi câu đố là một cấp: giải xong lên cấp ngay (lưu luôn), câu sau khó hơn.
async function sessions(box, opts, title, intro, n, make) {
  const ui = header(box, title);
  let score = 0;
  sayPhrase(intro);
  for (let i = 0; i < n; i++) {
    if (!opts.alive()) return null;
    const lv = Math.min(MAX_LV - 1, opts.level + i);
    ui.prog(i, n);
    ui.lvl.textContent = `Cấp ${lv + 1}`;
    const r = await make(ui.area, lv, i);
    if (r == null || !opts.alive()) return null;
    score += r;
    sfx('power');
    if (opts.levelUp) opts.levelUp();
    const pop = h('div', {class: 'lvup'}, '⭐ ', lv + 1 >= MAX_LV ? 'Cấp cao nhất!' : `Lên cấp ${lv + 2}!`);
    box.append(pop);
    await wait(1300);
    pop.remove();
  }
  ui.prog(n, n);
  return {win: true, score, lvUp: true, ups: n};
}

// ---------- 1. Lập trình robot ----------
function codingLevel(lv) {
  const n = lv < 6 ? 5 : lv < 18 ? 6 : lv < 36 ? 7 : 8, len = Math.min(24, lv < 9 ? 4 + lv : 13 + Math.floor((lv - 9) / 4)), spare = lv < 20 ? 3 : lv < 40 ? 2 : 1;
  for (let tries = 0; tries < 200; tries++) {
    const start = [0, Math.floor(Math.random() * n)];
    const path = [start], seen = new Set([start.join()]);
    let ok = true;
    while (path.length <= len) {
      const [x, y] = path[path.length - 1];
      const opts = shuffle(Object.values(DIRS)).map(([dx, dy]) => [x + dx, y + dy]).filter(([a, b]) => a >= 0 && b >= 0 && a < n && b < n && !seen.has(`${a},${b}`));
      if (!opts.length) { ok = false; break; }
      path.push(opts[0]); seen.add(opts[0].join());
    }
    if (!ok) continue;
    const goal = path[path.length - 1];
    if (Math.abs(goal[0] - start[0]) + Math.abs(goal[1] - start[1]) < Math.min(len, 3)) continue;
    const rocks = [];
    for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) if (!seen.has(`${x},${y}`) && Math.random() < .3) rocks.push([x, y]);
    return {n, start, goal, rocks, coins: shuffle(path.slice(2, -1)).slice(0, lv < 20 ? 2 : 3), max: path.length - 1 + spare};
  }
}

function coding(area, lv, hero) {
  const L = codingLevel(lv);
  const rock = new Set(L.rocks.map(p => p.join()));
  const grid = h('div', {class: 'cg', style: {gridTemplateColumns: `repeat(${L.n}, 1fr)`}});
  const cells = [];
  for (let y = 0; y < L.n; y++) for (let x = 0; x < L.n; x++) {
    const c = h('div', {class: 'cgc'}, rock.has(`${x},${y}`) ? img('Rock') : null);
    cells.push(c); grid.append(c);
  }
  const cell = ([x, y]) => cells[y * L.n + x];
  cell(L.goal).append(img('Glowing star', {class: 'goal'}));
  L.coins.forEach(p => cell(p).append(img('Coin', {class: 'coin'})));
  // Robot người que màu xanh do bé lập trình (không dùng hình linh vật)
  const bot = figureEl({...BOT, shirt: '#339af0', pants: '#1971c2'}, {size: 120, cls: 'bot'});
  const prog = [];
  const progEl = h('div', {class: 'cprog'});
  const run = h('button', {class: 'btn green'}, '▶ Chạy');
  const clear = h('button', {class: 'btn ghost'}, '↺');
  const pad = h('div', {class: 'cpad'}, Object.keys(ARROW).map(d => h('button', {class: 'cbtn', onclick: () => {
    if (prog.length >= L.max || busy) return; prog.push(d); sfx('tap'); draw(); popIn(progEl.children[prog.length - 1]);
  }}, ARROW[d])));
  const draw = () => progEl.replaceChildren(...Array.from({length: L.max}, (_, i) => h('button', {class: `cslot ${prog[i] ? 'on' : ''}`, onclick: () => {
    if (busy || i >= prog.length) return; prog.splice(i, 1); sfx('pop'); draw();
  }}, prog[i] ? ARROW[prog[i]] : '')));
  let busy = false, pos = [...L.start], tries = 0;
  const place = (p, hop = true) => {
    const ox = +bot.style.getPropertyValue('--x'); if (p[0] !== ox) bot.face = p[0] > ox ? 1 : -1; bot.run(.35); bot.style.setProperty('--x', p[0]); bot.style.setProperty('--y', p[1]);
    // Robot nhún lên trong lúc trượt sang ô mới
    if (hop) anim(bot, [{translate: '0 0'}, {translate: '0 -22%', offset: .45}, {translate: '0 0'}], {duration: 350, easing: 'ease-out'});
  };
  grid.append(bot); place(pos, false);
  draw();
  area.replaceChildren(h('div', {class: 'coding'}, h('div', {class: 'cg-wrap', style: {'--n': L.n}}, grid), h('div', {class: 'cside'}, progEl, pad, h('div', {class: 'row'}, clear, run))));
  clear.onclick = () => { if (busy) return; prog.length = 0; draw(); sfx('pop'); };
  return new Promise(resolve => {
    run.onclick = async () => {
      if (busy || !prog.length) return;
      busy = true; tries++;
      pos = [...L.start]; place(pos);
      let got = 0;
      const coinsLeft = new Set(L.coins.map(p => p.join()));
      cells.forEach(c => c.querySelector('.coin') && (c.querySelector('.coin').style.opacity = 1));
      await wait(250);
      for (let i = 0; i < prog.length; i++) {
        progEl.children[i].classList.add('run');
        const [dx, dy] = DIRS[prog[i]];
        const nx = pos[0] + dx, ny = pos[1] + dy;
        if (nx < 0 || ny < 0 || nx >= L.n || ny >= L.n || rock.has(`${nx},${ny}`)) {
          bot.classList.remove('bump'); void bot.offsetWidth; bot.classList.add('bump'); sfx('wrong');
          anim(bot, [{translate: '0 0'}, {translate: `${dx * 18}% ${dy * 18}%`, offset: .3}, {translate: '0 0'}], {duration: 400, easing: 'ease-out'});
          await wait(600); break;
        }
        pos = [nx, ny]; place(pos); sfx('jump');
        if (coinsLeft.has(pos.join())) { coinsLeft.delete(pos.join()); got++; const cn = cell(pos).querySelector('.coin'); sfx('coin');
          anim(cn, [{transform: 'translateY(0) scale(1)', opacity: 1}, {transform: 'translateY(-90%) scale(1.5)', opacity: 1, offset: .5}, {transform: 'translateY(-160%) scale(.6)', opacity: 0}], {duration: 450, easing: 'ease-out'});
          cn.style.opacity = 0; }
        await wait(420);
        progEl.children[i].classList.remove('run');
      }
      progEl.querySelectorAll('.run').forEach(x => x.classList.remove('run'));
      if (pos[0] === L.goal[0] && pos[1] === L.goal[1]) { bot.classList.add('win'); anim(cell(L.goal).querySelector('.goal'), [{transform: 'scale(1) rotate(0)'}, {transform: 'scale(1.9) rotate(180deg)'}, {transform: 'scale(1.3) rotate(360deg)'}], {duration: 700, easing: 'ease-out', fill: 'forwards'}); return resolve(Math.max(3, 12 - tries * 2) + got * 2); }
      sfx('wrong'); await wait(400);
      pos = [...L.start]; place(pos); busy = false;
    };
  });
}

// ---------- 2. Nối dây màu ----------
const FLOW_COLORS = ['#fa5252', '#4c6ef5', '#40c057', '#fab005', '#be4bdb', '#fd7e14', '#15aabf', '#e64980', '#868e96'];

// Đường đi qua mọi ô (Hamilton) bằng thuật toán "backbite", rồi cắt thành các đoạn ≥ 3 ô.
function flowLevel(lv) {
  const n = lv < 4 ? 4 : lv < 10 ? 5 : lv < 20 ? 6 : lv < 32 ? 7 : lv < 46 ? 8 : 9;
  let path = [];
  for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) path.push([y % 2 ? n - 1 - x : x, y]);
  const idx = p => p[1] * n + p[0];
  for (let it = 0; it < n * n * 30; it++) {
    if (Math.random() < .5) path.reverse();
    const [ex, ey] = path[path.length - 1];
    const nb = shuffle(Object.values(DIRS)).map(([dx, dy]) => [ex + dx, ey + dy]).find(([a, b]) => a >= 0 && b >= 0 && a < n && b < n);
    const pos = new Map(path.map((p, i) => [idx(p), i]));
    const j = pos.get(idx(nb));
    if (j == null || j === path.length - 2) continue;
    path = [...path.slice(0, j + 1), ...path.slice(j + 1).reverse()];
  }
  const k = Math.min(FLOW_COLORS.length, n === 4 ? 3 : n);
  const cuts = [];
  let rest = path.length, start = 0;
  for (let c = 0; c < k; c++) {
    const remainingSeg = k - c;
    const minLen = 3, maxLen = rest - minLen * (remainingSeg - 1);
    const len = c === k - 1 ? rest : Math.max(minLen, Math.min(maxLen, Math.round(rest / remainingSeg + (Math.random() - .5) * 3)));
    cuts.push(path.slice(start, start + len)); start += len; rest -= len;
  }
  return {n, segs: cuts};
}

function flow(area, lv) {
  const L = flowLevel(lv);
  const n = L.n;
  const owner = Array(n * n).fill(-1);
  const dots = new Map();
  L.segs.forEach((s, c) => { dots.set(s[0][1] * n + s[0][0], c); dots.set(s[s.length - 1][1] * n + s[s.length - 1][0], c); });
  const paths = L.segs.map(() => []);
  const grid = h('div', {class: 'fg', style: {gridTemplateColumns: `repeat(${n}, 1fr)`}});
  const cells = Array.from({length: n * n}, (_, i) => {
    const c = h('div', {class: 'fgc', 'data-i': i});
    if (dots.has(i)) c.append(h('span', {class: 'dot', style: {background: FLOW_COLORS[dots.get(i)]}}));
    grid.append(c); return c;
  });
  grid.dataset.sol = JSON.stringify(L.segs.map(sg => sg.map(([x, y]) => y * n + x)));  // đáp án (dùng cho kiểm thử tự động)
  area.replaceChildren(h('div', {class: 'flow', style: {'--n': n}}, grid));
  const done = c => { const p = paths[c]; return p.length > 1 && dots.get(p[0]) === c && dots.get(p[p.length - 1]) === c && p[0] !== p[p.length - 1]; };
  const paint = () => {
    cells.forEach((el, i) => {
      el.style.background = owner[i] >= 0 ? FLOW_COLORS[owner[i]] + '40' : '';
      el.querySelectorAll('.bar').forEach(b => b.remove());
    });
    paths.forEach((p, c) => p.forEach((i, k) => {
      for (const j of [p[k - 1], p[k + 1]]) {
        if (j == null) continue;
        const d = j === i - 1 ? 'l' : j === i + 1 ? 'r' : j < i ? 'u' : 'd';
        cells[i].prepend(h('i', {class: `bar ${d}`, style: {background: FLOW_COLORS[c]}}));
      }
    }));
  };
  const clearPath = c => { paths[c].forEach(i => { owner[i] = -1; }); paths[c] = []; };
  let cur = null;
  const cellAt = e => { const el = document.elementFromPoint(e.clientX, e.clientY); const c = el && el.closest('.fgc'); return c ? Number(c.dataset.i) : null; };
  const adj = (a, b) => (Math.abs(a - b) === 1 && Math.floor(a / n) === Math.floor(b / n)) || Math.abs(a - b) === n;
  return new Promise(resolve => {
    grid.addEventListener('pointerdown', e => {
      const i = cellAt(e); if (i == null) return;
      e.preventDefault(); grid.setPointerCapture(e.pointerId);
      if (dots.has(i)) { cur = dots.get(i); clearPath(cur); paths[cur] = [i]; owner[i] = cur; sfx('tap'); }
      else if (owner[i] >= 0) { cur = owner[i]; const p = paths[cur]; const k = p.indexOf(i); p.splice(k + 1).forEach(j => { owner[j] = -1; }); }
      else cur = null;
      paint();
    });
    grid.addEventListener('pointermove', e => {
      if (cur == null) return;
      const i = cellAt(e); const p = paths[cur];
      if (i == null || i === p[p.length - 1]) return;
      if (p.length > 1 && i === p[p.length - 2]) { owner[p.pop()] = -1; paint(); return; }
      if (!adj(i, p[p.length - 1]) || done(cur)) return;
      if (dots.has(i) && dots.get(i) !== cur) return;
      if (owner[i] >= 0 && owner[i] !== cur) { const o = owner[i]; clearPath(o); }
      if (owner[i] === cur) { const k = p.indexOf(i); p.splice(k + 1).forEach(j => { owner[j] = -1; }); }
      else { p.push(i); owner[i] = cur; sfx('count'); bounce(cells[i], 1.08, 180); }
      if (done(cur)) { sfx('star'); const pp = paths[cur]; for (const j of [pp[0], pp[pp.length - 1]]) bounce(cells[j].querySelector('.dot'), 1.4, 380); pp.forEach((j, k) => bounce(cells[j], 1.1, 260, k * 30)); cur = null; }
      paint();
      if (paths.every((_, c) => done(c))) { grid.classList.add('solved'); cells.forEach((el, k) => bounce(el, 1.12, 320, ((k % n) + Math.floor(k / n)) * 40)); const full = owner.every(o => o >= 0); setTimeout(() => resolve(10 + (full ? 5 : 0)), 500); }
    });
    grid.addEventListener('pointerup', () => { cur = null; });
  });
}

// ---------- 3. Dẫn nước: xoay ống ----------
// Mỗi ô là tập hướng mở {u,r,d,l}. Xoay 90° theo chiều kim đồng hồ.
const ROT = {u: 'r', r: 'd', d: 'l', l: 'u'};
const OPP = {u: 'd', d: 'u', l: 'r', r: 'l'};

function pipeLevel(lv) {
  const n = lv < 4 ? 4 : lv < 10 ? 5 : lv < 22 ? 6 : lv < 40 ? 7 : 8;
  for (;;) {
    const sy = Math.floor(Math.random() * n), ey = Math.floor(Math.random() * n);
    const path = [[0, sy]], seen = new Set(['0,' + sy]);
    let ok = false;
    for (let steps = 0; steps < 200; steps++) {
      const [x, y] = path[path.length - 1];
      if (x === n - 1 && y === ey) { ok = true; break; }
      const opts = shuffle(Object.entries(DIRS)).map(([d, [dx, dy]]) => [x + dx, y + dy]).filter(([a, b]) => a >= 0 && b >= 0 && a < n && b < n && !seen.has(`${a},${b}`));
      if (!opts.length) break;
      opts.sort((p, q) => (q[0] - p[0]) * (Math.random() < .6 ? 1 : 0));
      path.push(opts[0]); seen.add(opts[0].join());
    }
    if (!ok || path.length < n + 1) continue;
    const tiles = Array.from({length: n * n}, () => null);
    path.forEach(([x, y], i) => {
      const open = new Set();
      const prev = i === 0 ? [-1, y] : path[i - 1], next = i === path.length - 1 ? [n, y] : path[i + 1];
      for (const [px, py] of [prev, next]) open.add(px < x ? 'l' : px > x ? 'r' : py < y ? 'u' : 'd');
      tiles[y * n + x] = {open, path: true};
    });
    const SHAPES = [['l', 'r'], ['u', 'r'], ['u', 'r', 'd']];
    for (let i = 0; i < n * n; i++) if (!tiles[i]) tiles[i] = {open: new Set(SHAPES[Math.floor(Math.random() * 3)]), path: false};
    // Xáo hướng
    for (const t of tiles) { t.rot = 0; const k = Math.floor(Math.random() * 4); t.need = (4 - k) % 4; for (let r = 0; r < k; r++) { t.open = new Set([...t.open].map(d => ROT[d])); t.rot += 90; } }
    if (tiles[sy * n].open.has('l') && tiles[ey * n + n - 1].open.has('r') && flowFrom(tiles, n, sy, ey).reached) continue;
    return {n, sy, ey, tiles};
  }
}

function flowFrom(tiles, n, sy, ey) {
  const wet = new Set();
  if (!tiles[sy * n].open.has('l')) return {wet, reached: false};
  const q = [[0, sy]]; wet.add(sy * n);
  while (q.length) {
    const [x, y] = q.shift();
    for (const d of tiles[y * n + x].open) {
      const [dx, dy] = DIRS[d], nx = x + dx, ny = y + dy;
      if (nx < 0 || ny < 0 || nx >= n || ny >= n) continue;
      const j = ny * n + nx;
      if (wet.has(j) || !tiles[j].open.has(OPP[d])) continue;
      wet.add(j); q.push([nx, ny]);
    }
  }
  return {wet, reached: wet.has(ey * n + n - 1) && tiles[ey * n + n - 1].open.has('r')};
}

function pipeSvg(open) {
  const arms = {u: 'M50,50 L50,0', r: 'M50,50 L100,50', d: 'M50,50 L50,100', l: 'M50,50 L0,50'};
  const d = Object.keys(arms).filter(k => open.has(k)).map(k => arms[k]).join(' ');
  return `<svg viewBox="0 0 100 100"><path d="${d}" class="pb"/><path d="${d}" class="pw"/><circle cx="50" cy="50" r="15" class="pj"/></svg>`;
}

function pipes(area, lv) {
  const L = pipeLevel(lv);
  const n = L.n;
  // Ô hiển thị theo hình gốc (chưa xoay) + góc xoay CSS; giữ "base" để vẽ.
  const base = L.tiles.map(t => { let o = new Set(t.open); for (let r = 0; r < (t.rot / 90) % 4; r++) o = new Set([...o].map(d => ({u: 'l', r: 'u', d: 'r', l: 'd'})[d])); return o; });
  const grid = h('div', {class: 'pg', style: {gridTemplateColumns: `repeat(${n}, 1fr)`}});
  const els = L.tiles.map((t, i) => {
    const el = h('button', {class: 'pgc', html: pipeSvg(base[i]), 'data-need': t.path ? t.need : ''});
    el.style.setProperty('--r', t.rot + 'deg');
    grid.append(el); return el;
  });
  const src = h('div', {class: 'psrc', style: {top: `calc(${(L.sy + .5) / n * 100}% - 24px)`}}, img('Droplet'));
  const dst = h('div', {class: 'pdst', style: {top: `calc(${(L.ey + .5) / n * 100}% - 28px)`}}, img('Seedling'));
  area.replaceChildren(h('div', {class: 'pipes', style: {'--n': n}}, src, grid, dst));
  const refresh = () => {
    const {wet, reached} = flowFrom(L.tiles, n, L.sy, L.ey);
    els.forEach((el, i) => el.classList.toggle('wet', wet.has(i)));
    return reached;
  };
  refresh();
  let moves = 0;
  return new Promise(resolve => {
    els.forEach((el, i) => el.onclick = () => {
      if (grid.classList.contains('solved')) return;
      const t = L.tiles[i];
      t.open = new Set([...t.open].map(d => ROT[d])); t.rot += 90; moves++;
      el.style.setProperty('--r', t.rot + 'deg'); sfx('tap'); bounce(el, .9, 200);
      if (refresh()) {
        grid.classList.add('solved');
        // Nước chảy: các ô ướt nảy lần lượt từ trái sang phải
        const {wet} = flowFrom(L.tiles, n, L.sy, L.ey);
        [...wet].forEach(i => bounce(els[i], 1.12, 300, (i % n) * 70));
        dst.replaceChildren(img('Sunflower')); popIn(dst.firstChild, 500, n * 70); sfx('win');
        setTimeout(() => resolve(Math.max(4, 15 - Math.floor(moves / 4))), 900);
      }
    });
  });
}

// ---------- 4. Bảng số thần tốc ----------
function schulte(area, lv, content) {
  const n = lv < 3 ? 3 : lv < 10 ? 4 : lv < 30 ? 5 : 6, N = n * n, down = lv >= 8 && lv % 3 === 2;
  const nums = shuffle(Array.from({length: N}, (_, i) => i + 1));
  let next = down ? N : 1, mistakes = 0, found = 0;
  const t0 = performance.now();
  const timer = h('div', {class: 'stimer'}, '0.0s');
  const nextEl = h('div', {class: 'snext'}, down ? 'Đếm ngược! Tìm số ' : 'Tìm số ', h('b', {}, next));
  const grid = h('div', {class: 'sg', style: {gridTemplateColumns: `repeat(${n}, 1fr)`}});
  const COLORS = ['#ff8787', '#74c0fc', '#8ce99a', '#ffd43b', '#b197fc', '#ffa94d'];
  nums.forEach(v => grid.append(h('button', {class: 'sgc', 'data-v': v, style: {'--c': COLORS[v % COLORS.length]}}, v)));
  area.replaceChildren(h('div', {class: 'schulte'}, h('div', {class: 'srow'}, nextEl, timer), grid));
  const sayNum = v => content && (content.calNums[v - 1] ? say(tpl('numBig', content.calNums[v - 1])) : content.nums100 && content.nums100[v] && say(tpl('n100', content.nums100[v])));
  sayNum(next);
  const iv = setInterval(() => { if (!timer.isConnected) return clearInterval(iv); timer.textContent = ((performance.now() - t0) / 1000).toFixed(1) + 's'; }, 100);
  return new Promise(resolve => {
    grid.querySelectorAll('.sgc').forEach(b => b.onclick = () => {
      const v = Number(b.dataset.v);
      if (v !== next) { mistakes++; sfx('wrong'); b.classList.remove('shake'); void b.offsetWidth; b.classList.add('shake'); return; }
      b.classList.add('hit'); sfx('count'); next += down ? -1 : 1; found++;
      anim(b, [{transform: 'scale(1.25)', opacity: 1}, {transform: 'scale(.9)', opacity: .25}], {duration: 280, easing: BACK});
      if (found >= N) { clearInterval(iv); const sec = (performance.now() - t0) / 1000; sfx('win'); setTimeout(() => resolve(Math.max(5, Math.round(N * 2 - sec - mistakes * 2))), 600); return; }
      nextEl.querySelector('b').textContent = next; bounce(nextEl.querySelector('b'), 1.4, 260);
      sayNum(next);
    });
  });
}

export const coding_ = (box, opts) => sessions(box, opts, 'Lập trình robot', 'codingQ', 3, (area, lv) => coding(area, lv, opts.hero));
export const flow_ = (box, opts) => sessions(box, opts, 'Nối dây màu', 'flowQ', 3, (area, lv) => flow(area, lv));
export const pipes_ = (box, opts) => sessions(box, opts, 'Dẫn nước', 'pipesQ', 3, (area, lv) => pipes(area, lv));
export const schulte_ = (box, opts) => sessions(box, opts, 'Bảng số thần tốc', 'schulteQ', 2, (area, lv) => schulte(area, lv, opts.content));
