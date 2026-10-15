// Đảo Tô màu: tranh chạm-để-tô (mỗi vùng là một hình SVG) và vẽ tự do có hình dán, lưu được ảnh.
import {h, img, src, toast} from '../ui.js?v=4c51d34a6e';
import {sayPhrase, sfx} from '../audio.js?v=4c51d34a6e';
import {t} from '../i18n.js?v=4c51d34a6e';

const PALETTE = ['#ff6b6b', '#ff922b', '#ffd43b', '#94d82d', '#51cf66', '#22b8cf', '#4dabf7', '#4c6ef5', '#9775fa', '#f783ac', '#a0522d', '#ffe8cc', '#868e96', '#212529', '#ffffff'];
const NS = 'http://www.w3.org/2000/svg';

// Tranh 400×300. Mỗi vùng: [thẻ SVG, thuộc tính]. Vùng sau đè lên vùng trước. 'line' chỉ là nét trang trí.
export const PAGES = {
  house: [
    ['rect', {x: 0, y: 0, width: 400, height: 220}], ['rect', {x: 0, y: 220, width: 400, height: 80}],
    ['circle', {cx: 340, cy: 58, r: 32}], ['ellipse', {cx: 90, cy: 50, rx: 44, ry: 18}], ['ellipse', {cx: 200, cy: 34, rx: 34, ry: 14}],
    ['rect', {x: 240, y: 66, width: 26, height: 50}], ['rect', {x: 110, y: 132, width: 180, height: 118}],
    ['polygon', {points: '92,138 200,56 308,138'}], ['rect', {x: 180, y: 182, width: 42, height: 68, rx: 4}],
    ['rect', {x: 128, y: 156, width: 36, height: 34}], ['rect', {x: 236, y: 156, width: 36, height: 34}],
    ['rect', {x: 44, y: 180, width: 16, height: 62}], ['circle', {cx: 52, cy: 160, r: 32}],
    ['circle', {cx: 330, cy: 252, r: 9}], ['circle', {cx: 356, cy: 262, r: 9}], ['circle', {cx: 310, cy: 266, r: 9}]
  ],
  fish: [
    ['rect', {x: 0, y: 0, width: 400, height: 256}], ['rect', {x: 0, y: 256, width: 400, height: 44}],
    ['polygon', {points: '40,300 52,214 66,300'}], ['polygon', {points: '350,300 362,200 378,300'}],
    ['polygon', {points: '282,150 352,94 352,206'}], ['polygon', {points: '150,94 200,52 232,98'}], ['polygon', {points: '170,204 210,240 226,200'}],
    ['ellipse', {cx: 190, cy: 150, rx: 108, ry: 64}], ['ellipse', {cx: 210, cy: 150, rx: 12, ry: 58}], ['ellipse', {cx: 250, cy: 150, rx: 10, ry: 46}],
    ['circle', {cx: 128, cy: 134, r: 16}], ['circle', {cx: 124, cy: 134, r: 7}],
    ['circle', {cx: 80, cy: 70, r: 10}], ['circle', {cx: 64, cy: 40, r: 7}], ['circle', {cx: 86, cy: 18, r: 5}]
  ],
  flower: [
    ['rect', {x: 0, y: 0, width: 400, height: 300}], ['circle', {cx: 60, cy: 60, r: 30}],
    ['rect', {x: 195, y: 120, width: 10, height: 100}],
    ['ellipse', {cx: 166, cy: 176, rx: 30, ry: 13, transform: 'rotate(-30 166 176)'}], ['ellipse', {cx: 234, cy: 190, rx: 30, ry: 13, transform: 'rotate(30 234 190)'}],
    ['rect', {x: 140, y: 214, width: 120, height: 20, rx: 4}], ['polygon', {points: '150,234 250,234 236,296 164,296'}],
    ...[0, 60, 120, 180, 240, 300].map(a => ['circle', {cx: 200 + 38 * Math.cos(a * Math.PI / 180), cy: 100 + 38 * Math.sin(a * Math.PI / 180), r: 27}]),
    ['circle', {cx: 200, cy: 100, r: 24}],
    ['ellipse', {cx: 330, cy: 80, rx: 22, ry: 14}], ['ellipse', {cx: 352, cy: 80, rx: 22, ry: 14}]
  ],
  car: [
    ['rect', {x: 0, y: 0, width: 400, height: 230}], ['rect', {x: 0, y: 230, width: 400, height: 70}],
    ['rect', {x: 0, y: 260, width: 70, height: 10}], ['rect', {x: 120, y: 260, width: 70, height: 10}], ['rect', {x: 240, y: 260, width: 70, height: 10}],
    ['circle', {cx: 70, cy: 60, r: 28}], ['polygon', {points: '118,152 158,96 262,96 304,152'}],
    ['rect', {x: 56, y: 148, width: 290, height: 70, rx: 22}],
    ['polygon', {points: '134,148 166,108 206,108 206,148'}], ['polygon', {points: '216,148 216,108 254,108 286,148'}],
    ['circle', {cx: 122, cy: 220, r: 30}], ['circle', {cx: 122, cy: 220, r: 12}], ['circle', {cx: 282, cy: 220, r: 30}], ['circle', {cx: 282, cy: 220, r: 12}],
    ['circle', {cx: 332, cy: 172, r: 10}], ['rect', {x: 60, y: 168, width: 18, height: 12, rx: 3}]
  ],
  rocket: [
    ['rect', {x: 0, y: 0, width: 400, height: 300}], ['circle', {cx: 70, cy: 230, r: 40}], ['ellipse', {cx: 70, cy: 230, rx: 62, ry: 12}],
    ['polygon', {points: '330,40 336,56 352,56 339,66 344,82 330,72 316,82 321,66 308,56 324,56'}],
    ['polygon', {points: '80,50 84,60 94,60 86,66 89,76 80,70 71,76 74,66 66,60 76,60'}],
    ['polygon', {points: '170,206 200,280 230,206'}],
    ['polygon', {points: '158,160 114,224 160,210'}], ['polygon', {points: '242,160 286,224 240,210'}],
    ['path', {d: 'M200,30 Q252,84 246,212 L154,212 Q148,84 200,30 Z'}],
    ['path', {d: 'M200,30 Q226,56 236,84 L164,84 Q174,56 200,30 Z'}],
    ['circle', {cx: 200, cy: 130, r: 24}], ['circle', {cx: 200, cy: 130, r: 15}]
  ],
  butterfly: [
    ['rect', {x: 0, y: 0, width: 400, height: 300}],
    ['ellipse', {cx: 140, cy: 108, rx: 66, ry: 50, transform: 'rotate(-25 140 108)'}], ['ellipse', {cx: 260, cy: 108, rx: 66, ry: 50, transform: 'rotate(25 260 108)'}],
    ['ellipse', {cx: 152, cy: 196, rx: 48, ry: 38, transform: 'rotate(20 152 196)'}], ['ellipse', {cx: 248, cy: 196, rx: 48, ry: 38, transform: 'rotate(-20 248 196)'}],
    ['circle', {cx: 128, cy: 104, r: 18}], ['circle', {cx: 272, cy: 104, r: 18}], ['circle', {cx: 150, cy: 200, r: 13}], ['circle', {cx: 250, cy: 200, r: 13}],
    ['ellipse', {cx: 200, cy: 158, rx: 12, ry: 74}], ['circle', {cx: 200, cy: 76, r: 16}],
    ['line', {x1: 194, y1: 64, x2: 170, y2: 26}], ['line', {x1: 206, y1: 64, x2: 230, y2: 26}],
    ['circle', {cx: 168, cy: 24, r: 6}], ['circle', {cx: 232, cy: 24, r: 6}]
  ]
};

// Màu sẵn cho từng tranh (theo thứ tự vùng, bỏ qua nét 'line') – dùng cho ghép tranh và tìm điểm khác.
export const PRESET = {
  house: ['#bfe9ff', '#8ce99a', '#ffd43b', '#ffffff', '#ffffff', '#a0522d', '#ffe8cc', '#ff6b6b', '#a0522d', '#74c0fc', '#74c0fc', '#8d5524', '#51cf66', '#f783ac', '#ffd43b', '#9775fa'],
  fish: ['#a5d8ff', '#ffe066', '#51cf66', '#40c057', '#ff922b', '#ff922b', '#ff922b', '#ffa94d', '#ffffff', '#ffffff', '#ffffff', '#212529', '#e7f5ff', '#e7f5ff', '#e7f5ff'],
  flower: ['#e3fafc', '#ffd43b', '#40c057', '#51cf66', '#51cf66', '#d9480f', '#e8590c', '#f783ac', '#f783ac', '#f783ac', '#f783ac', '#f783ac', '#f783ac', '#ffd43b', '#9775fa', '#b197fc'],
  car: ['#d0ebff', '#868e96', '#ffffff', '#ffffff', '#ffffff', '#ffd43b', '#e03131', '#fa5252', '#a5d8ff', '#a5d8ff', '#343a40', '#adb5bd', '#343a40', '#adb5bd', '#ffec99', '#c92a2a'],
  rocket: ['#1c2a4a', '#9775fa', '#e599f7', '#ffd43b', '#ffd43b', '#ff922b', '#e03131', '#e03131', '#f1f3f5', '#e03131', '#4dabf7', '#a5d8ff'],
  butterfly: ['#ebfbee', '#ff922b', '#ff922b', '#ffd43b', '#ffd43b', '#ffffff', '#ffffff', '#ffffff', '#ffffff', '#495057', '#495057', '#495057', '#495057']
};

// Dựng tranh đã tô màu. viewBox tuỳ chọn để cắt một mảnh (ghép tranh). Trả về {svg, regions}.
export function pageSvg(page, colors = PRESET[page], viewBox = '0 0 400 300') {
  const svg = document.createElementNS(NS, 'svg');
  svg.setAttribute('viewBox', viewBox);
  svg.setAttribute('preserveAspectRatio', 'none');
  svg.setAttribute('class', 'cpage done');
  const regions = [];
  let k = 0;
  for (const [tag, attrs] of PAGES[page]) {
    const el = document.createElementNS(NS, tag);
    for (const a in attrs) el.setAttribute(a, attrs[a]);
    if (tag === 'line') { el.setAttribute('class', 'deco'); svg.append(el); continue; }
    el.setAttribute('fill', colors[k++] || '#fff');
    el.setAttribute('class', 'region');
    regions.push(el); svg.append(el);
  }
  return {svg, regions};
}

function colorPage(g, lv) {
  let color = PALETTE[0];
  const svg = document.createElementNS(NS, 'svg');
  svg.setAttribute('viewBox', '0 0 400 300');
  svg.setAttribute('class', 'cpage');
  const regions = [];
  for (const [tag, attrs] of PAGES[lv.page]) {
    const el = document.createElementNS(NS, tag);
    for (const k in attrs) el.setAttribute(k, attrs[k]);
    if (tag === 'line') { el.setAttribute('class', 'deco'); svg.append(el); continue; }
    el.setAttribute('fill', '#ffffff');
    el.setAttribute('class', 'region');
    el.addEventListener('pointerdown', e => {
      e.preventDefault();
      el.setAttribute('fill', color);
      el.dataset.done = '1';
      sfx('pop');
    });
    regions.push(el); svg.append(el);
  }
  const pal = palette(c => { color = c; });
  const doneBtn = h('button', {class: 'btn green'}, '✔ ', t('done'));
  const saveBtn = h('button', {class: 'btn ghost', onclick: () => saveSvg(svg)}, '💾 ', t('save'));
  g.stage.replaceChildren(h('div', {class: 'art'}, h('div', {class: 'canvas-box'}, svg), pal, h('div', {class: 'row'}, saveBtn, doneBtn)));
  g.progress(0, 1);
  sayPhrase('artIntro');
  return new Promise(resolve => {
    doneBtn.onclick = () => {
      const filled = regions.filter(r => r.dataset.done).length;
      if (filled < Math.ceil(regions.length * .5)) { sfx('wrong'); sayPhrase('colorMore'); return; }
      g.progress(1, 1);
      sayPhrase('artDone');
      resolve({stars: 3});
    };
  });
}

function palette(onPick, extra = []) {
  const el = h('div', {class: 'palette'});
  const sel = b => { el.querySelectorAll('.on').forEach(x => x.classList.remove('on')); b.classList.add('on'); };
  PALETTE.forEach((c, i) => {
    const b = h('button', {class: `sw ${i === 0 ? 'on' : ''}`, style: {background: c}, onclick: () => { sel(b); onPick(c); sfx('tap'); }});
    el.append(b);
  });
  extra.forEach(([label, fn]) => {
    const b = h('button', {class: 'sw tool', onclick: () => { sel(b); fn(); sfx('tap'); }}, label);
    el.append(b);
  });
  return el;
}

function download(blob, name) {
  const a = h('a', {href: URL.createObjectURL(blob), download: name});
  document.body.append(a); a.click(); a.remove();
  toast(t('saved'));
}

function saveSvg(svg) {
  const data = new XMLSerializer().serializeToString(svg).replace('<svg', `<svg xmlns="${NS}" width="1200" height="900"`);
  const im = new Image();
  im.onload = () => {
    const c = document.createElement('canvas');
    c.width = 1200; c.height = 900;
    const x = c.getContext('2d');
    x.fillStyle = '#fff'; x.fillRect(0, 0, 1200, 900); x.drawImage(im, 0, 0, 1200, 900);
    c.toBlob(b => download(b, 'be-vui-hoc-tranh.png'));
  };
  im.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(data.replace(/class="region"/g, 'stroke="#2b2d42" stroke-width="3"').replace(/class="deco"/g, 'stroke="#2b2d42" stroke-width="3"'));
}

// ---------- Vẽ tự do ----------
const STAMPS = ['Star', 'Glowing star', 'Rainbow', 'Butterfly', 'Hibiscus', 'Sun with face', 'Cat', 'Dog', 'Rocket', 'Racing car', 'Balloon', 'Soft ice cream'];

function draw(g) {
  const box = h('div', {class: 'canvas-box draw'});
  const cv = h('canvas', {class: 'drawc'});
  box.append(cv);
  let color = PALETTE[0], size = 10, mode = 'pen', stamp = null, hue = 0, strokes = 0;
  const undo = [];
  const stampImgs = {};
  STAMPS.forEach(s => { const im = new Image(); im.src = src(s); stampImgs[s] = im; });
  const pal = palette(c => { color = c; mode = 'pen'; }, [
    ['🌈', () => { mode = 'rainbow'; }],
    ['🧽', () => { mode = 'eraser'; }]
  ]);
  const sizes = h('div', {class: 'sizes'}, [6, 12, 24].map((s, i) => {
    const b = h('button', {class: `size ${i === 1 ? 'on' : ''}`, onclick: () => { sizes.querySelectorAll('.on').forEach(x => x.classList.remove('on')); b.classList.add('on'); size = s; sfx('tap'); }},
      h('i', {style: {width: s + 'px', height: s + 'px'}}));
    return b;
  }));
  const tray = h('div', {class: 'stamps'}, STAMPS.map(s => {
    const b = h('button', {class: 'stamp', onclick: () => {
      tray.querySelectorAll('.on').forEach(x => x.classList.remove('on'));
      if (mode === 'stamp' && stamp === s) { mode = 'pen'; stamp = null; return; }
      b.classList.add('on'); mode = 'stamp'; stamp = s; sfx('tap');
    }}, img(s));
    return b;
  }));
  const doneBtn = h('button', {class: 'btn green', disabled: true}, '✔ ', t('done'));
  const tools = h('div', {class: 'row'},
    h('button', {class: 'btn ghost', onclick: () => { const u = undo.pop(); if (u) ctx.putImageData(u, 0, 0); sfx('pop'); }}, '↩️'),
    h('button', {class: 'btn ghost', onclick: () => { snap(); clear(); sfx('pop'); }}, '🗑️'),
    h('button', {class: 'btn ghost', onclick: () => cv.toBlob(b => download(b, 'be-vui-hoc-ve.png'))}, '💾 ', t('save')),
    doneBtn);
  g.stage.replaceChildren(h('div', {class: 'art'}, box, h('div', {class: 'art-tools'}, pal, sizes), tray, tools));
  g.progress(0, 1);
  sayPhrase('drawQ');

  const dpr = Math.min(2, window.devicePixelRatio || 1);
  const r = box.getBoundingClientRect();
  cv.width = Math.round(r.width * dpr); cv.height = Math.round(r.height * dpr);
  const ctx = cv.getContext('2d');
  ctx.scale(dpr, dpr);
  ctx.lineCap = ctx.lineJoin = 'round';
  const clear = () => { ctx.fillStyle = '#fff'; ctx.fillRect(0, 0, cv.width, cv.height); };
  clear();
  const snap = () => { undo.push(ctx.getImageData(0, 0, cv.width, cv.height)); if (undo.length > 15) undo.shift(); };
  const pos = e => { const b = cv.getBoundingClientRect(); return [e.clientX - b.left, e.clientY - b.top]; };
  let last = null;
  cv.addEventListener('pointerdown', e => {
    e.preventDefault();
    snap();
    const [x, y] = pos(e);
    if (mode === 'stamp') {
      const s = 70 + size * 2;
      ctx.drawImage(stampImgs[stamp], x - s / 2, y - s / 2, s, s);
      sfx('pop'); strokes++;
    } else { last = [x, y]; cv.setPointerCapture(e.pointerId); line(x, y, x + .1, y + .1); }
    if (strokes >= 3) doneBtn.disabled = false;
  });
  cv.addEventListener('pointermove', e => {
    if (!last) return;
    const [x, y] = pos(e);
    line(last[0], last[1], x, y);
    last = [x, y];
  });
  const end = () => { if (last) { strokes++; if (strokes >= 3) doneBtn.disabled = false; } last = null; };
  cv.addEventListener('pointerup', end);
  cv.addEventListener('pointercancel', end);
  function line(x1, y1, x2, y2) {
    ctx.beginPath();
    ctx.lineWidth = mode === 'eraser' ? size * 2.5 : size;
    if (mode === 'rainbow') { hue = (hue + 6) % 360; ctx.strokeStyle = `hsl(${hue} 90% 55%)`; }
    else ctx.strokeStyle = mode === 'eraser' ? '#fff' : color;
    ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();
  }
  return new Promise(resolve => {
    doneBtn.onclick = () => { g.progress(1, 1); sayPhrase('artDone'); resolve({stars: 3}); };
  });
}

export const levels = (island, content) => content.artLevels.map(l => ({name: l.name, img: l.img}));

export function run(g, island, content, li) {
  const lv = content.artLevels[li];
  g.hideBuddy();
  return lv.kind === 'draw' ? draw(g) : colorPage(g, lv);
}
