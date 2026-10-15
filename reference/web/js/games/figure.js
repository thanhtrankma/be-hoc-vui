// Nhân vật trong Khu vui chơi + Thế giới phiêu lưu: SPRITE THẬT có khung hoạt ảnh (đợt 15), thay người que vẽ canvas của đợt 14.
// Hình: Kenney Toon Characters (CC0) cho người/robot, Cat & Dog của pzUH (CC0, OpenGameArt) cho thú đồng đội.
// Sheet do tools/sprites.py tạo ở src/sprites/toon/*.webp|json và src/sprites/pets/*; đọc bằng sheets.js.
//
// ===== API (giữ chữ ký cũ, game không phải sửa) =====
// preloadFigures() -> Promise: nạp mọi sheet + hình mũ. Tự chạy khi import và tự thêm vào funcore.preloads,
//   nên `await loadAll([...])` của game đã chờ sẵn. Vẽ khi chưa nạp xong thì bỏ qua (không lỗi).
// drawFigure(ctx, x, y, h, o): (x, y) = điểm giữa hai bàn chân, h = chiều cao nhân vật (chân tới đỉnh đầu, không tính mũ).
//   o = {c: trang phục, pose, t (giây), act (0..1 tiến độ đòn), face (1 phải / -1 trái), alpha, weapon (tên hình Fluent),
//        team (màu vòng dưới chân), noHead (chỉ vẽ phần dưới cổ, để game vẽ đầu to riêng bằng drawHead), shadow:false}
//   pose: idle | run | walk | sprint | jump | fall | punch | kick | flykick | swing | throw | block | hurt | sit | pull | cheer | talk | interact | show
// drawHead(ctx, x, y, r, c, {face, hurt, t}): chân dung (đầu + cổ áo) tâm (x, y), bán kính r (dùng cho HUD, bóng, ô cờ...).
// figureEl(c, {size, pose, cls}) -> <canvas> tự chạy hoạt ảnh; el.pose, el.face, el.weapon, el.run(giây).
// petBuddy(kind) -> {update(dt, moving), draw(ctx, x, y, size, face)}: thú đồng đội (dog | cat | fox), size như petrig (u = dài thân).
// petEl(kind, {size, cls}) -> <canvas> thú đứng thở.
// figureSize(h) -> {w, head}: bề ngang và cỡ đầu xấp xỉ của nhân vật cao h (để game tính va chạm/HUD nếu cần).
//
// ===== Trang phục (c) =====
// {base: 'boy' | 'girl' | 'kid' | 'dad' | 'robot', shirt, pants, hair: '#rrggbb' (đổi màu thật trên sprite), hat: tên hình Fluent đội trên đầu}
// COSTUMES theo tên hình linh vật; costumeOf(img). BOT = robot đỏ (máy), DAD = bố/mẹ, FRIENDS = 4 bạn đồng đội.
// Game cũ còn truyền {...c, shirt: '#hex'} hay hat: 'racing' vẫn chạy (shirt đổi màu áo, hat cũ được ánh xạ sang hình mũ).
import {draw, preloads, loadAll} from './funcore.js?v=4c51d34a6e';
import {loadSheet, drawFrame, frameAt} from './sheets.js?v=4c51d34a6e';

export const COSTUMES = {
  'Man superhero': {base: 'boy', shirt: '#1c7ed6', pants: '#e03131'},
  'Woman superhero': {base: 'girl', shirt: '#e64980'},
  'Robot': {base: 'robot'},
  'Racing car': {base: 'boy', shirt: '#fa5252', pants: '#343a40', hat: 'Billed cap'},
  'T-rex': {base: 'boy', shirt: '#40c057'},
  'Astronaut': {base: 'kid', shirt: '#f1f3f5', pants: '#ced4da'},
  'Princess': {base: 'girl', shirt: '#f783ac', hair: '#fab005', hat: 'Crown'},
  'Unicorn': {base: 'kid', shirt: '#b197fc', hair: '#f783ac'},
  'Cat face': {base: 'boy', shirt: '#ff922b', pants: '#5c3d2e'},
  'Rabbit face': {base: 'girl', shirt: '#f1f3f5'},
  'Dog face': {base: 'boy', shirt: '#c08a52', pants: '#5c3d2e'},
  'Panda': {base: 'kid', shirt: '#f8f9fa', pants: '#343a40'},
  'Fire engine': {base: 'boy', shirt: '#e03131', pants: '#343a40', hat: 'Rescue workers helmet'},
  'Woman fairy': {base: 'girl', shirt: '#63e6be', hair: '#ffd43b'},
  'Rocket': {base: 'boy', shirt: '#e9ecef', pants: '#868e96'},
  'Police car': {base: 'boy', shirt: '#1864ab', pants: '#212529', hat: 'Billed cap'},
  'Sauropod': {base: 'kid', shirt: '#4dabf7'},
  'Locomotive': {base: 'boy', shirt: '#495057', pants: '#343a40', hat: 'Top hat'},
  'Ninja': {base: 'boy', shirt: '#343a40', pants: '#212529', hair: '#212529'},
  'Bear': {base: 'boy', shirt: '#a0522d', pants: '#5c3d2e'},
  'Dragon': {base: 'kid', shirt: '#e03131'},
  'Lion': {base: 'girl', shirt: '#fab005', hair: '#e8590c'}
};
const DEFAULT = {base: 'boy', shirt: '#339af0'};
export const costumeOf = img => ({...DEFAULT, ...(COSTUMES[img] || {})});
// Nhân vật của bé (2026-10-12, mở công khai): bé tự chọn bé trai / bé gái, màu áo, mũ ở Khu vui chơi (p.look).
// Chỉ thay nhân vật CỦA BÉ: game gọi heroOf(opts.hero); NPC vẫn dùng costumeOf (vd. Công chúa trong làng RPG).
export const LOOK_SHIRTS = ['#1c7ed6', '#e03131', '#2f9e44', '#f08c00', '#ae3ec9', '#e64980', '#15aabf', '#343a40'];
export const LOOK_HATS = [null, 'Billed cap', 'Crown', 'Rescue workers helmet', 'Top hat'];
let PLAYER = null;  // {img, look}
export function setPlayer(img, look) { PLAYER = look && (look.base === 'boy' || look.base === 'girl') ? {img, look, c: lookOf(look)} : null; }
export function lookOf(look) {
  return {base: look.base, shirt: look.shirt || (look.base === 'girl' ? '#e64980' : '#1c7ed6'),
    hair: look.hair || undefined, pants: look.base === 'boy' ? (look.pants || '#343a40') : undefined, hat: look.hat || undefined};
}
// Trả về cùng một đối tượng mỗi khung (look() nhớ ảnh đã đổi màu trên đối tượng); game sửa thêm (cape) thì sửa trên bản sao.
export const heroOf = img => (PLAYER && (img == null || img === PLAYER.img) ? {...PLAYER.c} : costumeOf(img));
export const BOT = {base: 'robot', shirt: '#fa5252'};
export const DAD = {base: 'dad'};
export const FRIENDS = [{base: 'kid', shirt: '#40c057'}, {base: 'girl', shirt: '#fab005'}, {base: 'boy', shirt: '#7950f2'}, {base: 'kid', shirt: '#15aabf', hair: '#8d5524'}];
// Mũ kiểu cũ (đợt 14) -> hình Fluent
const OLD_HATS = {racing: 'Billed cap', police: 'Billed cap', fire: 'Rescue workers helmet', conductor: 'Top hat', crown: 'Crown', space: null, ears: null, dino: null, mane: null, horn: null, ninja: null, antenna: null};
const HATS = ['Crown', 'Billed cap', 'Rescue workers helmet', 'Top hat'];
const BASES = ['boy', 'girl', 'kid', 'dad', 'robot'];
const PET_SHEET = {dog: 'dog', fox: 'dog', cat: 'cat', rabbit: 'cat', hamster: 'dog', panda: 'cat'};
const PET_TINT = {dog: {fur: '#b7793f'}, hamster: {fur: '#e3b26b'}};

// ---------- Nạp ----------
const S = {};  // tên sheet -> sheet đã nạp
let ready = null;
const decode = im => (im.decode ? im.decode() : Promise.resolve()).catch(() => {});  // giải nén trước để khung đầu không giật
export function preloadFigures() {
  if (!ready) {
    ready = Promise.all([
      ...BASES.map(b => loadSheet('toon/' + b).then(s => { S[b] = s; return Promise.all([loadShades(s), decode(s.img)]); })),
      ...['dog', 'cat'].map(p => loadSheet('pets/' + p).then(s => { S['pet:' + p] = s; return Promise.all([loadShades(s), decode(s.img)]); })),
      loadAll(HATS)
    ]).catch(e => console.warn('figure sprites', e));
  }
  return ready;
}
preloads.add(preloadFigures());

// ---------- Đổi màu áo/tóc/quần ngay trên sprite (một lần cho mỗi bộ màu, lưu canvas) ----------
// Ảnh bóng của từng nhóm màu (tools/sprites.py xuất <tên>.<nhóm>.webp: xám = độ sáng/độ sáng màu chuẩn, chỉ có ở điểm thuộc nhóm).
// Đổi màu = nhân màu đích lên ảnh bóng rồi phủ lên sheet, toàn bằng drawImage/fillRect (GPU), không đọc điểm ảnh.
const shades = {}, variants = {};
function loadShades(sheet) {
  return Promise.all(Object.keys(sheet.tint || {}).map(g => new Promise(r => {
    const im = new Image(); im.onload = () => { shades[sheet.name + '.' + g] = im; decode(im).then(r); }; im.onerror = r;
    im.src = new URL(`../../sprites/${sheet.name}.${g}.webp`, import.meta.url).href;
  })));
}
let tmp = null;
function variant(sheet, key, colors) {
  // colors: {nhóm: '#hex'}; trả về ảnh gốc nếu không đổi gì
  const groups = Object.keys(colors).filter(g => colors[g] && sheet.tint?.[g] && shades[sheet.name + '.' + g]);
  if (!groups.length || !sheet.img.naturalWidth) return sheet.img;
  const id = sheet.name + '|' + groups.map(g => g + colors[g]).join('|');
  if (variants[id]) return variants[id];
  const w = sheet.img.naturalWidth, h = sheet.img.naturalHeight;
  const cv = document.createElement('canvas'); cv.width = w; cv.height = h;
  const cx = cv.getContext('2d');
  cx.drawImage(sheet.img, 0, 0);
  if (!tmp) tmp = document.createElement('canvas');
  if (tmp.width < w || tmp.height < h) { tmp.width = Math.max(tmp.width, w); tmp.height = Math.max(tmp.height, h); }
  const tx = tmp.getContext('2d');
  for (const g of groups) {
    const sh = shades[sheet.name + '.' + g];
    tx.globalCompositeOperation = 'source-over'; tx.clearRect(0, 0, w, h); tx.drawImage(sh, 0, 0);
    tx.globalCompositeOperation = 'multiply'; tx.fillStyle = colors[g]; tx.fillRect(0, 0, w, h);
    tx.globalCompositeOperation = 'destination-in'; tx.drawImage(sh, 0, 0);
    cx.drawImage(tmp, 0, 0, w, h, 0, 0, w, h);
  }
  tx.globalCompositeOperation = 'source-over';
  return (variants[id] = cv);
}

function baseOf(c) { return c.base && BASES.includes(c.base) ? c.base : c.robot ? 'robot' : c.long || c.dress ? 'girl' : 'boy'; }
function look(c) {
  c = c || DEFAULT;
  if (c._fig && c._fig.shirt === c.shirt && c._fig.hair === c.hair && c._fig.pants === c.pants && c._fig.hat === c.hat) return c._fig;
  const b = baseOf(c), sh = S[b];
  if (!sh) return null;
  const hat = c.hat in OLD_HATS ? OLD_HATS[c.hat] : HATS.includes(c.hat) ? c.hat : null;
  // robot bố/mẹ không đổi màu; áo của dad giữ nguyên trừ khi game đổi
  const L = {shirt: c.shirt, hair: c.hair, pants: c.pants, hat: c.hat, sheet: sh, hatImg: hat,
    img: variant(sh, b, {shirt: b === 'robot' && c.shirt === undefined ? null : c.shirt, hair: c.hair, pants: c.pants})};
  try { Object.defineProperty(c, '_fig', {value: L, configurable: true, writable: true, enumerable: false}); } catch (e) { /* đối tượng đóng băng */ }
  return L;
}

// ---------- Chọn khung theo tư thế ----------
const sin = Math.sin;
function frameFor(sh, pose, t, act) {
  const a = Math.min(1, Math.max(0, act || 0));
  switch (pose) {
    case 'idle': return ['idle', 0, 0];
    case 'run': return [frameAt(sh, 'walk', t * 1.25), 0, 0];
    case 'walk': return [frameAt(sh, 'walk', t), 0, 0];
    case 'sprint': return [frameAt(sh, 'run', t), 0, 0];
    case 'jump': return ['jump', 0, 0];
    case 'fall': return ['fall', 0, 0];
    case 'punch': return [a < .2 ? 'hold' : 'attack0', a < .2 ? 0 : sin(a * Math.PI) * .06, 0];
    case 'kick': return [a < .15 ? 'hold' : 'kick', 0, 0];
    case 'flykick': return ['attackKick', 0, 0];
    case 'swing': return [a < .4 ? 'attack1' : 'attack2', a < .4 ? 0 : .04, 0];
    case 'throw': return [a < .45 ? 'attack1' : 'attack0', 0, 0];
    case 'block': return ['hold', -.02, -.05];
    case 'hurt': return ['hit', -.03, -.12];
    case 'sit': return ['duck', 0, 0];
    case 'pull': return ['drag', -.02 + sin(t * 9) * .015, -.08 + sin(t * 9) * .03];
    case 'cheer': return [frameAt(sh, 'cheer', t), 0, 0];
    case 'talk': return [frameAt(sh, 'talk', t), 0, 0];
    default: return [sh.frames[pose] ? pose : sh.anims?.[pose] ? frameAt(sh, pose, t) : 'idle', 0, 0];
  }
}

export const figureSize = h => ({w: h * .78, head: h * .55});

export function drawFigure(ctx, x, y, h, o = {}) {
  const L = look(o.c);
  if (!L) return;
  const sh = L.sheet, face = o.face || 1, t = o.t || 0, pose = o.pose || 'idle';
  const FH = h / (1 - sh.top), k = FH / sh.size[1];
  const [fr, dx, rot] = frameFor(sh, pose, t, o.act);
  const bob = pose === 'idle' ? 1 + sin(t * 2.6) * .012 : pose === 'cheer' ? 1 + Math.abs(sin(t * 8)) * .03 : 1;
  const lift = pose === 'cheer' ? Math.abs(sin(t * 8)) * h * .04 : 0;
  ctx.save();
  if (o.alpha != null) ctx.globalAlpha *= o.alpha;
  if (o.shadow !== false && pose !== 'sit' && pose !== 'jump' && pose !== 'fall' && pose !== 'flykick') {  // đang bay thì game tự vẽ bóng dưới đất
    ctx.fillStyle = o.team ? o.team + '88' : 'rgba(0,0,0,.18)';
    ctx.beginPath(); ctx.ellipse(x, y, h * .3, h * .065, 0, 0, 7); ctx.fill();
  }
  const X = x + dx * h * face, Y = y - lift;
  if (o.noHead) {
    const hb = sh.head[fr]; const cut = Y - (sh.size[1] - (hb[1] + hb[3] * .3)) * k;
    ctx.beginPath(); ctx.rect(x - h * 2, cut, h * 4, h * 2); ctx.clip();
  }
  drawFrame(ctx, sh, fr, X, Y, FH, {flip: face < 0, rot: rot * face, img: L.img, sy: bob});
  // toạ độ khung logic -> màn hình (có xoay quanh chân)
  const P = (px, py) => {
    const lx = (px - sh.size[0] * sh.anchor[0]) * k * face, ly = (py - sh.size[1] * sh.anchor[1]) * k * bob;
    const cr = Math.cos(rot * face), sr = sin(rot * face);
    return [X + lx * cr - ly * sr, Y + lx * sr + ly * cr];
  };
  if (L.hatImg && !o.noHead) drawHat(ctx, L, sh, fr, P, k, face, rot);
  if (o.weapon) {
    const [hx, hy, ang = 0] = sh.hand[fr] || sh.hand.idle, [wx, wy] = P(hx, hy), ws = h * .46, A = (ang + rot) * face;
    draw(ctx, o.weapon, wx + sin(A) * ws * .28, wy - Math.cos(A) * ws * .28, ws, ws, {rot: A, flip: face < 0});
  }
  ctx.restore();
}

function drawHat(ctx, L, sh, fr, P, k, face, rot) {
  const [cx, cy, hw, hh] = sh.head[fr] || sh.head.idle, w = hw * k * (L.hatImg === 'Crown' ? .62 : .95);
  const [hx, hy] = P(cx + 4, cy - hh * (L.hatImg === 'Crown' ? .64 : .36));
  draw(ctx, L.hatImg, hx, hy, w, w, {rot: rot * face, flip: face < 0});
}

// ---------- Chân dung ----------
export function drawHead(ctx, x, y, r, c, {face = 1, hurt = false, t = 0} = {}) {
  const L = look(c);
  if (!L) return;
  const sh = L.sheet, fr = hurt ? 'hit' : (t % 4.2) > 3.9 ? 'talk' : 'idle', f = sh.frames[fr], hb = sh.head[fr];
  if (!f || !hb) return;
  const [sx, sy, sw, shh, ox, oy] = f;
  // hộp đầu, lấy rộng hơn chút để có cổ áo, cắt trong phạm vi khung đã cắt
  let bx0 = hb[0] - hb[2] * .55, bx1 = hb[0] + hb[2] * .55, by0 = hb[1] - hb[3] * .55, by1 = hb[1] + hb[3] * .62;
  bx0 = Math.max(bx0, ox); by0 = Math.max(by0, oy); bx1 = Math.min(bx1, ox + sw); by1 = Math.min(by1, oy + shh);
  const k = r * 2.1 / hb[2];
  ctx.save();
  ctx.translate(x, y); if (face < 0) ctx.scale(-1, 1);
  ctx.drawImage(L.img, sx + bx0 - ox, sy + by0 - oy, bx1 - bx0, by1 - by0, (bx0 - hb[0]) * k, (by0 - hb[1]) * k, (bx1 - bx0) * k, (by1 - by0) * k);
  ctx.restore();
  if (L.hatImg) {
    const w = hb[2] * k * (L.hatImg === 'Crown' ? .62 : .95);
    draw(ctx, L.hatImg, x + 4 * k * face, y - hb[3] * k * (L.hatImg === 'Crown' ? .64 : .36), w, w, {flip: face < 0});
  }
}

// ---------- Thú đồng đội ----------
export function petBuddy(kind) {
  let t = Math.random() * 2, mv = 0;
  const sk = PET_SHEET[kind] || 'dog';
  return {
    update(dt, moving) { t += dt; mv += ((moving ? 1 : 0) - mv) * Math.min(1, dt * 8); },
    draw(ctx, x, y, size, face = 1) {
      const sh = S['pet:' + sk];
      if (!sh) return;
      const img = PET_TINT[kind] ? variant(sh, sk, PET_TINT[kind]) : sh.img;
      const H = size * 1.8 / (sh.anchor[1] - sh.top);  // cao ~1.8 lần size (u của petrig)
      ctx.fillStyle = 'rgba(0,0,0,.15)'; ctx.beginPath(); ctx.ellipse(x, y, size * .55, size * .13, 0, 0, 7); ctx.fill();
      drawFrame(ctx, sh, frameAt(sh, mv > .5 ? 'walk' : 'idle', t), x, y, H, {flip: face < 0, img});
    }
  };
}

// ---------- Phần tử DOM ----------
function loopCanvas(size, paint) {
  const cv = document.createElement('canvas'), dpr = Math.min(2, window.devicePixelRatio || 1);
  cv.width = cv.height = Math.round(size * dpr); cv.style.aspectRatio = '1';
  const ctx = cv.getContext('2d');
  let last = performance.now(), started = false;
  const frame = now => {
    if (started && !cv.isConnected) return;
    if (cv.isConnected) started = true;
    const dt = Math.min(.05, (now - last) / 1000); last = now;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0); ctx.clearRect(0, 0, size, size);
    paint(ctx, dt);
    requestAnimationFrame(frame);
  };
  requestAnimationFrame(frame);
  return cv;
}

// Nhân vật trong giao diện DOM (thẻ làng, ô lập trình robot). el.pose, el.face đổi được; el.run(giây) chạy rồi về đứng; el.weapon.
export function figureEl(c, {size = 160, pose = 'idle', cls = ''} = {}) {
  let t = Math.random() * 3;
  const cv = loopCanvas(size, (ctx, dt) => {
    t += dt; cv.runT = Math.max(0, cv.runT - dt);
    drawFigure(ctx, size / 2, size * .97, size * .8, {c, pose: cv.runT > 0 ? 'run' : cv.pose, t, face: cv.face, weapon: cv.weapon});
  });
  cv.className = cls;
  return Object.assign(cv, {pose, face: 1, weapon: null, runT: 0, run(s) { this.runT = s; }});
}

// Thú cưng trong giao diện DOM (chọn đồng đội, thẻ làng)
export function petEl(kind, {size = 120, cls = ''} = {}) {
  const rig = petBuddy(kind);
  const cv = loopCanvas(size, (ctx, dt) => { rig.update(dt, false); rig.draw(ctx, size / 2, size * .95, size * .44); });
  cv.className = cls;
  return cv;
}
