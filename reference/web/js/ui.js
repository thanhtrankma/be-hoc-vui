// Tiện ích dựng giao diện.
export function h(tag, attrs = {}, ...kids) {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs || {})) {
    if (v == null || v === false) continue;
    if (k.startsWith('on')) el.addEventListener(k.slice(2), v);
    else if (k === 'style' && typeof v === 'object') for (const [sk, sv] of Object.entries(v)) sk.startsWith('--') ? el.style.setProperty(sk, sv) : (el.style[sk] = sv);
    else if (k === 'html') el.innerHTML = v;
    else el.setAttribute(k, v === true ? '' : v);
  }
  for (const c of kids.flat(Infinity)) if (c != null && c !== false) el.append(c instanceof Node ? c : String(c));
  return el;
}

export const slug = name => name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
export const src = name => `img/${slug(name)}.webp`;
// Ảnh chụp thật (photos.json) thay hình hoạt hình, chỉ bật trong màn học (setPhotoMode). photo:false để giữ hình hoạt hình.
let PHOTOS = {}, photoOn = false;
export const setPhotos = map => { PHOTOS = map || {}; };
export const setPhotoMode = on => { photoOn = on; };
export const photoOf = name => photoOn && PHOTOS[name] ? PHOTOS[name].f : null;
export const img = (name, attrs = {}) => {
  const {photo, ...rest} = attrs;
  const ph = photo !== false && photoOf(name);
  if (ph) rest.class = ((rest.class || '') + ' ph').trim();
  const el = h('img', {src: ph || src(name), alt: '', draggable: 'false', decoding: 'async', ...rest});
  // data-n: tên hình; data-pa: được phép đổi ảnh chụp (để unifyPhotos so cả nhóm).
  el.dataset.n = name;
  if (photo !== false && photoOn) el.dataset.pa = '1';
  // Ảnh chụp lỗi tải thì quay về hình hoạt hình.
  if (ph) el.addEventListener('error', () => toCartoon(el), {once: true});
  return el;
};
const toCartoon = el => { if (!el.classList.contains('ph')) return; el.classList.remove('ph'); el.src = src(el.dataset.n); };
// Màn học: mỗi khi stage đổi nội dung thì gom nhóm hình cho cùng kiểu, và ẩn hình tới khi tải xong (tối đa 4 giây,
// có vòng xoay chờ) để bé không thấy thẻ trống.
export function watchStage(stage) {
  // Đợt 19: trình duyệt trong Facebook (iPhone) tải ảnh chậm; trước đây hết 4 giây là mở màn luôn dù hình hoạt hình
  // thay thế chưa về, bé thấy thẻ trắng. Giờ: 4 giây đổi sang hoạt hình rồi vẫn chờ (tối đa thêm 6 giây), hình lỗi tải lại 1 lần.
  let timer = 0, hard = 0;
  const imgs = () => [...stage.querySelectorAll('img')];
  const done = () => { clearTimeout(timer); clearTimeout(hard); timer = hard = 0; stage.classList.remove('imgwait'); };
  const check = () => { if (imgs().every(im => im.complete)) done(); };
  const onErr = e => {
    const im = e.target;
    if (!im.classList.contains('ph') && !im.dataset.r) { im.dataset.r = '1'; im.src = src(im.dataset.n || '') + '?r=' + Date.now(); return; }
    check();
  };
  const track = () => {
    const waits = imgs().filter(im => !im.complete);
    if (!waits.length) return done();
    stage.classList.add('imgwait');
    for (const im of waits) {
      if (im.dataset.w) continue;
      im.dataset.w = '1';
      im.addEventListener('load', check); im.addEventListener('error', onErr);
    }
  };
  // Hết giờ chờ mà ảnh chụp chưa về (mạng chậm): đổi cả nhóm sang hoạt hình (nhẹ, thường đã lưu sẵn) thay vì để thẻ trống.
  const giveUp = () => {
    for (const im of stage.querySelectorAll('img.ph')) if (!im.complete) toCartoon(im);
    unifyPhotos(stage); track();
    if (!hard && stage.classList.contains('imgwait')) hard = setTimeout(done, 6000);
  };
  const mo = new MutationObserver(() => {
    unifyPhotos(stage);
    if (!imgs().some(im => !im.complete && !im.dataset.w)) return;
    track();
    clearTimeout(timer); clearTimeout(hard); hard = 0; timer = setTimeout(giveUp, 4000);
  });
  mo.observe(stage, {childList: true, subtree: true});
  return () => { mo.disconnect(); done(); };
}
// Một nhóm hình (các thẻ lựa chọn, hình trong một trang truyện...) phải cùng kiểu: nếu có hình chưa có ảnh chụp
// thì cả nhóm dùng hoạt hình, để không lộ đáp án và không lẫn ảnh với hoạt hình.
export function unifyPhotos(root) {
  const groups = new Map();
  for (const el of root.querySelectorAll('img[data-pa]')) {
    if (el.closest('.reward')) continue;
    const g = el.closest('.choices') || el.parentElement.closest('.choice')?.parentElement || el.parentElement;
    if (!groups.has(g)) groups.set(g, []);
    groups.get(g).push(el);
  }
  for (const els of groups.values()) {
    if (els.length > 1 && els.some(e => !e.classList.contains('ph')) && els.some(e => e.classList.contains('ph'))) els.forEach(toCartoon);
  }
}
// Tải trước hình (ảnh chụp hoặc hoạt hình) để thẻ không hiện trống; trả về Promise xong khi tải xong hoặc quá thời gian.
export function preloadImgs(names, timeout = 1500) {
  const ps = [...new Set(names)].filter(Boolean).map(n => new Promise(res => { const im = new Image(); im.onload = im.onerror = res; im.src = photoOf(n) || src(n); }));
  return Promise.race([Promise.all(ps), new Promise(res => setTimeout(res, timeout))]);
}

export const shuffle = a => { a = [...a]; for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; };
export const sample = (a, n) => shuffle(a).slice(0, n);
export const wait = ms => new Promise(r => setTimeout(r, ms));

export function confetti(n = 70) {
  const box = h('div', {class: 'confetti'});
  const colors = ['#ff8a5b', '#ffc93c', '#4fb3ff', '#3ccf91', '#b388ff', '#ff6fae'];
  for (let i = 0; i < n; i++) {
    box.append(h('i', {style: {
      left: Math.random() * 100 + '%', background: colors[i % colors.length],
      animationDuration: 1.8 + Math.random() * 1.6 + 's', animationDelay: Math.random() * .4 + 's',
      '--dx': (Math.random() * 200 - 100) + 'px', '--r': (Math.random() * 900 - 450) + 'deg'
    }}));
  }
  document.body.append(box);
  setTimeout(() => box.remove(), 4000);
}

export function toast(text) {
  const el = h('div', {class: 'toast'}, text);
  document.body.append(el);
  setTimeout(() => el.remove(), 2400);
}

export function overlay(...kids) {
  const el = h('div', {class: 'overlay'}, h('div', {class: 'panel'}, ...kids));
  document.body.append(el);
  return el;
}

export const isIOS = () => /iPad|iPhone|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
export const isStandalone = () => navigator.standalone === true || matchMedia('(display-mode: standalone)').matches;

// ---------- Biểu tượng nét tròn đồng bộ cho nút trên thanh (thay emoji ⬅️ ⚙️ 👥 ✕ mỗi máy một kiểu) ----------
const ICONS = {
  back: '<path d="M14.5 5.5 8 12l6.5 6.5"/>',
  close: '<path d="M6.5 6.5l11 11M17.5 6.5l-11 11"/>',
  // Bánh răng có răng cưa rõ (bản cũ là vòng tròn + tia, nhìn như nút sáng/tối)
  gear: '<path d="M19.2 10.4 L21.5 10.8 L21.5 13.2 L19.2 13.6 L18.2 16.0 L19.6 17.9 L17.9 19.6 L16.0 18.2 L13.6 19.2 L13.2 21.5 L10.8 21.5 L10.4 19.2 L8.0 18.2 L6.1 19.6 L4.4 17.9 L5.8 16.0 L4.8 13.6 L2.5 13.2 L2.5 10.8 L4.8 10.4 L5.8 8.0 L4.4 6.1 L6.1 4.4 L8.0 5.8 L10.4 4.8 L10.8 2.5 L13.2 2.5 L13.6 4.8 L16.0 5.8 L17.9 4.4 L19.6 6.1 L18.2 8.0Z" stroke-linejoin="round"/><circle cx="12" cy="12" r="3"/>',
  kids: '<circle cx="9" cy="8.5" r="3.2"/><path d="M3.5 19.5c.6-3.3 2.8-5 5.5-5s4.9 1.7 5.5 5"/><circle cx="16.8" cy="9.5" r="2.5"/><path d="M15.6 14.6c2.6-.3 4.4 1.3 4.9 4.4"/>'
};
export const icon = name => {
  const s = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  s.setAttribute('viewBox', '0 0 24 24'); s.setAttribute('class', 'ico ico-' + name); s.setAttribute('aria-hidden', 'true');
  s.innerHTML = ICONS[name];
  return s;
};
const EMOJI_ICON = {'⬅️': 'back', '✕': 'close', '⚙️': 'gear', '👥': 'kids'};
// Màn do khuôn trò chơi tự dựng (thú cưng, bố con thi tài...) vẫn dùng emoji: đổi sang biểu tượng chung khi nút được gắn vào trang.
export function iconize(root) {
  const fix = el => {
    for (const b of el.querySelectorAll ? el.querySelectorAll('button.icon-btn') : []) {
      const k = EMOJI_ICON[b.textContent.trim()];
      if (k && b.childElementCount === 0) { b.replaceChildren(icon(k)); if (!b.getAttribute('aria-label')) b.setAttribute('aria-label', k); }
    }
  };
  fix(root);
  new MutationObserver(ms => { for (const m of ms) for (const n of m.addedNodes) if (n.nodeType === 1) fix(n.parentNode || n); }).observe(root, {childList: true, subtree: true});
}

// Dấu thanh vẽ bằng SVG (sách lớp 1 dạy dấu là hình ` ´ ̉ ~ .), không phụ thuộc phông máy bé. ngang: gạch ngang.
const TONE_PATH = {
  'ngang': '<path d="M5 12h14"/>',
  'huyền': '<path d="M8 4l8 9"/>',
  'sắc': '<path d="M16 4l-8 9"/>',
  'hỏi': '<path d="M9.6 5.6Q9.6 3.2 12.2 3.2T14.8 5.6Q14.8 7.4 12.2 7.9V9.6"/>',
  'ngã': '<path d="M5 10Q8 5 12 9T19 8"/>',
  'nặng': '<circle cx="12" cy="18" r="2.4" fill="currentColor" stroke="none"/>'
};
export function toneMark(tone) {
  const el = h('span', {class: 'tmark', role: 'img', 'aria-label': tone});
  el.innerHTML = `<svg viewBox="0 0 24 22" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round">${TONE_PATH[tone] || ''}</svg>`;
  return el;
}
