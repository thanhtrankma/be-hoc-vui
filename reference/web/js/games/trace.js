// Đảo Tập viết: bé tô chữ/số bằng ngón tay trên dòng kẻ ô li. Mực chỉ chảy khi ngón tay đi đúng nét, đúng chiều.
import {h, img, wait} from '../ui.js?v=4c51d34a6e';
import {tpl, say, sayPhrase, sfx, preload} from '../audio.js?v=4c51d34a6e';

// Hệ toạ độ 100×150: dòng trên 10, đường kẻ giữa 60, dòng kẻ chân 110, dòng dưới 145.
const AS = 10, XH = 60, BL = 110, DS = 145;
const HAT = [['M', 36, 49], ['L', 50, 36], ['L', 64, 49]];
const BREVE = [['A', 50, 38, 11, 180, 0]];
const roundA = (cx, cy, r = 24) => [['A', cx, cy, r, -25, -385]];  // nét cong kín, ngược chiều kim đồng hồ

// Mỗi chữ: danh sách nét theo thứ tự viết. Lệnh: M/L/Q như SVG, A = cung tròn (cx, cy, r, góc đầu, góc cuối),
// E = cung elip (cx, cy, rx, ry, góc đầu, góc cuối). Góc tính theo màn hình (0 = phải, 90 = dưới); góc giảm = ngược kim đồng hồ.
export const GLYPHS = {
  o: [[['A', 50, 85, 25, -60, -420]]],
  'ô': [[['A', 50, 85, 25, -60, -420]], HAT],
  'ơ': [[['A', 48, 85, 25, -60, -420]], [['M', 68, 68], ['Q', 80, 66, 82, 54]]],
  a: [roundA(47, 85), [['M', 72, XH], ['L', 72, BL]]],
  'ă': [roundA(47, 85), [['M', 72, XH], ['L', 72, BL]], BREVE],
  'â': [roundA(47, 85), [['M', 72, XH], ['L', 72, BL]], HAT],
  c: [[['A', 52, 85, 25, -40, -320]]],
  e: [[['M', 27, 86], ['L', 75, 86], ['A', 51, 86, 24, 0, -315]]],
  'ê': [[['M', 27, 86], ['L', 75, 86], ['A', 51, 86, 24, 0, -315]], HAT],
  b: [[['M', 28, AS], ['L', 28, BL]], [['A', 50, 86, 22, 180, 540]]],
  d: [roundA(50, 86, 23), [['M', 73, AS], ['L', 73, BL]]],
  'đ': [roundA(50, 86, 23), [['M', 73, AS], ['L', 73, BL]], [['M', 60, 32], ['L', 86, 32]]],
  i: [[['M', 50, XH], ['L', 50, BL]], [['M', 50, 40], ['L', 50, 45]]],
  t: [[['M', 48, 24], ['L', 48, 102], ['Q', 48, 111, 60, 110]], [['M', 32, XH], ['L', 66, XH]]],
  u: [[['M', 28, XH], ['L', 28, 88], ['A', 50, 88, 22, 180, 0], ['L', 72, XH]], [['M', 72, XH], ['L', 72, BL]]],
  'ư': [[['M', 28, XH], ['L', 28, 88], ['A', 50, 88, 22, 180, 0], ['L', 72, XH]], [['M', 72, XH], ['L', 72, BL]], [['M', 72, 62], ['Q', 84, 60, 84, 48]]],
  l: [[['M', 50, AS], ['L', 50, BL]]],
  h: [[['M', 28, AS], ['L', 28, BL]], [['M', 28, 84], ['A', 50, 84, 22, 180, 360], ['L', 72, BL]]],
  k: [[['M', 30, AS], ['L', 30, BL]], [['M', 70, XH], ['L', 31, 88], ['L', 72, BL]]],
  m: [[['M', 18, XH], ['L', 18, BL]], [['M', 18, 80], ['A', 34, 80, 16, 180, 360], ['L', 50, BL]], [['M', 50, 80], ['A', 66, 80, 16, 180, 360], ['L', 82, BL]]],
  n: [[['M', 26, XH], ['L', 26, BL]], [['M', 26, 82], ['A', 49, 82, 23, 180, 360], ['L', 72, BL]]],
  r: [[['M', 32, XH], ['L', 32, BL]], [['M', 32, 82], ['A', 52, 82, 20, 180, 310]]],
  g: [roundA(48, 84, 23), [['M', 71, XH], ['L', 71, 125], ['A', 51, 125, 20, 0, 160]]],
  p: [[['M', 28, XH], ['L', 28, DS]], [['A', 50, 85, 22, 180, 540]]],
  q: [roundA(50, 85, 23), [['M', 73, XH], ['L', 73, DS]]],
  y: [[['M', 27, XH], ['L', 50, BL]], [['M', 74, XH], ['L', 38, DS]]],
  s: [[['A', 50, 73, 13, -30, -270], ['A', 50, 98, 12, -90, 160]]],
  v: [[['M', 26, XH], ['L', 50, BL], ['L', 74, XH]]],
  x: [[['M', 28, XH], ['L', 72, BL]], [['M', 72, XH], ['L', 28, BL]]],
  0: [[['E', 50, 68, 23, 42, -90, -450]]],
  1: [[['M', 34, 44], ['L', 56, 26], ['L', 56, BL]]],
  2: [[['A', 50, 48, 22, 200, 380], ['L', 28, BL], ['L', 74, BL]]],
  3: [[['A', 48, 46, 20, 210, 450], ['A', 48, 88, 22, -90, 155]]],
  4: [[['M', 60, 26], ['L', 24, 84], ['L', 78, 84]], [['M', 60, 52], ['L', 60, BL]]],
  5: [[['M', 36, 28], ['L', 36, 64], ['A', 50, 85, 24, -125, 155]], [['M', 36, 28], ['L', 72, 28]]],
  6: [[['M', 68, 30], ['Q', 30, 44, 28, 88], ['A', 50, 88, 22, 180, -180]]],
  7: [[['M', 26, 28], ['L', 74, 28], ['L', 40, BL]]],
  8: [[['A', 50, 46, 19, -60, -420]], [['A', 50, 88, 22, -90, 270]]],
  9: [[['A', 48, 48, 21, 0, -360], ['L', 69, BL]]]
};

const rad = d => d * Math.PI / 180;
const r2 = n => Math.round(n * 100) / 100;

// Đổi danh sách lệnh thành chuỗi path SVG (cung chia nhỏ ≤ 90° để vẽ chính xác).
export function compile(stroke) {
  let d = '', cur = null;
  const moveOrLine = (x, y) => {
    if (!cur) d += `M${r2(x)},${r2(y)}`;
    else if (Math.hypot(cur[0] - x, cur[1] - y) > .5) d += `L${r2(x)},${r2(y)}`;
    cur = [x, y];
  };
  for (const c of stroke) {
    if (c[0] === 'M') { d += `M${c[1]},${c[2]}`; cur = [c[1], c[2]]; }
    else if (c[0] === 'L') { d += `L${c[1]},${c[2]}`; cur = [c[1], c[2]]; }
    else if (c[0] === 'Q') { d += `Q${c[1]},${c[2]} ${c[3]},${c[4]}`; cur = [c[3], c[4]]; }
    else {
      const [cx, cy, rx, ry, a0, a1] = c[0] === 'A' ? [c[1], c[2], c[3], c[3], c[4], c[5]] : c.slice(1);
      const pt = a => [cx + rx * Math.cos(rad(a)), cy + ry * Math.sin(rad(a))];
      moveOrLine(...pt(a0));
      const steps = Math.ceil(Math.abs(a1 - a0) / 90), sweep = a1 > a0 ? 1 : 0;
      for (let k = 1; k <= steps; k++) {
        const [x, y] = pt(a0 + (a1 - a0) * k / steps);
        d += `A${rx},${ry} 0 0 ${sweep} ${r2(x)},${r2(y)}`;
        cur = [x, y];
      }
    }
  }
  return d;
}

const NS = 'http://www.w3.org/2000/svg';
const sv = (tag, attrs = {}) => { const e = document.createElementNS(NS, tag); for (const k in attrs) e.setAttribute(k, attrs[k]); return e; };
const TOL = 15, LOOK = 14, STEP = 2;

// Tô một chữ. Trả về Promise khi bé tô xong mọi nét.
function traceChar(stage, ch) {
  const svg = sv('svg', {viewBox: '-6 0 112 150', class: 'trace-svg'});
  for (const [y, cls] of [[AS, 'l2'], [XH, 'l1'], [BL, 'l0'], [DS, 'l2']]) svg.append(sv('line', {x1: -6, x2: 106, y1: y, y2: y, class: `ol ${cls}`}));
  const strokes = GLYPHS[ch].map(compile);
  const guides = strokes.map(d => sv('path', {d, class: 'guide'}));
  const dashes = strokes.map(d => sv('path', {d, class: 'dash'}));
  const inks = strokes.map(d => sv('path', {d, class: 'ink', visibility: 'hidden'}));
  svg.append(...guides, ...dashes, ...inks);
  const dot = sv('circle', {r: 7, class: 'start'});
  const num = sv('text', {class: 'snum', 'text-anchor': 'middle'});
  svg.append(dot, num);
  stage.replaceChildren(h('div', {class: 'trace-wrap'}, svg));

  return new Promise(resolve => {
    let si = 0, pi = 0, drawing = false, samples = [], total = 0;
    function startStroke() {
      const p = inks[si];
      total = p.getTotalLength();
      samples = [];
      for (let l = 0; l <= total; l += STEP) { const q = p.getPointAtLength(l); samples.push([q.x, q.y]); }
      p.style.strokeDasharray = `${total} ${total}`;
      p.style.strokeDashoffset = total;
      p.setAttribute('visibility', 'visible');
      pi = 0;
      guides.forEach((g, k) => g.classList.toggle('now', k === si));
      dashes.forEach((g, k) => g.classList.toggle('now', k === si));
      placeDot();
    }
    function placeDot() {
      const [x, y] = samples[pi];
      dot.setAttribute('cx', x); dot.setAttribute('cy', y);
      num.setAttribute('x', x); num.setAttribute('y', y - 11);
      num.textContent = strokes.length > 1 ? si + 1 : '';
      dot.classList.toggle('moving', pi > 0);
    }
    const toSvg = e => { const p = new DOMPoint(e.clientX, e.clientY).matrixTransform(svg.getScreenCTM().inverse()); return [p.x, p.y]; };
    const dist = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1]);
    function advance(p) {
      let best = -1;
      for (let j = pi; j <= Math.min(samples.length - 1, pi + LOOK); j++) if (dist(samples[j], p) < TOL) best = j;
      if (best > pi) {
        pi = best;
        inks[si].style.strokeDashoffset = Math.max(0, total - pi * STEP);
        placeDot();
      }
      if (pi >= samples.length - 3) {
        inks[si].style.strokeDashoffset = 0;
        drawing = false;
        sfx('star');
        si++;
        if (si < strokes.length) startStroke();
        else { svg.onpointerdown = svg.onpointermove = svg.onpointerup = null; dot.remove(); num.remove(); svg.classList.add('done'); resolve(); }
      }
    }
    svg.onpointerdown = e => {
      const p = toSvg(e);
      if (dist(p, samples[pi]) < TOL * 1.7) { drawing = true; svg.setPointerCapture(e.pointerId); advance(p); }
      else { sfx('pop'); dot.classList.remove('hint'); void dot.getBBox(); dot.classList.add('hint'); }
    };
    svg.onpointermove = e => { if (drawing) advance(toSvg(e)); };
    svg.onpointerup = svg.onpointercancel = () => { drawing = false; };
    startStroke();
  });
}

export const levels = (island, content) => content.traceLevels.map(l => ({name: l.name}));

export async function run(g, island, content, li) {
  const lv = content.traceLevels[li];
  const by = Object.fromEntries(content.letters.map(l => [l.ch, l]));
  const voice = ch => /\d/.test(ch) ? tpl('writeNum', content.digits[Number(ch)]) : tpl('writeLetter', by[ch]);
  const done = ch => /\d/.test(ch) ? tpl('num', content.nums[Number(ch)]) : tpl('letterWord', by[ch]);
  preload(lv.chars.flatMap(ch => [voice(ch), done(ch)]));
  g.hideBuddy();
  await sayPhrase('traceIntro');
  for (let i = 0; i < lv.chars.length; i++) {
    if (g.aborted()) return null;
    g.progress(i, lv.chars.length);
    const ch = lv.chars[i];
    const p = traceChar(g.stage, ch);
    say(voice(ch));
    await p;
    if (g.aborted()) return null;
    sfx('correct');
    const L = by[ch];
    const card = h('div', {class: 'reward'}, h('div', {class: 'card'}, L ? img(L.img) : null, h('div', {class: 'big'}, ch), L ? h('div', {class: 'small'}, L.word) : null));
    g.stage.append(card);
    await Promise.all([say(done(ch)), wait(1200)]);
  }
  g.progress(lv.chars.length, lv.chars.length);
  return {stars: 3};
}
