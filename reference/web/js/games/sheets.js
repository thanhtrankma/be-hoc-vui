// Sprite sheet có khung hoạt ảnh (nhân vật, xe, con vật từ gói CC0 trong src/sprites/).
// Mỗi gói: src/sprites/<gói>/<tên>.webp + <tên>.json dạng
//   {"frames": {"walk0": [x, y, w, h], ...}, "anims": {"walk": {"frames": ["walk0", "walk1"], "fps": 10, "loop": true}}, "anchor": [0.5, 1]}
// anchor: điểm gốc (0.5,1 = giữa chân). Dùng:
//   const s = await loadSheet('toon/boy');  drawAnim(ctx, s, 'walk', t, x, y, h, {flip});
// Mở rộng (tools/sprites.py xuất): khung đã cắt bớt viền trống ghi [x, y, w, h, ox, oy] kèm "size": [W, H] là khung logic;
// khi có size thì h trong drawFrame là chiều cao khung logic và anchor tính trên khung logic (mọi khung thẳng hàng chân).
// opts.img: vẽ từ ảnh/canvas khác cùng bố cục (bản đổi màu áo của figure.js).
const cache = {};
const base = new URL('../../sprites/', import.meta.url);

export function loadSheet(name) {
  if (!cache[name]) {
    cache[name] = (async () => {
      const meta = await (await fetch(new URL(`${name}.json`, base))).json();
      const img = new Image();
      img.decoding = 'async';
      img.src = new URL(`${name}.webp`, base).href;
      await new Promise(r => { img.onload = r; img.onerror = r; });
      return {name, img, ...meta, anchor: meta.anchor || [0.5, 1]};
    })();
  }
  return cache[name];
}

export const loadSheets = names => Promise.all(names.map(loadSheet));

// Khung theo thời gian t (giây) của một hoạt ảnh.
export function frameAt(sheet, anim, t) {
  const a = sheet.anims?.[anim] || sheet.anims?.idle || {frames: [Object.keys(sheet.frames)[0]], fps: 1};
  const n = a.frames.length;
  let i = Math.floor(t * (a.fps || 10));
  i = a.loop === false ? Math.min(i, n - 1) : ((i % n) + n) % n;
  return a.frames[i];
}

// Vẽ một khung, h = chiều cao hiển thị (rộng tự theo tỉ lệ khung).
export function drawFrame(ctx, sheet, frame, x, y, h, {flip = false, rot = 0, alpha = 1, img = null, sy = 1} = {}) {
  const f = sheet?.frames?.[frame], im = img || sheet?.img;
  if (!f || !(im.naturalWidth || im.width)) return;
  const [sx, sy0, sw, sh, ox = 0, oy = 0] = f;
  const [FW, FH] = sheet.size || [sw, sh], k = h / FH;
  ctx.save();
  if (alpha !== 1) ctx.globalAlpha *= alpha;
  ctx.translate(x, y);
  if (rot) ctx.rotate(rot);
  if (flip) ctx.scale(-1, 1);
  if (sy !== 1) ctx.scale(1, sy);
  ctx.drawImage(im, sx, sy0, sw, sh, (ox - FW * sheet.anchor[0]) * k, (oy - FH * sheet.anchor[1]) * k, sw * k, sh * k);
  ctx.restore();
}

export const drawAnim = (ctx, sheet, anim, t, x, y, h, opts) => drawFrame(ctx, sheet, frameAt(sheet, anim, t), x, y, h, opts);
