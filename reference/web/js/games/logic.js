// Đảo Tư duy: ghép bóng, quy luật, tìm hình khác nhóm, mê cung, sudoku hình 4×4.
import {h, img, sample, shuffle, wait} from '../ui.js?v=4c51d34a6e';
import {phrase, sfx, say, sayPhrase, tpl, preload} from '../audio.js?v=4c51d34a6e';
import {pageSvg, PRESET} from './art.js?v=4c51d34a6e';
import {runQuiz, starsFor} from './quiz.js?v=4c51d34a6e';

const ROUND = 6;
const praise = () => phrase('praise' + (1 + Math.floor(Math.random() * 6)));
const cats = content => Object.values(content.categories);

function shadow(content, lv) {
  return Array.from({length: ROUND}, () => {
    const cat = sample(cats(content), 1)[0];
    const opts = sample(cat, lv.choices);
    const ans = opts[0];
    return {
      say: phrase('shadowQ'), stage: () => h('div', {class: 'shadow'}, img(ans, {photo: false})),
      choices: shuffle(opts).map(x => ({id: x, node: () => img(x, {photo: false})})),
      answer: ans, reward: praise(), rewardNode: () => img(ans, {photo: false})
    };
  });
}

function pattern(content, lv) {
  return Array.from({length: ROUND}, () => {
    const pat = sample(lv.patterns, 1)[0];
    const letters = [...new Set(pat)];
    const pool = sample(cats(content).flat(), letters.length + 1);
    const map = Object.fromEntries(letters.map((l, i) => [l, pool[i]]));
    const len = pat.length;
    const shown = len * 2 + Math.floor(Math.random() * len);
    const seq = Array.from({length: shown + 1}, (_, i) => map[pat[i % len]]);
    const ans = seq[shown];
    const choices = shuffle([...new Set([ans, ...Object.values(map), pool[letters.length]])]).slice(0, 3);
    if (!choices.includes(ans)) choices[0] = ans;
    return {
      say: phrase('patternQ'),
      stage: () => h('div', {class: 'seq'}, seq.slice(0, shown).map(x => h('span', {}, img(x))), h('span', {class: 'q'}, '?')),
      choices: shuffle(choices).map(x => ({id: x, node: () => img(x)})),
      answer: ans, reward: praise(), rewardNode: () => img(ans)
    };
  });
}

function odd(content, lv) {
  return Array.from({length: ROUND}, () => {
    const [a, b] = sample(cats(content), 2);
    const same = sample(a, lv.choices - 1), diff = sample(b, 1)[0];
    return {
      say: phrase('oddQ'),
      choices: shuffle([...same, diff]).map(x => ({id: x, node: () => img(x)})),
      answer: diff, reward: praise(), rewardNode: () => img(diff)
    };
  });
}

// ---------- Mê cung: sinh bằng DFS, bé kéo ngón tay (hoặc chạm ô kề) để đi tới ngôi sao ----------
function makeMaze(n) {
  const walls = Array.from({length: n}, () => Array.from({length: n}, () => ({t: 1, r: 1, b: 1, l: 1})));
  const seen = Array.from({length: n}, () => Array(n).fill(false));
  const stack = [[0, 0]];
  seen[0][0] = true;
  const DIRS = [[0, -1, 't', 'b'], [1, 0, 'r', 'l'], [0, 1, 'b', 't'], [-1, 0, 'l', 'r']];
  while (stack.length) {
    const [x, y] = stack[stack.length - 1];
    const next = shuffle(DIRS).find(([dx, dy]) => seen[y + dy]?.[x + dx] === false);
    if (!next) { stack.pop(); continue; }
    const [dx, dy, w1, w2] = next;
    walls[y][x][w1] = 0; walls[y + dy][x + dx][w2] = 0;
    seen[y + dy][x + dx] = true;
    stack.push([x + dx, y + dy]);
  }
  return walls;
}

const SVGNS = 'http://www.w3.org/2000/svg';
const sv = (tag, attrs = {}) => { const e = document.createElementNS(SVGNS, tag); for (const k in attrs) e.setAttribute(k, attrs[k]); return e; };

function maze(g, lv, buddyImg) {
  const n = lv.size, C = 100, W = n * C;
  const walls = makeMaze(n);
  const svg = sv('svg', {viewBox: `-8 -8 ${W + 16} ${W + 16}`, class: 'maze'});
  svg.append(sv('rect', {x: 0, y: 0, width: W, height: W, rx: 18, class: 'floor'}));
  const trail = sv('polyline', {class: 'trail', points: `${C / 2},${C / 2}`});
  svg.append(trail);
  for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) {
    const w = walls[y][x], X = x * C, Y = y * C;
    const line = (x1, y1, x2, y2) => svg.append(sv('line', {x1, y1, x2, y2, class: 'wall'}));
    if (w.t) line(X, Y, X + C, Y);
    if (w.l) line(X, Y, X, Y + C);
    if (y === n - 1 && w.b) line(X, Y + C, X + C, Y + C);
    if (x === n - 1 && w.r) line(X + C, Y, X + C, Y + C);
  }
  const goal = sv('image', {href: 'img/glowing-star.webp', x: W - C + 12, y: W - C + 12, width: C - 24, height: C - 24});
  const me = sv('image', {href: buddyImg, x: 8, y: 8, width: C - 16, height: C - 16, class: 'me'});
  svg.append(goal, me);
  g.stage.replaceChildren(h('div', {class: 'maze-wrap'}, svg));
  g.progress(0, 1);
  let cx = 0, cy = 0;
  const path = [[0, 0]];
  return new Promise(resolve => {
    const canGo = (x, y) => {
      const dx = x - cx, dy = y - cy;
      if (Math.abs(dx) + Math.abs(dy) !== 1) return false;
      const w = walls[cy][cx];
      return !((dx === 1 && w.r) || (dx === -1 && w.l) || (dy === 1 && w.b) || (dy === -1 && w.t));
    };
    const moveTo = (x, y) => {
      // Đi lùi thì xoá vết; đi tới thì nối vết.
      const back = path.length > 1 && path[path.length - 2][0] === x && path[path.length - 2][1] === y;
      if (back) path.pop(); else path.push([x, y]);
      cx = x; cy = y;
      me.setAttribute('x', x * C + 8); me.setAttribute('y', y * C + 8);
      trail.setAttribute('points', path.map(([a, b]) => `${a * C + C / 2},${b * C + C / 2}`).join(' '));
      sfx('tap');
      if (x === n - 1 && y === n - 1) {
        svg.onpointermove = svg.onpointerdown = null;
        sfx('correct'); g.cheer(); g.progress(1, 1);
        wait(700).then(() => resolve({stars: 3}));
      }
    };
    const cellAt = e => {
      const p = new DOMPoint(e.clientX, e.clientY).matrixTransform(svg.getScreenCTM().inverse());
      return [Math.floor(p.x / C), Math.floor(p.y / C)];
    };
    const handle = e => {
      if (e.type === 'pointermove' && !e.buttons && e.pointerType === 'mouse') return;
      const [x, y] = cellAt(e);
      if (x === cx && y === cy) return;
      if (canGo(x, y)) moveTo(x, y);
      else if (e.type === 'pointerdown') sfx('pop');
    };
    svg.onpointerdown = e => { svg.setPointerCapture(e.pointerId); handle(e); };
    svg.onpointermove = handle;
  });
}

// ---------- Sudoku 4×4 bằng hình ----------
function makeSudoku() {
  const base = [[0, 1, 2, 3], [2, 3, 0, 1], [1, 0, 3, 2], [3, 2, 1, 0]];
  const sym = shuffle([0, 1, 2, 3]);
  const rows = [...shuffle([0, 1]), ...shuffle([2, 3])];
  const cols = [...shuffle([0, 1]), ...shuffle([2, 3])];
  const band = Math.random() < .5 ? [0, 1, 2, 3] : [2, 3, 0, 1];
  const stack = Math.random() < .5 ? [0, 1, 2, 3] : [2, 3, 0, 1];
  return band.map(r => stack.map(c => sym[base[rows[r]][cols[c]]]));
}

function sudoku(g, lv, content) {
  const pics = sample(content.categories.animals, 4);
  const sol = makeSudoku();
  const blanks = new Set(sample([...Array(16).keys()], lv.blanks));
  let selected = null, mistakes = 0, left = blanks.size;
  const cells = [];
  const grid = h('div', {class: 'sudoku'});
  for (let i = 0; i < 16; i++) {
    const r = Math.floor(i / 4), c = i % 4;
    const cell = h('button', {class: `cell ${blanks.has(i) ? 'empty' : 'given'} ${r === 1 ? 'rb' : ''} ${c === 1 ? 'cb' : ''}`,
      onclick: () => {
        if (!blanks.has(i) || cell.classList.contains('filled')) return;
        cells.forEach(x => x.classList.remove('sel'));
        cell.classList.add('sel'); selected = i; sfx('tap');
      }}, blanks.has(i) ? '' : img(pics[sol[r][c]]));
    cells.push(cell); grid.append(cell);
  }
  const palette = h('div', {class: 'sudoku-pal'});
  g.stage.replaceChildren(h('div', {class: 'sudoku-wrap'}, grid, palette));
  g.progress(0, left);
  return new Promise(resolve => {
    // Chọn sẵn ô trống đầu tiên cho bé.
    const firstEmpty = () => cells.findIndex((x, i) => blanks.has(i) && !x.classList.contains('filled'));
    const select = i => { cells.forEach(x => x.classList.remove('sel')); if (i >= 0) { cells[i].classList.add('sel'); selected = i; } };
    select(firstEmpty());
    pics.forEach((p, k) => palette.append(h('button', {class: 'pal', onclick: async () => {
      if (selected == null) return;
      const r = Math.floor(selected / 4), c = selected % 4;
      const cell = cells[selected];
      if (sol[r][c] === k) {
        cell.replaceChildren(img(p)); cell.classList.add('filled'); cell.classList.remove('sel');
        sfx('correct'); g.cheer();
        left--; g.progress(blanks.size - left, blanks.size);
        if (!left) { await wait(700); return resolve({stars: starsFor(mistakes)}); }
        select(firstEmpty());
      } else {
        mistakes++; sfx('wrong'); g.sad();
        cell.classList.remove('shake'); void cell.offsetWidth; cell.classList.add('shake');
      }
    }}, img(p))));
  });
}

// ---------- Ghép tranh: kéo mảnh (hoặc chạm mảnh rồi chạm ô) vào đúng chỗ ----------
function jigsaw(g, lv) {
  const cols = lv.pieces, rows = lv.rows || lv.pieces, W = 400 / cols, H = 300 / rows;
  const board = h('div', {class: 'jboard', style: {gridTemplateColumns: `repeat(${cols}, 1fr)`, gridTemplateRows: `repeat(${rows}, 1fr)`}});
  const ghost = pageSvg(lv.page).svg; ghost.classList.add('jghost');
  const tray = h('div', {class: 'jtray'});
  const slots = [];
  for (let i = 0; i < cols * rows; i++) { const sl = h('div', {class: 'jslot', 'data-i': i}); slots.push(sl); board.append(sl); }
  const piece = i => {
    const c = i % cols, r = Math.floor(i / cols);
    return h('div', {class: 'jpiece', 'data-i': i}, pageSvg(lv.page, PRESET[lv.page], `${c * W} ${r * H} ${W} ${H}`).svg);
  };
  shuffle([...Array(cols * rows).keys()]).forEach(i => tray.append(piece(i)));
  g.stage.replaceChildren(h('div', {class: 'jigsaw'}, h('div', {class: 'jwrap'}, ghost, board), tray));
  tray.style.setProperty('--pw', `${Math.min(150, 560 / cols)}px`);
  g.progress(0, cols * rows);
  say(phrase('jigsawQ'));
  let placed = 0, mistakes = 0, selected = null;
  return new Promise(resolve => {
    const place = async (pc, slot) => {
      if (Number(pc.dataset.i) !== Number(slot.dataset.i) || slot.firstChild) {
        mistakes++; sfx('wrong'); pc.classList.remove('shake'); void pc.offsetWidth; pc.classList.add('shake');
        return;
      }
      pc.classList.remove('sel'); pc.style.transform = '';
      slot.append(pc.firstChild); pc.remove(); slot.classList.add('ok');
      sfx('correct'); g.cheer();
      placed++; g.progress(placed, cols * rows);
      if (placed === cols * rows) { ghost.remove(); board.classList.add('done'); await wait(900); resolve({stars: starsFor(Math.max(0, mistakes - 1))}); }
    };
    tray.addEventListener('pointerdown', e => {
      const pc = e.target.closest('.jpiece'); if (!pc) return;
      e.preventDefault();
      const sx = e.clientX, sy = e.clientY;
      pc.setPointerCapture(e.pointerId); pc.classList.add('drag');
      const move = ev => { pc.style.transform = `translate(${ev.clientX - sx}px, ${ev.clientY - sy}px) scale(1.05)`; };
      const up = ev => {
        pc.removeEventListener('pointermove', move); pc.removeEventListener('pointerup', up); pc.removeEventListener('pointercancel', up);
        pc.classList.remove('drag');
        const moved = Math.hypot(ev.clientX - sx, ev.clientY - sy);
        pc.style.visibility = 'hidden';
        const under = document.elementFromPoint(ev.clientX, ev.clientY);
        pc.style.visibility = '';
        const slot = under && under.closest('.jslot');
        pc.style.transform = '';
        if (slot && moved > 10) return place(pc, slot);
        if (moved <= 10) { tray.querySelectorAll('.sel').forEach(x => x.classList.remove('sel')); pc.classList.add('sel'); selected = pc; sfx('tap'); }
      };
      pc.addEventListener('pointermove', move); pc.addEventListener('pointerup', up); pc.addEventListener('pointercancel', up);
    });
    board.addEventListener('click', e => {
      const slot = e.target.closest('.jslot');
      if (slot && selected && selected.isConnected) place(selected, slot);
    });
  });
}

// ---------- Sắp xếp trình tự: chạm hình để đưa vào ô trống tiếp theo ----------
async function seq(g, lv, content) {
  const sets = lv.sets.map(id => content.sequences.find(s => s.id === id));
  preload(sets.flatMap(s => s.steps.map(([, n]) => tpl('seqStep', {name: n}))));
  let mistakes = 0;
  await sayPhrase('seqQ');
  for (let r = 0; r < sets.length; r++) {
    if (g.aborted()) return null;
    g.progress(r, sets.length);
    const st = sets[r];
    const N = st.steps.length;
    const slots = Array.from({length: N}, (_, i) => h('button', {class: 'qslot', 'data-i': i}, h('b', {}, i + 1)));
    const tray = h('div', {class: 'qtray'});
    g.stage.replaceChildren(h('div', {class: 'seqgame'}, h('div', {class: 'stitle2'}, st.name), h('div', {class: 'qslots'}, slots), tray));
    await new Promise(resolve => {
      const card = (k) => {
        const [im, name] = st.steps[k];
        const c = h('button', {class: 'qcard', 'data-k': k}, img(im), h('span', {}, name));
        c.onclick = async () => {
          if (c.parentElement === tray) {
            const empty = slots.find(sl => !sl.querySelector('.qcard'));
            if (!empty) return;
            empty.append(c); sfx('pop'); say(tpl('seqStep', {name}));
            if (slots.every(sl => sl.querySelector('.qcard'))) await check();
          } else { tray.append(c); sfx('tap'); }
        };
        return c;
      };
      shuffle([...Array(N).keys()]).forEach(k => tray.append(card(k)));
      const check = async () => {
        const wrong = slots.filter((sl, i) => Number(sl.querySelector('.qcard').dataset.k) !== i);
        if (!wrong.length) {
          sfx('correct'); g.cheer();
          for (const sl of slots) { if (g.aborted()) return; sl.classList.add('ok'); await say(tpl('seqStep', {name: st.steps[Number(sl.dataset.i)][1]})); }
          await wait(500);
          return resolve();
        }
        mistakes++; sfx('wrong'); g.sad();
        wrong.forEach(sl => { sl.classList.remove('shake'); void sl.offsetWidth; sl.classList.add('shake'); });
        await sayPhrase('seqWrong');
        if (g.aborted()) return;
        wrong.forEach(sl => tray.append(sl.querySelector('.qcard')));
      };
    });
  }
  g.progress(sets.length, sets.length);
  return {stars: starsFor(mistakes)};
}

// ---------- Tìm điểm khác nhau ----------
const DIFF_COLORS = ['#e03131', '#1971c2', '#2f9e44', '#f08c00', '#9c36b5', '#212529'];
function spot(g, lv) {
  const A = pageSvg(lv.page), B = pageSvg(lv.page);
  const wrap = h('div', {class: 'spot'}, h('div', {class: 'spic'}, A.svg), h('div', {class: 'spic'}, B.svg));
  g.stage.replaceChildren(wrap);
  // Chọn vùng khác: bỏ 2 vùng nền đầu tiên; vùng nhỏ thì ẩn hẳn, vùng lớn thì đổi màu.
  const cands = B.regions.map((r, i) => i).slice(2);
  const diffs = new Set(sample(cands, lv.diffs));
  for (const i of diffs) {
    const r = B.regions[i], bb = r.getBBox();
    if (bb.width * bb.height < 2500 && Math.random() < .5) r.setAttribute('opacity', '0');
    else {
      const cur = r.getAttribute('fill');
      r.setAttribute('fill', sample(DIFF_COLORS.filter(c => c !== cur), 1)[0]);
    }
  }
  g.progress(0, diffs.size);
  say(phrase('spotQ'));
  let found = 0, mistakes = 0;
  const NS = 'http://www.w3.org/2000/svg';
  const ring = (svg, bb) => {
    const c = document.createElementNS(NS, 'circle');
    c.setAttribute('cx', bb.x + bb.width / 2); c.setAttribute('cy', bb.y + bb.height / 2);
    c.setAttribute('r', Math.max(14, Math.max(bb.width, bb.height) / 2 + 6)); c.setAttribute('class', 'ring');
    svg.append(c);
  };
  return new Promise(resolve => {
    [A, B].forEach(P => P.regions.forEach((r, i) => r.addEventListener('pointerdown', async e => {
      e.preventDefault(); e.stopPropagation();
      if (diffs.has(i)) {
        diffs.delete(i);
        const bb = A.regions[i].getBBox();
        ring(A.svg, bb); ring(B.svg, bb);
        sfx('correct'); g.cheer();
        found++; g.progress(found, lv.diffs);
        if (!diffs.size) { await wait(900); resolve({stars: starsFor(Math.max(0, mistakes - 2))}); }
      } else {
        // Chạm vùng nền lớn không tính lỗi để bé đỡ nản; chỉ rung nhẹ.
        if (i > 1) mistakes++;
        sfx('pop');
        P.svg.parentElement.classList.remove('shake'); void P.svg.parentElement.offsetWidth; P.svg.parentElement.classList.add('shake');
      }
    })));
  });
}

export const levels = (island, content) => content.logicLevels.map(l => ({name: l.name}));

export function run(g, island, content, li) {
  const lv = content.logicLevels[li];
  if (lv.kind === 'maze') { say(phrase('mazeQ')); return maze(g, lv, g.buddySrc); }
  if (lv.kind === 'sudoku') { say(phrase('sudokuQ')); return sudoku(g, lv, content); }
  if (lv.kind === 'jigsaw') { g.hideBuddy(); return jigsaw(g, lv); }
  if (lv.kind === 'seq') return seq(g, lv, content);
  if (lv.kind === 'spot') { g.hideBuddy(); return spot(g, lv); }
  const make = {shadow, pattern, odd}[lv.kind];
  return runQuiz(g, make(content, lv));
}
