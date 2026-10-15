// Đảo Lập trình (đợt 16): bé xếp thẻ lệnh cho robot làm vườn đi tưới mầm cây.
// 4 kiểu bài: garden (tìm đường, tưới), loop (thẻ lặp lại), debug (sửa một thẻ sai), trace (đoán robot dừng ở đâu).
// Đề sinh rồi kiểm bằng BFS: số ô lệnh = lời giải ngắn nhất + dư. Bài lặp sinh từ chương trình đáp án, và lời giải
// KHÔNG lặp ngắn nhất phải dài hơn số ô, nên bé buộc phải dùng thẻ lặp lại.
import {h, img, src, shuffle, wait} from '../ui.js?v=4c51d34a6e';
import {sfx, say, phrase} from '../audio.js?v=4c51d34a6e';
import {BOT, figureEl} from './figure.js?v=4c51d34a6e';

const D = [[0, -1], [1, 0], [0, 1], [-1, 0]];      // 0 lên, 1 phải, 2 xuống, 3 trái
const ABS = {U: 0, R: 1, D: 2, L: 3};
const FLOWERS = ['Sunflower', 'Tulip', 'Blossom', 'Hibiscus'];
const PUZZLES = 3, TRACE_Q = 5;
const rand = (a, b) => a + Math.floor(Math.random() * (b - a + 1));
const pick = a => a[Math.floor(Math.random() * a.length)];
const anim = (el, kf, o) => { try { return el && el.animate ? el.animate(kf, o) : null; } catch (_) { return null; } };
const bump = el => { if (!el) return; el.classList.remove('cd-shake'); void el.offsetWidth; el.classList.add('cd-shake'); };

// ---------- Thẻ lệnh: hình SVG (bé chưa biết đọc), chạm thì đọc tên ----------
const ARROW = c => `<path d="M24 5 41 23H30v19H18V23H7z" fill="${c}" stroke="#fff" stroke-width="2.5" stroke-linejoin="round"/>`;
const TURN = '<path d="M33 42V27a10 10 0 0 0-10-10h-5" fill="none" stroke="#f76707" stroke-width="7.5" stroke-linecap="round"/><path d="M20 5 5 17l15 12z" fill="#f76707"/>';
const SVG = {
  U: ARROW('#339af0'), R: `<g transform="rotate(90 24 24)">${ARROW('#339af0')}</g>`,
  D: `<g transform="rotate(180 24 24)">${ARROW('#339af0')}</g>`, L: `<g transform="rotate(-90 24 24)">${ARROW('#339af0')}</g>`,
  F: ARROW('#2f9e44'), TL: TURN, TR: `<g transform="matrix(-1 0 0 1 48 0)">${TURN}</g>`,
  J: '<rect x="17" y="35" width="14" height="9" rx="3" fill="#a0522d"/><path d="M7 40Q24 0 39 34" fill="none" stroke="#7048e8" stroke-width="6" stroke-linecap="round"/><path d="M31 31l13-1-4 12z" fill="#7048e8"/>',
  REP: '<path d="M10 26a14 14 0 0 1 24-12" fill="none" stroke="#e64980" stroke-width="6" stroke-linecap="round"/><path d="M38 6v13H25z" fill="#e64980"/><path d="M38 22a14 14 0 0 1-24 12" fill="none" stroke="#e64980" stroke-width="6" stroke-linecap="round"/><path d="M10 42V29h13z" fill="#e64980"/>'
};
const SAY = {U: 'cmdU', R: 'cmdR', D: 'cmdD', L: 'cmdL', F: 'cmdF', TL: 'cmdTL', TR: 'cmdTR', J: 'cmdJ', W: 'cmdW', REP: 'cmdREP'};
const face = c => c === 'W' ? img('Droplet', {photo: false, class: 'cd-ico'}) : h('span', {class: 'cd-ico', html: `<svg viewBox="0 0 48 48">${SVG[c]}</svg>`});
const card = (c, attrs = {}) => h('button', {class: `cd-card c-${c}`, ...attrs}, face(c));

// ---------- Chương trình: mảng gồm lệnh ('F', 'TL'...) và khối lặp {rep, body: [lệnh]} (không lồng nhau) ----------
const cost = prog => prog.reduce((n, it) => n + (it.rep ? 1 + it.body.length : 1), 0);
const clone = prog => prog.map(it => it.rep ? {rep: it.rep, body: [...it.body]} : it);
function flat(prog) {
  const out = [];
  prog.forEach((it, i) => {
    if (it.rep) { for (let r = 0; r < it.rep; r++) it.body.forEach((c, j) => out.push({c, at: `${i}.${j}`, blk: i, r})); }
    else out.push({c: it, at: `${i}`});
  });
  return out;
}

// ---------- Khu vườn ----------
// M = {n, start: [x, y], dir, rocks: Set(ô), logs: Set(ô), sprouts: [[x, y]]}; ô = y * n + x.
const free = (M, x, y) => x >= 0 && y >= 0 && x < M.n && y < M.n && !M.rocks.has(y * M.n + x) && !M.logs.has(y * M.n + x);

// Chạy chương trình, trả về các bước để diễn hoạt. Dừng ngay khi tưới đủ (bé không bị phạt vì thừa lệnh).
function simulate(M, prog) {
  let [x, y] = M.start, dir = M.dir;
  const wet = new Set(), ev = [], K = M.sprouts.length;
  const done = extra => ({ev, x, y, dir, wet, win: K > 0 && wet.size === K, ...extra});
  for (const st of flat(prog)) {
    const {c} = st;
    if (c in ABS || c === 'F' || c === 'J') {
      if (c in ABS) dir = ABS[c];
      const s = c === 'J' ? 2 : 1, nx = x + D[dir][0] * s, ny = y + D[dir][1] * s;
      if (!free(M, nx, ny)) { ev.push({...st, kind: 'bump', x, y, dir}); return done({bump: true}); }
      x = nx; y = ny; ev.push({...st, kind: c === 'J' ? 'jump' : 'move', x, y, dir});
    } else if (c === 'TL' || c === 'TR') {
      dir = (dir + (c === 'TR' ? 1 : 3)) % 4; ev.push({...st, kind: 'turn', x, y, dir});
    } else if (c === 'W') {
      const k = M.sprouts.findIndex(([a, b]) => a === x && b === y), fresh = k >= 0 && !wet.has(k);
      if (fresh) wet.add(k);
      ev.push({...st, kind: 'water', x, y, dir, k: fresh ? k : -1});
      if (K && wet.size === K) return done({});
    }
  }
  return done({});
}

// BFS lời giải KHÔNG lặp ngắn nhất với bộ lệnh cmds. Trả về {len, prog} hoặc null.
function shortest(M, cmds) {
  const n = M.n, K = M.sprouts.length, full = (1 << K) - 1, abs = cmds.includes('U');
  const sp = new Map(M.sprouts.map(([x, y], i) => [y * n + x, i]));
  const key = (x, y, d, m) => ((m * 4 + d) * n + y) * n + x;
  const s0 = [M.start[0], M.start[1], abs ? 0 : M.dir, 0];
  const prev = new Map([[key(...s0), null]]);
  let q = [s0];
  while (q.length) {
    const nq = [];
    for (const s of q) {
      const [x, y, d, m] = s;
      if (m === full) {
        const prog = [];
        for (let k = key(...s); prev.get(k); k = prev.get(k)[0]) prog.unshift(prev.get(k)[1]);
        return {len: prog.length, prog};
      }
      for (const c of cmds) {
        let t = null;
        if (c in ABS || c === 'F' || c === 'J') {
          const dd = c in ABS ? ABS[c] : d, st = c === 'J' ? 2 : 1, nx = x + D[dd][0] * st, ny = y + D[dd][1] * st;
          if (free(M, nx, ny)) t = [nx, ny, abs ? 0 : dd, m];
        } else if (c === 'TL' || c === 'TR') t = [x, y, (d + (c === 'TR' ? 1 : 3)) % 4, m];
        else if (c === 'W') { const i = sp.get(y * n + x); if (i != null && !(m >> i & 1)) t = [x, y, d, m | 1 << i]; }
        if (!t) continue;
        const k = key(...t);
        if (prev.has(k)) continue;
        prev.set(k, [key(...s), c]);
        nq.push(t);
      }
    }
    q = nq;
  }
  return null;
}

const atoms = cmds => cmds.filter(c => c !== 'REP');

// Bài tìm đường: rải mầm, đá, (hàng khúc gỗ) ngẫu nhiên rồi lọc bằng BFS.
function genGarden(o) {
  const cmds = atoms(o.cmds), abs = cmds.includes('U');
  for (let tries = 0; tries < 400; tries++) {
    const n = o.n, M = {n, rocks: new Set(), logs: new Set(), sprouts: []};
    if (o.jump) {  // một hàng rào khúc gỗ chắn ngang vườn, chỉ nhảy qua được
      const col = Math.random() < .5, at = rand(1, n - 2);
      for (let i = 0; i < n; i++) M.logs.add(col ? i * n + at : at * n + i);
    }
    const empty = () => shuffle([...Array(n * n).keys()].filter(i => !M.logs.has(i) && !M.rocks.has(i)));
    for (const i of empty()) if (Math.random() < o.rocks) M.rocks.add(i);
    const cells = empty();
    if (cells.length < o.k + 1) continue;
    const s = cells.pop();
    M.start = [s % n, Math.floor(s / n)];
    M.dir = abs ? 1 : rand(0, 3);
    M.sprouts = cells.slice(0, o.k).map(i => [i % n, Math.floor(i / n)]);
    const res = shortest(M, cmds);
    if (!res || res.len < o.min || res.len > o.max) continue;
    if (o.detour && shortest({...M, rocks: new Set()}, cmds).len >= res.len) continue;  // phải có đường vòng thật
    if (o.jump && shortest(M, cmds.filter(c => c !== 'J'))) continue;                   // phải dùng thẻ nhảy
    return {...M, cap: res.len + o.spare, sol: res.prog, cmds: o.cmds};
  }
  return null;
}

// Đi thử một chương trình trên vườn trống: các ô đi qua, ô tưới, ô bị nhảy qua (để đặt khúc gỗ).
function walkEmpty(prog, n, start, dir) {
  let [x, y] = start;
  const seen = new Set([y * n + x]), waters = [], mids = new Set();
  for (const {c} of flat(prog)) {
    if (c in ABS || c === 'F' || c === 'J') {
      if (c in ABS) dir = ABS[c];
      const st = c === 'J' ? 2 : 1, nx = x + D[dir][0] * st, ny = y + D[dir][1] * st;
      if (nx < 0 || ny < 0 || nx >= n || ny >= n) return null;
      if (st === 2) mids.add((y + D[dir][1]) * n + x + D[dir][0]);
      x = nx; y = ny; seen.add(y * n + x);
    } else if (c === 'TL' || c === 'TR') dir = (dir + (c === 'TR' ? 1 : 3)) % 4;
    else if (c === 'W') { if (waters.some(([a, b]) => a === x && b === y)) return null; waters.push([x, y]); }
  }
  for (const m of mids) if (seen.has(m)) return null;
  return {x, y, dir, seen, waters, mids};
}

// Mẫu chương trình có lặp (thân lặp dùng TR, mirror đổi sang TL).
const LOOPS = {
  row: () => [{rep: rand(3, 5), body: ['F', 'W']}],
  gap: () => [{rep: rand(2, 3), body: ['F', 'F', 'W']}],
  stairs: () => [{rep: rand(3, 4), body: ['F', 'TR', 'F', 'TL', 'W']}],
  square: () => [{rep: 4, body: ['F', 'F', 'W', 'TR']}],
  jumps: () => [{rep: rand(2, 3), body: ['J', 'W']}],
  corner: () => [{rep: rand(3, 4), body: ['F', 'W']}, 'TR', {rep: rand(2, 4), body: ['F', 'W']}],
  zigzag: () => [{rep: 2, body: ['F', 'F', 'W', 'TR', 'F', 'TR', 'F', 'F', 'W', 'TL', 'F', 'TL']}]
};
const mirror = prog => prog.map(it => it.rep ? {rep: it.rep, body: it.body.map(c => c === 'TR' ? 'TL' : c === 'TL' ? 'TR' : c)} : it === 'TR' ? 'TL' : it === 'TL' ? 'TR' : it);

function genLoop(o) {
  const cmds = atoms(o.cmds);
  for (let tries = 0; tries < 400; tries++) {
    let prog = LOOPS[pick(o.loops)]();
    if (Math.random() < .5) prog = mirror(prog);
    const n = o.n, start = [rand(0, n - 1), rand(0, n - 1)], dir = rand(0, 3);
    const w = walkEmpty(prog, n, start, dir);
    if (!w || !w.waters.length) continue;
    const M = {n, start, dir, rocks: new Set(), logs: new Set(w.mids), sprouts: w.waters};
    for (let i = 0; i < n * n; i++) if (!w.seen.has(i) && !M.logs.has(i) && Math.random() < o.rocks) M.rocks.add(i);
    const cap = cost(prog) + o.spare;
    const res = shortest(M, cmds);
    if (!res || res.len <= cap) continue;  // không dùng lặp mà vẫn vừa số ô thì bài vô nghĩa
    if (!simulate(M, prog).win) continue;
    return {...M, cap, sol: prog, cmds: o.cmds};
  }
  return null;
}

// Bài sửa lỗi: lấy lời giải đúng, đổi đúng một thẻ (hoặc số lần lặp) sao cho chạy sai.
function genDebug(o) {
  for (let tries = 0; tries < 60; tries++) {
    const M = o.loops ? genLoop(o) : genGarden(o);
    if (!M) continue;
    const cmds = atoms(o.cmds);
    const spots = [];
    M.sol.forEach((it, i) => it.rep ? (spots.push({i, rep: true}), it.body.forEach((_, j) => spots.push({i, j}))) : spots.push({i}));
    for (let t = 0; t < 20; t++) {
      const sp = pick(spots), prog = clone(M.sol);
      if (sp.rep) { const r = prog[sp.i].rep + pick([-1, 1]); if (r < 2 || r > 6) continue; prog[sp.i].rep = r; }
      else {
        const old = sp.j == null ? prog[sp.i] : prog[sp.i].body[sp.j];
        const nw = pick(cmds.filter(c => c !== old));
        if (sp.j == null) prog[sp.i] = nw; else prog[sp.i].body[sp.j] = nw;
      }
      if (simulate(M, prog).win) continue;
      return {...M, prog, wrong: sp.rep ? `${sp.i}` : sp.j == null ? `${sp.i}` : `${sp.i}.${sp.j}`};
    }
  }
  return null;
}

// Bài đoán đích: chương trình ngẫu nhiên đi trong vườn, ô cuối khác ô đầu.
function genTrace(o) {
  const cmds = atoms(o.cmds);
  for (let tries = 0; tries < 500; tries++) {
    const n = o.n, start = [rand(0, n - 1), rand(0, n - 1)], dir = cmds.includes('U') ? 1 : rand(0, 3);
    let prog;
    if (o.loops) {
      const body = Array.from({length: rand(2, 3)}, () => pick(cmds));
      if (!body.some(c => c === 'F' || c in ABS)) continue;
      prog = [{rep: rand(2, 3), body}];
      if (Math.random() < .5) prog.push(pick(cmds));
    } else prog = Array.from({length: rand(o.min, o.max)}, () => pick(cmds));
    if (!o.loops && !cmds.includes('U') && (prog[prog.length - 1] === 'TL' || prog[prog.length - 1] === 'TR')) continue;
    const w = walkEmpty(prog, n, start, dir);
    if (!w || (w.x === start[0] && w.y === start[1])) continue;
    if (Math.abs(w.x - start[0]) + Math.abs(w.y - start[1]) < 2 && Math.random() < .7) continue;
    return {n, start, dir, rocks: new Set(), logs: new Set(), sprouts: [], prog, end: [w.x, w.y]};
  }
  return null;
}

// ---------- Bàn cờ vườn ----------
function board(M, rel) {
  const n = M.n;
  const grid = h('div', {class: 'cd-grid', style: {gridTemplateColumns: `repeat(${n}, 1fr)`}});
  const cells = [];
  for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) {
    const i = y * n + x;
    const c = h('div', {class: `cd-cell ${(x + y) % 2 ? 'alt' : ''}`, 'data-x': x, 'data-y': y},
      M.rocks.has(i) ? img('Rock', {photo: false}) : M.logs.has(i) ? img('Wood', {photo: false, class: 'cd-log'}) : null);
    if (x === M.start[0] && y === M.start[1]) c.classList.add('cd-start');
    cells.push(c); grid.append(c);
  }
  const cell = (x, y) => cells[y * n + x];
  const sprouts = M.sprouts.map(([x, y]) => { const el = img('Seedling', {photo: false, class: 'cd-sprout'}); cell(x, y).append(el); return el; });
  const flowers = M.sprouts.map(() => pick(FLOWERS));
  const bot = h('div', {class: 'cd-bot'}, figureEl({...BOT, shirt: '#339af0', pants: '#1971c2'}, {size: 120}), rel ? h('i', {class: 'cd-head'}) : null);
  const fig = bot.firstChild;
  grid.append(bot);
  let ang = M.dir * 90;
  const place = (x, y, dir, hop = 0) => {
    const ox = +bot.style.getPropertyValue('--x');
    if (x !== ox && fig.run) { fig.face = x > ox ? 1 : -1; fig.run(.35); }
    else if (dir === 1 || dir === 3) fig.face = dir === 1 ? 1 : -1;
    // Góc mũi tên hướng cộng dồn để quay đường ngắn nhất (270° → 0° không xoay ngược cả vòng)
    ang += ((dir * 90 - ang) % 360 + 540) % 360 - 180;
    bot.style.setProperty('--x', x); bot.style.setProperty('--y', y); bot.style.setProperty('--dir', ang + 'deg');
    if (hop) anim(fig, [{translate: '0 0'}, {translate: `0 -${hop}%`, offset: .45}, {translate: '0 0'}], {duration: 380, easing: 'ease-out'});
  };
  const reset = () => {
    sprouts.forEach(el => { el.src = src('Seedling'); el.classList.remove('wet'); });
    place(M.start[0], M.start[1], M.dir);
  };
  const water = k => {
    const [x, y] = M.sprouts[k], drop = img('Droplet', {photo: false, class: 'cd-drop'});
    cell(x, y).append(drop);
    anim(drop, [{transform: 'translateY(-80%)', opacity: 0}, {transform: 'translateY(0)', opacity: 1, offset: .6}, {transform: 'translateY(20%) scale(.4)', opacity: 0}], {duration: 420, easing: 'ease-in'});
    setTimeout(() => drop.remove(), 450);
    setTimeout(() => {
      sprouts[k].src = src(flowers[k]); sprouts[k].classList.add('wet');
      anim(sprouts[k], [{transform: 'scale(.4)'}, {transform: 'scale(1.25)'}, {transform: 'scale(1)'}], {duration: 380, easing: 'ease-out'});
    }, 300);
  };
  const splash = (x, y) => {
    const drop = img('Droplet', {photo: false, class: 'cd-drop'});
    cell(x, y).append(drop);
    anim(drop, [{transform: 'translateY(-60%)', opacity: 0}, {transform: 'translateY(10%) scale(.5)', opacity: .9}, {opacity: 0}], {duration: 420});
    setTimeout(() => drop.remove(), 450);
  };
  reset();
  const wrap = h('div', {class: 'cd-board', style: {'--n': n}}, grid);
  return {el: wrap, grid, cell, cells, bot, fig, place, reset, water, splash};
}

// Diễn hoạt một lượt chạy; hl(at, r) tô thẻ đang chạy. Trả về kết quả simulate (null nếu bé thoát).
async function play(g, B, M, prog, hl) {
  B.reset();
  await wait(250);
  const res = simulate(M, prog);
  for (const e of res.ev) {
    if (g.aborted()) return null;
    hl(e.at, e.r);
    if (e.kind === 'bump') {
      const [dx, dy] = D[e.dir];
      anim(B.bot, [{translate: '0 0'}, {translate: `${dx * 20}% ${dy * 20}%`, offset: .3}, {translate: '0 0'}], {duration: 400, easing: 'ease-out'});
      sfx('wrong'); await wait(550);
      break;
    }
    if (e.kind === 'move') { B.place(e.x, e.y, e.dir, 18); sfx('jump'); }
    else if (e.kind === 'jump') { B.place(e.x, e.y, e.dir, 70); sfx('power'); }
    else if (e.kind === 'turn') { B.place(e.x, e.y, e.dir); sfx('tap'); }
    else if (e.kind === 'water') { if (e.k >= 0) { B.water(e.k); sfx('coin'); } else { B.splash(e.x, e.y); sfx('pop'); } }
    await wait(e.kind === 'jump' ? 560 : 440);
  }
  hl(null);
  return res;
}

// ---------- Khung soạn chương trình ----------
// mode 'edit': chạm thẻ trong chương trình để bỏ; 'fix': chạm thẻ để chọn rồi chạm thẻ ở bảng lệnh để thay; 'view': chỉ xem.
function editor({cmds, cap = 99, prog = [], mode = 'edit'}) {
  let target = -1, sel = null, locked = false;
  const progEl = h('div', {class: `cd-prog m-${mode}`});
  const meter = h('div', {class: 'cd-meter'});
  const speak = c => say(phrase(SAY[c]));
  const getAt = at => { const [i, j] = at.split('.').map(Number); return j == null ? prog[i] : prog[i].body[j]; };
  const render = () => {
    progEl.replaceChildren(...prog.map((it, i) => {
      if (!it.rep) return atomEl(it, `${i}`);
      const chip = h('button', {class: 'cd-chip', onclick: e => {
        e.stopPropagation();
        if (locked || mode === 'view') return;
        it.rep = it.rep >= 6 ? 2 : it.rep + 1; sfx('tap'); say(phrase('codeRep' + it.rep)); render();
      }}, '×', it.rep);
      const head = h('button', {class: 'cd-bhead', onclick: () => {
        if (locked || mode !== 'edit') return;
        target = target === i ? -1 : i; sfx('tap'); render();
      }}, face('REP'));
      const kill = mode === 'edit' ? h('button', {class: 'cd-kill', 'aria-label': 'Xoá', onclick: e => {
        e.stopPropagation(); if (locked) return;
        prog.splice(i, 1); target = -1; sfx('pop'); render();
      }}, '✕') : null;
      return h('div', {class: `cd-block ${target === i ? 'tgt' : ''}`, 'data-at': `${i}`}, head, chip,
        h('div', {class: 'cd-body'}, it.body.map((c, j) => atomEl(c, `${i}.${j}`)), mode === 'edit' && target === i ? h('i', {class: 'cd-caret'}) : null), kill);
    }), ...(mode === 'edit' && target < 0 ? [h('i', {class: 'cd-caret'})] : []));
    if (mode === 'edit') {
      const used = cost(prog);
      meter.replaceChildren(...Array.from({length: cap}, (_, k) => h('i', {class: k < used ? 'on' : ''})));
    }
  };
  const atomEl = (c, at) => card(c, {'data-at': at, class: `cd-card c-${c} ${sel === at ? 'sel' : ''}`, onclick: () => {
    if (locked || mode === 'view') return;
    const [i, j] = at.split('.').map(Number);
    if (mode === 'fix') { sel = sel === at ? null : at; sfx('tap'); render(); return; }
    if (j == null) { prog.splice(i, 1); if (target > i) target--; else if (target === i) target = -1; }
    else prog[i].body.splice(j, 1);
    sfx('pop'); render();
  }});
  const pad = mode === 'view' ? null : h('div', {class: 'cd-pad'}, cmds.filter(c => mode === 'edit' || c !== 'REP').map(c => card(c, {onclick: () => {
    if (locked) return;
    speak(c);
    if (mode === 'fix') {
      if (!sel || getAt(sel).rep || c === 'REP') { bump(progEl); sfx('pop'); return; }
      const [i, j] = sel.split('.').map(Number);
      if (j == null) prog[i] = c; else prog[i].body[j] = c;
      sfx('tap'); render();
      const el = progEl.querySelector(`[data-at="${sel}"]`);
      anim(el, [{transform: 'scale(.5)'}, {transform: 'scale(1)'}], {duration: 240, easing: 'ease-out'});
      return;
    }
    if (cost(prog) >= cap) { bump(meter); sfx('wrong'); say(phrase('codeFull')); return; }
    if (c === 'REP') { prog.push({rep: 2, body: []}); target = prog.length - 1; }
    else if (target >= 0 && prog[target]) prog[target].body.push(c);
    else prog.push(c);
    sfx('tap'); render();
    const last = target >= 0 ? progEl.querySelector(`[data-at="${target}"] .cd-body`)?.lastElementChild?.previousElementSibling : progEl.lastElementChild?.previousElementSibling;
    anim(last, [{transform: 'scale(.4)'}, {transform: 'scale(1)'}], {duration: 240, easing: 'cubic-bezier(.34,1.56,.64,1)'});
  }})));
  render();
  const hl = (at, r) => {
    progEl.querySelectorAll('.run').forEach(x => x.classList.remove('run'));
    progEl.querySelectorAll('.cd-chip[data-r]').forEach(x => { x.textContent = '×' + prog[+x.closest('.cd-block').dataset.at].rep; x.removeAttribute('data-r'); });
    if (at == null) return;
    const el = progEl.querySelector(`[data-at="${at}"]`);
    if (el) el.classList.add('run');
    if (r != null) {
      const blk = progEl.querySelector(`[data-at="${at.split('.')[0]}"]`), chip = blk && blk.querySelector('.cd-chip');
      if (chip) { chip.textContent = `${r + 1}/${prog[+blk.dataset.at].rep}`; chip.dataset.r = r; blk.classList.add('run'); }
    }
  };
  return {prog, progEl, meter, pad, hl, render, lock: v => { locked = v; progEl.classList.toggle('locked', v); }, shake: at => {
    const el = progEl.querySelector(`[data-at="${at}"]`); el && el.classList.add('cd-hint'); setTimeout(() => el && el.classList.remove('cd-hint'), 2400);
  }, clear: () => { prog.length = 0; target = -1; sel = null; render(); }};
}

// ---------- Một câu đố xếp lệnh (garden / loop / debug). Trả về số lần chạy sai, null nếu thoát ----------
function puzzle(g, M, lv, fix) {
  const rel = !M.cmds.includes('U');
  const B = board(M, rel);
  const E = editor({cmds: M.cmds, cap: M.cap, prog: fix ? clone(M.prog) : (lv.hint ? [{rep: 2, body: []}] : []), mode: fix ? 'fix' : 'edit'});
  const run = h('button', {class: 'btn green cd-run'}, '▶');
  const clr = fix ? null : h('button', {class: 'btn ghost cd-clr', 'aria-label': 'Xoá hết'}, '↺');
  g.stage.replaceChildren(h('div', {class: 'cdg'}, B.el,
    h('div', {class: 'cd-side'}, fix ? null : E.meter, E.progEl, E.pad, h('div', {class: 'row cd-btns'}, clr, run))));
  g.stage.dataset.sol = JSON.stringify(fix ? {wrong: M.wrong, sol: M.sol} : M.sol);  // đáp án cho kiểm thử tự động
  let fails = 0, busy = false;
  if (clr) clr.onclick = () => { if (busy) return; E.clear(); sfx('pop'); };
  return new Promise(resolve => {
    run.onclick = async () => {
      if (busy || g.aborted()) return;
      if (!cost(E.prog)) { bump(E.progEl); sfx('pop'); return; }
      busy = true; E.lock(true); run.disabled = true;
      const res = await play(g, B, M, E.prog, E.hl);
      if (!res) return resolve(null);
      if (res.win) {
        g.cheer(); sfx('correct'); B.bot.classList.add('win');
        await wait(1100);
        return resolve(fails);
      }
      fails++; g.sad();
      await say(phrase(res.bump ? 'codeBump' : 'codeMissed'));
      if (g.aborted()) return;
      if (fix && fails >= 2) { E.shake(M.wrong); say(phrase('codeDebugHint')); }
      B.reset(); busy = false; E.lock(false); run.disabled = false;
    };
  });
}

async function puzzles(g, lv) {
  const gen = lv.kind === 'loop' ? genLoop : lv.kind === 'debug' ? genDebug : genGarden;
  let fails = 0;
  for (let i = 0; i < PUZZLES; i++) {
    if (g.aborted()) return null;
    g.progress(i, PUZZLES);
    const M = gen(lv);
    if (!M) { console.warn('Không sinh được đề', lv); continue; }
    if (i === 0) say(phrase(lv.say || ({loop: 'codeLoopQ', debug: 'codeDebugQ'}[lv.kind] || 'codeGardenQ')));
    const f = await puzzle(g, M, lv, lv.kind === 'debug');
    if (f == null) return null;
    fails += f;
  }
  g.progress(PUZZLES, PUZZLES);
  return {stars: fails <= 1 ? 3 : fails <= 4 ? 2 : 1};
}

// ---------- Đoán robot dừng ở đâu ----------
async function trace(g, lv) {
  let mistakes = 0;
  for (let q = 0; q < TRACE_Q; q++) {
    if (g.aborted()) return null;
    g.progress(q, TRACE_Q);
    const M = genTrace(lv);
    if (!M) continue;
    const B = board(M, !lv.cmds.includes('U'));
    const E = editor({cmds: lv.cmds, prog: M.prog, mode: 'view'});
    g.stage.replaceChildren(h('div', {class: 'cdg cd-trace'}, B.el, h('div', {class: 'cd-side'}, h('div', {class: 'cd-ask'}, '❓'), E.progEl)));
    g.stage.dataset.sol = JSON.stringify(M.end);
    if (q === 0) say(phrase('codeTraceQ'));
    const tap = await new Promise(res => {
      B.grid.addEventListener('pointerdown', e => {
        const c = e.target.closest('.cd-cell');
        if (!c || g.aborted()) return;
        e.preventDefault();
        clearInterval(off);
        res([+c.dataset.x, +c.dataset.y, c]);
      });
      const off = setInterval(() => { if (g.aborted()) { clearInterval(off); res(null); } }, 500);
    });
    if (!tap) return null;
    tap[2].classList.add('cd-guess'); sfx('tap');
    const r = await play(g, B, M, M.prog, E.hl);
    if (!r) return null;
    const ok = tap[0] === M.end[0] && tap[1] === M.end[1];
    if (ok) { sfx('correct'); g.cheer(); B.bot.classList.add('win'); tap[2].classList.add('cd-ok'); await wait(1100); }
    else {
      mistakes++; sfx('wrong'); g.sad();
      tap[2].classList.add('cd-no'); B.cell(...M.end).classList.add('cd-ok');
      await say(phrase('codeTraceWrong')); await wait(600);
    }
  }
  g.progress(TRACE_Q, TRACE_Q);
  return {stars: mistakes === 0 ? 3 : mistakes <= 2 ? 2 : 1};
}

export const levels = (island, content) => content.codeLevels.map(l => ({name: l.name}));

export function run(g, island, content, li) {
  const lv = content.codeLevels[li];
  g.hideBuddy();
  return lv.kind === 'trace' ? trace(g, lv) : puzzles(g, lv);
}

// Cho kiểm thử tự động (node): sinh đề, giải, chạy thử.
export const _test = {genGarden, genLoop, genDebug, genTrace, simulate, shortest, cost};
