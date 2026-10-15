// Đua xe tốc độ bản nâng cấp: Gara (chọn xe, nâng cấp, mở xe mới, sơn, dán hình), hộp quà bí ẩn (tên lửa, khiên, nam châm,
// tăng tốc, biến hình robot, sấm sét, bom dầu, khiên vàng, xe bay), bình nitro, giáp, ô đồ giữ qua màn.
// Bệ tăng tốc, dốc nhảy, rào chắn, dầu trơn; xe máy cấp cao biết thả dầu và bắn tên lửa. Nhìn từ trên xuống, 6 xe, xếp hạng.
// Kéo ngón tay để lái, chạm nút để dùng đồ / nitro.
// Kho đồ (opts.carry, v:1): {coins, car, own[], up{xe:{eng,acc,grip,nitro,armor,bag}}, ip{món:sao}, items[], paint{}, decal{}, paints[], decals[]}
import {sfx, engine} from '../audio.js?v=4c51d34a6e';
import {banner, canvasIn, draw, endText, fx, loadAll, loop, pick, rand, ramp, roundRect, theme} from './funcore.js?v=4c51d34a6e';
import {drawHead, heroOf} from './figure.js?v=4c51d34a6e';
import {drawFrame} from './sheets.js?v=4c51d34a6e';
import {anim, approach, booms, clamp, dust, easeOutBack, shaker, sheets, spr, coin} from './funfx.js?v=4c51d34a6e';
import {h, img} from '../ui.js?v=4c51d34a6e';

// Xe đua: sprite Kenney Racing Pack (nhìn từ trên). Thân nghiêng theo tay lái (co ngang nhẹ), bóng đổ, đèn phanh rực, số xe trên nóc.
let RS = null;  // sheet racing/racing (nạp trong racer())
export function drawCar(ctx, x, y, w, h, frame, {num, ang = 0, hero = null, scale = 1, steer = 0, brake = 0, sh = RS, lift = 0, decal = null} = {}) {
  ctx.save();
  ctx.translate(x, y);
  // Bóng đổ (tách xa khi xe bay)
  ctx.fillStyle = 'rgba(0,0,0,.22)'; ctx.beginPath(); ctx.ellipse(w * .1 + lift * 18, h * .07 + lift * 22, w * .52 * scale, h * .5 * scale, ang, 0, 7); ctx.fill();
  ctx.rotate(ang); ctx.scale(scale * (1 - Math.min(.08, Math.abs(steer) * .12)), scale);
  if (sh && sh.frames[frame]) drawFrame(ctx, sh, frame, 0, 0, h, {rot: 0});
  else { ctx.fillStyle = '#fa5252'; roundRect(ctx, -w / 2, -h / 2, w, h, w * .3); ctx.fill(); }
  // Hình dán trên mui trước
  if (decal) draw(ctx, decal, 0, -h * .27, w * .42);
  // Đèn phanh
  if (brake > .1) {
    ctx.fillStyle = `rgba(255,40,40,${.5 + brake * .5})`;
    ctx.beginPath(); ctx.ellipse(-w * .3, h * .47, w * .1, h * .025, 0, 0, 7); ctx.ellipse(w * .3, h * .47, w * .1, h * .025, 0, 0, 7); ctx.fill();
    ctx.fillStyle = `rgba(255,60,60,${brake * .25})`; ctx.beginPath(); ctx.ellipse(0, h * .56, w * .5, h * .07, 0, 0, 7); ctx.fill();
  }
  if (hero) drawHead(ctx, 0, h * .02, w * .2, {...heroOf(hero), hat: 'racing', hatC: '#f8f9fa'});
  if (num != null) {
    ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.arc(0, h * .08, w * .16, 0, 7); ctx.fill();
    ctx.fillStyle = '#212529'; ctx.font = `800 ${w * .22}px "Baloo 2", sans-serif`; ctx.textAlign = 'center'; ctx.fillText(num, 0, h * .08 + w * .08);
  }
  ctx.restore();
}

// 4 xe có sẵn + 2 xe mở bằng xu. model: số kiểu dáng trong sheet (car_<màu>_<model>), paint: màu gốc.
const CARS = [
  {id: 'red', color: '#fa5252', spr: 'car_red_1', paint: 'red', model: 1, vi: 'Tia chớp', note: 'Chạy nhanh', vmax: 580, acc: 1.1, grip: 650, robot: 7},
  {id: 'blue', color: '#4c6ef5', spr: 'car_blue_1', paint: 'blue', model: 1, vi: 'Rồng xanh', note: 'Tăng tốc mạnh', vmax: 550, acc: 1.6, grip: 650, robot: 7},
  {id: 'yellow', color: '#fab005', spr: 'car_yellow_1', paint: 'yellow', model: 1, vi: 'Ong vàng', note: 'Lái nhạy', vmax: 550, acc: 1.1, grip: 900, robot: 7},
  {id: 'purple', color: '#be4bdb', spr: 'car_purple_1', paint: 'purple', model: 1, vi: 'Robot tím', note: 'Biến hình lâu', vmax: 550, acc: 1.1, grip: 700, robot: 11},
  {id: 'green', color: '#40c057', spr: 'car_green_5', paint: 'green', model: 5, vi: 'Khủng long', note: 'Giáp dày', vmax: 570, acc: 1.3, grip: 760, robot: 8, armor: 2, cost: 450},
  {id: 'black', color: '#343a40', spr: 'car_black_1', paint: 'black', model: 1, vi: 'Báo đen', note: 'Siêu nhanh', vmax: 615, acc: 1.45, grip: 820, robot: 9, cost: 700}
];
const ITEMS = {
  rocket: {img: 'Rocket', vi: 'TÊN LỬA!'}, shield: {img: 'Shield', vi: 'KHIÊN!'}, magnet: {img: 'Magnet', vi: 'NAM CHÂM!'},
  turbo: {img: 'High voltage', vi: 'TĂNG TỐC!'}, robot: {img: 'Robot', vi: 'BIẾN HÌNH!'}, triple: {img: 'Fire', vi: '3 TÊN LỬA!'},
  zap: {img: 'Cloud with lightning', vi: 'SẤM SÉT!'}, bomb: {img: 'Bomb', vi: 'BOM DẦU!'}, gold: {img: 'Glowing star', vi: 'KHIÊN VÀNG!'}, fly: {img: 'Wing', vi: 'XE BAY!'}
};
const ITEM_KEYS = Object.keys(ITEMS);
const BOX_POOL = ['rocket', 'rocket', 'triple', 'shield', 'magnet', 'turbo', 'robot', 'robot', 'zap', 'zap', 'bomb', 'bomb', 'gold', 'fly', 'fly'];
// Món nâng sức mạnh được trong Gara (3 TÊN LỬA dùng chung sao với Tên lửa)
const SHOP_ITEMS = ['rocket', 'shield', 'magnet', 'turbo', 'robot', 'zap', 'bomb', 'gold', 'fly'];
const UPS = [
  {k: 'eng', img: 'Gear', max: 5}, {k: 'acc', img: 'Wind face', max: 5}, {k: 'grip', img: 'Wrench', max: 5},
  {k: 'nitro', img: 'Fuel pump', max: 5}, {k: 'armor', img: 'Shield', max: 4}, {k: 'bag', img: 'Backpack', max: 2}
];
// Giá: một lượt (1-3 cấp) được khoảng 50-120 xu, nên món đầu cần 2-3 lượt
const upCost = (k, n) => k === 'bag' ? 220 + n * 140 : 120 + n * 60;
const IP_MAX = 3, ipCost = n => 100 + n * 60;
const PAINTS = {red: '#fa5252', blue: '#4c6ef5', green: '#40c057', yellow: '#fab005', black: '#343a40', purple: '#be4bdb'};
const PAINT_COST = 30, DECALS = ['Star', 'Fire', 'High voltage', 'Crown'], DECAL_COST = 40;
const BAG_MAX = 3, RANK_COINS = [0, 15, 10, 6, 4, 2, 1];
// Màu xe đối thủ (sprite) theo màu cũ
const AI_SPR = {'#fa5252': 'car_red_3', '#4c6ef5': 'car_blue_5', '#40c057': 'car_green_3', '#fab005': 'car_yellow_5', '#be4bdb': 'car_purple_3', '#fd7e14': 'car_black_3'};
const sprOf = (G, c) => `car_${G.paint[c.id] || c.paint}_${c.model}`;
const clone = o => JSON.parse(JSON.stringify(o));

// Đọc kho đồ phòng thủ: thiếu/sai trường thì lấy mặc định, không bao giờ hạ cấp đã có.
function norm(raw) {
  const c = raw && typeof raw === 'object' ? raw : {};
  const num = (v, a, b) => Math.max(a, Math.min(b, Math.floor(+v || 0)));
  const arr = v => Array.isArray(v) ? v : [];
  const own = new Set(['red', 'blue', 'yellow', 'purple', ...arr(c.own)].filter(id => CARS.some(x => x.id === id)));
  const up = {};
  for (const x of CARS) { const u = (c.up || {})[x.id] || {}; up[x.id] = Object.fromEntries(UPS.map(s => [s.k, num(u[s.k], 0, s.max)])); }
  const ip = Object.fromEntries(SHOP_ITEMS.map(k => [k, num((c.ip || {})[k], 0, IP_MAX)]));
  const paints = [...new Set([...arr(c.paints), ...CARS.filter(x => own.has(x.id)).map(x => x.paint)])].filter(p => PAINTS[p]);
  const decals = [...new Set(arr(c.decals))].filter(d => DECALS.includes(d));
  const paint = {}, decal = {};
  for (const x of CARS) {
    const p = (c.paint || {})[x.id]; paint[x.id] = paints.includes(p) ? p : x.paint;
    const d = (c.decal || {})[x.id]; if (decals.includes(d)) decal[x.id] = d;
  }
  return {v: 1, coins: num(c.coins, 0, 1e7), car: own.has(c.car) ? c.car : 'red', own: [...own], up, ip,
    items: arr(c.items).filter(k => ITEMS[k]).slice(0, BAG_MAX), paint, decal, paints, decals};
}

// CSS màn Gara (prefix rcg-), dựa trên .carpick/.carcard có sẵn trong app.css
const RCG_CSS = `
.rcg{justify-content:flex-start;gap:10px;padding:64px 12px 24px}
.rcg-top{display:flex;align-items:center;gap:12px;flex-wrap:wrap;justify-content:center}
.rcg-coins{display:flex;align-items:center;gap:6px;background:#fff;border-radius:999px;padding:4px 18px 4px 6px;font-weight:800;font-size:1.7em;color:#e67700;box-shadow:0 4px 0 rgba(0,0,0,.15)}
.rcg-coins img,.rcg-buy img,.rcg-price img{width:1.3em;height:1.3em}
.rcg .cars{grid-template-columns:repeat(6,minmax(0,1fr));width:min(1000px,100%);gap:10px}
@media (max-width:760px){.rcg .cars{grid-template-columns:repeat(3,minmax(0,1fr))}.rcg .carcard span{display:none}}
.rcg-slot{display:flex;flex-direction:column;gap:6px;min-width:0}
.rcg-slot .carcard,.rcg-lock{width:100%;min-width:0}
.rcg-on .carcard{outline:5px solid #ffd43b;outline-offset:2px}
.rcg-lock{display:flex;flex-direction:column;align-items:center;gap:2px;padding:10px 6px 12px;border-radius:26px;background:#dee2e6;border:4px dashed #868e96;font-weight:800}
.rcg-lock canvas{width:100%;max-width:130px;height:auto;opacity:.45}
.rcg-lock b{font-size:1.15em;color:#495057}
.rcg-tune{display:flex;align-items:center;justify-content:center;gap:4px;border-radius:16px;background:#fff;border:3px solid #fff;font-weight:800;font-size:1.1em;padding:4px;color:#495057;box-shadow:0 4px 0 rgba(0,0,0,.12)}
.rcg-on .rcg-tune{background:#ffd43b;border-color:#fab005}
.rcg-tune img{width:28px;height:28px}
.rcg-price{display:flex;align-items:center;gap:3px;color:#e67700;font-size:1.2em}
.rcg-box{width:min(1000px,100%);background:rgba(255,255,255,.92);border-radius:24px;padding:10px 12px;box-shadow:0 5px 0 rgba(0,0,0,.12)}
.rcg-box h3{margin:0 0 6px;font-size:1.4em;display:flex;align-items:center;gap:8px;color:#343a40}
.rcg-box h3 img{width:40px;height:40px}
.rcg-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(205px,1fr));gap:8px}
.rcg-row{display:flex;align-items:center;gap:6px;background:#f1f3f5;border-radius:18px;padding:6px 8px}
.rcg-row>img{width:44px;height:44px;flex:none}
.rcg-st{flex:1;color:#fab005;font-size:1.15em;letter-spacing:-1px;white-space:nowrap}
.rcg-buy{display:flex;align-items:center;gap:2px;border-radius:14px;background:#40c057;color:#fff;font-weight:800;font-size:1.1em;padding:4px 8px;border:0;box-shadow:0 3px 0 #2b8a3e;flex:none}
.rcg-buy.no{background:#adb5bd;box-shadow:0 3px 0 #868e96}
.rcg-buy.max{background:#fab005;box-shadow:0 3px 0 #e67700}
.rcg-sws{display:flex;flex-wrap:wrap;gap:8px;align-items:center}
.rcg-sw{width:54px;height:54px;border-radius:50%;border:4px solid #fff;box-shadow:0 3px 0 rgba(0,0,0,.2);display:flex;align-items:center;justify-content:center;font-weight:800;color:#fff;font-size:.85em;padding:0;flex-direction:column;line-height:1}
.rcg-sw.on{outline:4px solid #ffd43b;outline-offset:2px}
.rcg-sw img{width:34px;height:34px}
.rcg-sw.dc{background:#fff;color:#e67700;border-color:#dee2e6}
.rcg-bag{display:flex;gap:8px}
.rcg-bag span{width:60px;height:60px;border-radius:50%;background:#ffe066;border:4px solid #fff;display:flex;align-items:center;justify-content:center;box-shadow:0 3px 0 rgba(0,0,0,.15)}
.rcg-bag span.e{background:#e9ecef}
.rcg-bag img{width:42px;height:42px}
.rcg-play{font-size:1.8em;font-weight:800;padding:6px 34px;border-radius:999px;background:#fa5252;color:#fff;border:5px solid #fff;box-shadow:0 6px 0 rgba(0,0,0,.25)}
.rcg-play:active{transform:scale(.95)}
@keyframes rcg-shake{0%,100%{transform:translateX(0)}25%{transform:translateX(-8px)}75%{transform:translateX(8px)}}
.rcg-shake{animation:rcg-shake .3s 2}
`;

// Màn Gara (DOM): chạm thẻ xe = chọn và vào đua ngay (như cũ); nút cờ lê để xem/nâng cấp xe đó; nút "Chơi ▶" (trên cùng) chạy xe đang chọn.
function garage(box, opts, G) {
  if (!document.getElementById('rcg-style')) document.head.append(h('style', {id: 'rcg-style'}, RCG_CSS));
  return new Promise(resolve => {
    let sel = G.car;
    const wrap = h('div', {class: 'carpick rcg'});
    const save = () => { opts.carry = G; if (opts.saveGear) opts.saveGear(clone(G)); };
    const go = c => { G.car = c.id; save(); sfx('power'); wrap.remove(); resolve(c); };
    const pay = (cost, el, fn) => {
      if (G.coins < cost) { sfx('wrong'); const ce = wrap.querySelector('.rcg-coins'); for (const e of [el, ce]) if (e) { e.classList.remove('rcg-shake'); void e.offsetWidth; e.classList.add('rcg-shake'); } return; }
      G.coins -= cost; fn(); sfx('star'); save(); render();
    };
    const stars = (n, max) => '★'.repeat(n) + '☆'.repeat(max - n);
    const buyBtn = (cost, el) => h('button', {class: 'rcg-buy' + (G.coins < cost ? ' no' : '')}, img('Coin'), cost);
    const carCanvas = c => {
      const cv = h('canvas', {width: 160, height: 200});
      const t0 = performance.now();
      const spin = now => {
        if (!cv.isConnected && now - t0 > 500) return;
        const x = cv.getContext('2d'), k = (now - t0) / 1000;
        x.clearRect(0, 0, 160, 200);
        drawCar(x, 80, 100 + Math.sin(k * 3) * 3, 66, 122, sprOf(G, c), {hero: opts.hero, ang: Math.sin(k * 1.6) * .06, steer: Math.sin(k * 1.6) * .3, decal: G.decal[c.id]});
        requestAnimationFrame(spin);
      };
      requestAnimationFrame(spin);
      return cv;
    };
    function render() {
      const top = wrap.scrollTop;
      const c = CARS.find(x => x.id === sel) || CARS[0], U = G.up[c.id];
      const slots = CARS.map(x => {
        const owned = G.own.includes(x.id), lv = UPS.reduce((s, u) => s + G.up[x.id][u.k], 0);
        if (!owned) {
          const b = h('button', {class: 'rcg-lock', style: {'--c': x.color}}, carCanvas(x), h('b', {}, x.vi), h('span', {class: 'rcg-price'}, img('Locked'), img('Coin'), x.cost));
          b.onclick = () => pay(x.cost, b, () => { G.own.push(x.id); if (!G.paints.includes(x.paint)) G.paints.push(x.paint); sel = x.id; G.car = x.id; });
          return h('div', {class: 'rcg-slot'}, b);
        }
        return h('div', {class: 'rcg-slot' + (x.id === sel ? ' rcg-on' : '')},
          h('button', {class: 'carcard', style: {'--c': PAINTS[G.paint[x.id]] || x.color}, onclick: () => go(x)}, carCanvas(x), h('b', {}, x.vi), h('span', {}, x.note)),
          h('button', {class: 'rcg-tune', onclick: () => { sel = x.id; G.car = x.id; sfx('tap'); save(); render(); }}, img('Wrench'), '★' + lv));
      });
      // Nâng cấp xe đang chọn
      const ups = UPS.map(u => {
        const n = U[u.k], max = n >= u.max, cost = upCost(u.k, n);
        const b = max ? h('button', {class: 'rcg-buy max'}, 'MAX') : buyBtn(cost);
        if (!max) b.onclick = () => pay(cost, b, () => { U[u.k] = n + 1; });
        return h('div', {class: 'rcg-row'}, img(u.img), h('span', {class: 'rcg-st'}, stars(n, u.max)), b);
      });
      const sws = Object.keys(PAINTS).map(p => {
        const has = G.paints.includes(p);
        const b = h('button', {class: 'rcg-sw' + (G.paint[c.id] === p ? ' on' : ''), style: {background: PAINTS[p]}}, has ? '' : [img('Coin'), PAINT_COST]);
        b.onclick = () => has ? (G.paint[c.id] = p, sfx('tap'), save(), render()) : pay(PAINT_COST, b, () => { G.paints.push(p); G.paint[c.id] = p; });
        return b;
      });
      const dcs = [null, ...DECALS].map(d => {
        const has = !d || G.decals.includes(d);
        const b = h('button', {class: 'rcg-sw dc' + ((G.decal[c.id] || null) === d ? ' on' : '')}, d ? img(d) : '✕', has ? '' : h('span', {}, DECAL_COST));
        b.onclick = () => has ? (d ? (G.decal[c.id] = d) : delete G.decal[c.id], sfx('tap'), save(), render()) : pay(DECAL_COST, b, () => { G.decals.push(d); G.decal[c.id] = d; });
        return b;
      });
      const its = SHOP_ITEMS.map(k => {
        const n = G.ip[k], max = n >= IP_MAX, cost = ipCost(n);
        const b = max ? h('button', {class: 'rcg-buy max'}, 'MAX') : buyBtn(cost);
        if (!max) b.onclick = () => pay(cost, b, () => { G.ip[k] = n + 1; });
        return h('div', {class: 'rcg-row'}, img(ITEMS[k].img), h('span', {class: 'rcg-st'}, stars(n, IP_MAX)), b);
      });
      const nb = 1 + U.bag;
      const bag = h('div', {class: 'rcg-bag'}, Array.from({length: nb}, (_, i) => G.items[i] ? h('span', {}, img(ITEMS[G.items[i]].img)) : h('span', {class: 'e'})));
      wrap.replaceChildren(
        h('div', {class: 'rcg-top'}, h('h2', {}, '🏎️ Gara'), h('div', {class: 'rcg-coins'}, img('Coin'), G.coins), h('button', {class: 'rcg-play', onclick: () => go(c)}, 'Chơi ▶')),
        h('div', {class: 'cars'}, slots),
        h('div', {class: 'rcg-box'}, h('h3', {}, img('Hammer and wrench'), c.vi), h('div', {class: 'rcg-grid'}, ups)),
        h('div', {class: 'rcg-box'}, h('h3', {}, img('Artist palette')), h('div', {class: 'rcg-sws'}, sws, h('span', {style: {width: '12px'}}), dcs)),
        h('div', {class: 'rcg-box'}, h('h3', {}, img('Wrapped gift'), h('span', {class: 'rcg-bag'}, bag)), h('div', {class: 'rcg-grid'}, its)));
      wrap.scrollTop = top;
    }
    render();
    box.append(wrap);
  });
}

export async function racer(box, opts) {
  // Cấp: cấp thấp chỉ cần về top 3, cấp 9-20 top 2, từ cấp 21 phải về nhất; đối thủ nhanh dần, đường dài và nhiều chướng ngại hơn.
  const lv = opts.level || 0, th = theme(lv), goalPos = lv < 8 ? 3 : lv < 20 ? 2 : 1;
  const goalTxt = goalPos === 1 ? 'Về nhất' : `Về top ${goalPos}`;
  const SCENERY = th.deco;
  const [rs, fxs, robotS, sp] = await Promise.all([
    sheets(['racing/racing', 'fxa/fx', 'toon/robot', 'space/space']),
    loadAll([...SCENERY, 'Coin', 'High voltage', 'Chequered flag', 'Trophy', 'Rocket', 'Shield', 'Magnet', 'Robot', 'Fire', 'Construction', 'Collision', 'Sparkles', 'Wrapped gift',
      'Cloud with lightning', 'Bomb', 'Glowing star', 'Wing', 'Fuel pump', 'Star', 'Crown', opts.hero])
  ]).then(r => r[0]);
  RS = rs;
  const G = norm(opts.carry);
  opts.carry = G;
  // Gara chỉ hiện ở cấp đầu của lượt; cấp sau chơi tiếp xe đã chọn
  const pickd = opts.car || await garage(box, opts, G);
  opts.car = pickd;
  if (!opts.alive()) return null;
  const base = CARS.find(c => c.id === pickd.id) || CARS.find(c => c.spr === pickd.spr) || CARS[0];
  const U = G.up[base.id], P = G.ip;
  const paint = G.paint[base.id] || base.paint;
  // Xe thật trong màn = chỉ số gốc + nâng cấp (không sửa CARS dùng chung)
  const car = {...base, vmax: base.vmax + U.eng * 22, acc: base.acc + U.acc * .14, grip: base.grip + U.grip * 55, color: PAINTS[paint] || base.color};
  const mySpr = sprOf(G, base), myDecal = G.decal[base.id] || null;
  const slots = 1 + U.bag, nitroDur = 1.3 + U.nitro * .2;
  // Sức mạnh gara 0..1: xe máy nhanh hơn chút theo đó
  const gp = (U.eng + U.acc + U.grip + U.nitro + U.armor) / 24 + (base.vmax - 550) / 400;
  const G0 = clone(G);  // ảnh chụp đầu màn: carry lưu = G0 + phần nhặt thêm trong màn (không cộng trùng)
  const {cv, ctx, W, H} = canvasIn(box);
  const S = Math.min(W, H), carW = Math.max(46, Math.min(70, W * .075)), carH = carW * 1.75;
  const rw = Math.min(W * .34, 260), LEN = Math.round(ramp(lv, 20000, 34000));
  let meY = H * .72;
  const cx = d => W / 2 + W * .13 * Math.sin(d * .0009) + W * .09 * Math.sin(d * .00037 + 1.3);
  const AIS = Object.entries(AI_SPR).filter(([, s]) => !s.startsWith(`car_${paint}_`)).slice(0, 5);
  const me = {d: 0, x: cx(0) + rw * .3, v: 0, vx: 0, tx: null, nitro: 0, spin: 0, ang: 0, coins: 0, roll: 0, shield: 0, magnet: 0, robot: 0, morph: 0, air: 0, slow: 0, hits: 0, bump: 0,
    gold: 0, fly: 0, inv: 0, bag: G.items.slice(0, slots), hidden: G.items.slice(slots), tanks: 1 + Math.ceil(U.nitro / 2), armor: U.armor + (base.armor || 0), tmax: {}};
  const armor0 = me.armor;
  const ai = [[220, -.5], [220, .1], [420, -.2], [420, .5], [620, 0]].map(([d, off], i) => ({d, off, v: 0, base: rand(470, 540) + ramp(lv, -40, 105) + gp * ramp(lv, 15, 75), color: AIS[i][0], spr: AIS[i][1], num: i + 2, ph: rand(0, 6), spin: 0, slow: 0}));
  const items = [], scen = [], rockets = [], skids = [], traps = [], botR = [], F = fx(), D = dust(260), B = booms(fxs), SH = shaker();
  const rowsY = new Float32Array(Math.ceil((H + 32) / 10) + 1), rowsC = new Float32Array(rowsY.length);
  for (let i = 0; i < rowsY.length; i++) rowsY[i] = -16 + i * 10;
  let vPrev = 0, brake = 0, botCd = 3, lastSaved = 0;
  // Xe máy biết chơi xấu từ cấp 6 (thả dầu) và cấp 15 (bắn tên lửa chậm, né được), mạnh dần theo cấp và sức mạnh gara
  const atkOil = lv >= 5 ? ramp(lv, .01, .05) + gp * .01 : 0, atkRkt = lv >= 14 ? ramp(lv, .02, .07) + gp * .015 : 0;
  const hsh = n => { const x = Math.sin(n * 127.1) * 43758.5453; return x - Math.floor(x); };  // ngẫu nhiên cố định theo vị trí
  // Cảnh hai bên: cây, lều, khán đài, chồng lốp (Kenney) xen cảnh theo chủ đề
  const KEN = ['tree_large', 'tree_small', 'tree_large', 'tent_red', 'tent_blue', 'tires_red', 'tires_white', 'barrel_red', 'barrel_blue', 'rock1'];
  for (let d = 300; d < LEN + 800; d += rand(60, 120)) {
    const ken = Math.random() < .55, k = ken ? pick(KEN) : pick(SCENERY);
    scen.push({d, side: Math.random() < .5 ? -1 : 1, gap: ken && k.startsWith('tire') ? rand(0, 20) : rand(10, 160), k, ken, s: ken ? (k.startsWith('tree') ? rand(80, 130) : k.startsWith('tent') ? rand(70, 95) : rand(30, 44)) : rand(58, 96)});
  }
  for (let d = 1600; d < LEN; d += rand(2600, 4200)) scen.push({d, side: Math.random() < .5 ? -1 : 1, gap: 30, k: 'tribune_full', ken: true, s: 110, tri: true});
  // Đường đua: xu, hộp quà, bệ tăng tốc, dốc nhảy, dầu, rào chắn
  for (let d = 900; d < LEN - 400; d += rand(420, 700)) {
    const r = Math.min(.999, Math.random() + ramp(lv, 0, .16)), off = rand(-.65, .65);
    if (r < .38) for (let k = 0; k < 5; k++) items.push({d: d + k * 70, off, k: 'coin'});
    else if (r < .58) for (const o of [-.55, 0, .55]) items.push({d, off: o, k: 'box'});
    else if (r < .7) items.push({d, off, k: 'boost'});
    else if (r < .78) items.push({d, off, k: 'ramp'});
    else if (r < .9) items.push({d, off, k: 'oil'});
    else { items.push({d, off: -.4, k: 'cone'}); items.push({d: d + 260, off: .4, k: 'cone'}); }
  }
  let t = -3.2, end = null, endT = 0, lastBeep = 4, finishOrder = [], roulette = 0, flash = 0, popItem = 0;
  const btnR = Math.min(62, S * .1), btn = {x: W - btnR - 22, y: H - btnR - 22};
  // Nút nitro bên trái nút đồ; ô đồ phụ (ô 2, 3) xếp phía trên nút đồ
  const nbtn = {x: btn.x - btnR * 2.35, y: btn.y + btnR * .15, r: btnR * .78};
  const sbtn = [btn, ...[1, 2].map(i => ({x: btn.x, y: btn.y - btnR * (1.75 + (i - 1) * 1.45), r: btnR * .62}))];
  const steerTo = e => { const r = cv.getBoundingClientRect(); me.tx = e.clientX - r.left; };
  const hitBtn = e => {
    const r = cv.getBoundingClientRect(), x = e.clientX - r.left, y = e.clientY - r.top;
    if (Math.hypot(x - btn.x, y - btn.y) < btnR * 1.15) return 0;
    for (let i = 1; i < slots; i++) if (Math.hypot(x - sbtn[i].x, y - sbtn[i].y) < sbtn[i].r * 1.2) return i;
    if (Math.hypot(x - nbtn.x, y - nbtn.y) < nbtn.r * 1.2) return 'n';
    return -1;
  };
  cv.addEventListener('pointerdown', e => {
    const b = hitBtn(e);
    if (b === 'n') { useNitro(); return; }
    if (b >= 0) { useItem(b); return; }
    cv.setPointerCapture(e.pointerId); steerTo(e);
  });
  cv.addEventListener('pointermove', e => { if ((e.buttons || e.pointerType !== 'mouse') && hitBtn(e) === -1) steerTo(e); });
  cv.addEventListener('pointerup', () => { me.tx = null; });
  const place = () => 1 + ai.filter(a => a.d > me.d).length;
  const stopEngine = () => engine(0);
  const ix = it => cx(it.d) + it.off * rw;
  const flying = () => me.air > 0 || me.fly > 0;
  const tough = () => me.robot > 0 || me.shield > 0 || me.gold > 0;
  // Kho đồ mới = đầu màn + xu nhặt được + ô đồ hiện tại (món dùng rồi thì mất, món còn giữ lại)
  const build = (extra = 0) => ({...clone(G0), coins: G0.coins + me.coins + extra, items: [...me.bag, ...me.hidden].slice(0, BAG_MAX)});
  const saveMid = () => { if (opts.saveGear) opts.saveGear(build()); lastSaved = me.coins; };

  function giveItem() {
    if (me.bag.length >= slots || roulette > 0) return;
    roulette = .9; sfx('coin');
  }
  function fireRocket(off = 0) {
    rockets.push({d: me.d + carH * .6, x: me.x + off, v: me.v + 620 + P.rocket * 60, life: 3 + P.rocket * .4, target: null, turn: 6 + P.rocket * 2});
    sfx('shoot'); D.puff(me.x + off, meY - carH * .5, 4, 'rgba(240,240,240,1)', 50, 7);
  }
  const timed = (k, s) => { me[k] = Math.max(me[k], s); me.tmax[k] = me[k]; };
  function useNitro() {
    if (me.tanks <= 0 || end || t < 0) { if (t >= 0 && !end) sfx('tap'); return; }
    me.tanks--; timed('nitro', nitroDur); sfx('power'); SH.add(4); F.text(me.x, meY - carH, 'NITRO!', '#ff922b');
  }
  function useItem(i = 0) {
    if (!me.bag[i] || end || t < 0) return;
    const k = me.bag.splice(i, 1)[0], p = P[k === 'triple' ? 'rocket' : k] || 0, m = 1 + p * .25;
    popItem = .3; saveMid();
    F.text(me.x, meY - carH, ITEMS[k].vi, '#ffd43b');
    if (k === 'rocket') { fireRocket(); if (p >= 3) setTimeout(() => fireRocket(carW * .5), 180); }
    else if (k === 'triple') { fireRocket(-carW * .6); setTimeout(() => fireRocket(0), 150); setTimeout(() => fireRocket(carW * .6), 300); }
    else if (k === 'shield') { timed('shield', 7 * m); sfx('power'); }
    else if (k === 'magnet') { timed('magnet', 8 * m); sfx('power'); }
    else if (k === 'turbo') { timed('nitro', 3 * m); sfx('power'); SH.add(4); }
    else if (k === 'robot') { timed('robot', car.robot * (1 + p * .2)); me.morph = .7; sfx('win'); F.burst(me.x, meY, 30, ['#be4bdb', '#ffd43b', '#4dabf7']); B.add(me.x, meY, carH * 1.2, 'smoke'); }
    else if (k === 'zap') {
      // Sấm sét: mọi xe phía trước chạy chậm
      const dur = 2.5 + p * .8; flash = .35; sfx('boom'); SH.add(6);
      for (const a of ai) if (a.d > me.d) { a.slow = dur; const ay = meY - (a.d - me.d); if (ay > -40) D.sparks(cx(a.d) + a.off * rw, ay, 10, '#ffe066', 260); }
    } else if (k === 'bomb') {
      // Bom dầu thả phía sau: xe máy cán phải là quay vòng
      const n = 1 + p;
      for (let j = 0; j < n; j++) traps.push({d: me.d - carH * (.8 + j * 1.1), off: clamp((me.x - cx(me.d)) / rw + (j % 2 ? .35 : -.35) * (j > 0), -.8, .8)});
      sfx('pop'); B.add(me.x, meY + carH * .7, 70, 'smoke');
    } else if (k === 'gold') { timed('gold', 6 * m); sfx('win'); F.burst(me.x, meY, 30, ['#ffd43b', '#fab005', '#fff']); }
    else if (k === 'fly') { timed('fly', 2.6 * (1 + p * .3)); sfx('jump'); D.puff(me.x, meY + carH * .4, 8, 'rgba(220,220,220,1)', 90, 9); }
  }
  // Giáp đỡ một cú: trả về true nếu đỡ được
  const absorb = (x, y) => {
    if (me.armor <= 0) return false;
    me.armor--; me.inv = .8; sfx('hit'); F.text(x, y - 30, 'KENG!', '#74c0fc'); D.sparks(x, y, 12, '#a5d8ff', 260); SH.add(3);
    return true;
  };
  const knock = (a, push) => {
    a.spin = 1.2; a.v *= .3; a.off = Math.max(-.85, Math.min(.85, a.off + push * .4));
    const ax = cx(a.d) + a.off * rw, ay = meY - (a.d - me.d);
    B.add(ax, ay, carH * 1.1); D.sparks(ax, ay, 14, '#ffd43b', 320); D.puff(ax, ay, 6, 'rgba(90,90,90,1)', 70, 10);
    sfx('boom'); me.hits++; SH.add(7);
  };

  return loop({
    update(dt) {
      t += dt; SH.update(dt); D.update(dt); B.update(dt); popItem = Math.max(0, popItem - dt);
      if (t < 0) { const n = Math.ceil(-t); if (n < lastBeep) { lastBeep = n; sfx('tap'); } F.update(dt); if (Math.random() < .5) D.emit(me.x + rand(-6, 6), meY + carH * .5, rand(-20, 20), rand(30, 70), {life: .5, r: 4, grow: 14, c: 'rgba(200,200,200,1)', a: .5}); return null; }
      if (lastBeep > 0) { lastBeep = 0; sfx('power'); SH.add(3); for (let k = 0; k < 10; k++) D.emit(me.x + rand(-carW * .4, carW * .4), meY + carH * .5, rand(-60, 60), rand(60, 160), {life: .7, r: 6, grow: 24, c: 'rgba(210,210,210,1)', a: .6}); }
      if (end) { endT += dt; F.update(dt); engine(Math.max(0, .3 - endT * .3)); if (endT > 2.4) { stopEngine(); return end; } return null; }
      // Hộp quà quay số
      if (roulette > 0) { roulette -= dt; if (roulette <= 0) { if (me.bag.length < slots) me.bag.push(pick(BOX_POOL)); sfx('power'); popItem = .35; saveMid(); } }
      // Người chơi
      const roadX = cx(me.d), off = me.x - roadX, onRoad = Math.abs(off) < rw - carW * .35;
      const robot = me.robot > 0, fl = flying();
      let vmax = robot ? car.vmax + 170 : car.vmax;
      if (me.gold > 0) vmax += 90;
      if (me.fly > 0) vmax += 60;
      if (me.nitro > 0) vmax = Math.max(vmax, 860);
      if (!onRoad && !robot && !fl && me.gold <= 0) vmax = 250;
      if (me.slow > 0) vmax *= .55;
      me.v += (vmax - me.v) * Math.min(1, dt * (me.v < vmax ? car.acc : 3));
      if (me.spin > 0) { me.spin -= dt; me.v *= 1 - dt * 1.5; }
      for (const k of ['nitro', 'shield', 'magnet', 'robot', 'morph', 'air', 'slow', 'bump', 'gold', 'fly', 'inv']) me[k] = Math.max(0, me[k] - dt);
      if (robot && me.robot < .05) { F.burst(me.x, meY, 20); sfx('pop'); B.add(me.x, meY, carH, 'smoke'); }
      me.d += me.v * dt;
      // Lái có quán tính: vận tốc ngang tiến dần về mức mong muốn (không giật)
      const tx = me.tx == null ? me.x : me.tx;
      const want = clamp((tx - me.x) * 8, -car.grip, car.grip);
      me.vx = approach(me.vx, want, car.grip / 70, dt);
      me.x += me.vx * dt;
      me.x = Math.max(roadX - rw - 80, Math.min(roadX + rw + 80, me.x + (cx(me.d) - roadX)));
      const lean = me.vx / 2600 + (cx(me.d + 200) - cx(me.d)) / 900;
      me.ang = me.spin > 0 ? me.spin * 8 : approach(me.ang, lean, 10, dt);
      me.steer = approach(me.steer || 0, me.vx / car.grip * .45, 12, dt);
      brake = Math.max(0, Math.min(1, brake + ((me.v < vPrev - 2 || me.slow > 0) ? dt * 6 : -dt * 3))); vPrev = me.v;
      // Camera: chạy nhanh thì xe lùi xuống dưới một chút để thấy đường phía trước
      meY = approach(meY, H * (.7 + Math.min(1, me.v / 860) * .07), 2, dt);
      // Vệt lốp khi cua gắt hoặc trượt dầu; khói lốp; khói xả
      const hard = Math.abs(me.vx) > car.grip * .7 || me.spin > 0;
      if (onRoad && !fl && hard && me.v > 250) {
        skids.push({d: me.d - carH * .3, o: me.x - cx(me.d) - carW * .38}, {d: me.d - carH * .3, o: me.x - cx(me.d) + carW * .38}); if (skids.length > 400) skids.splice(0, 2);
        if (Math.random() < .5) D.emit(me.x + (Math.random() < .5 ? -1 : 1) * carW * .4, meY + carH * .3, rand(-30, 30), rand(40, 100), {life: .6, r: 5, grow: 22, c: 'rgba(235,235,235,1)', a: .45});
      }
      if (Math.random() < .5) D.emit(me.x + rand(-5, 5), meY + carH * .52, rand(-15, 15), me.v * .25 + rand(20, 60), me.nitro > 0 ? {life: .3, r: 5, grow: 6, c: pick(['#ffa94d', '#ffe066', '#ff6b6b']), a: .9} : {life: .5, r: 3, grow: 12, c: 'rgba(173,181,189,1)', a: .45});
      if (!onRoad && !robot && !fl && me.v > 80) { D.emit(me.x + rand(-carW * .4, carW * .4), meY + carH * .45, rand(-40, 40), rand(60, 140), {life: .45, r: 3, grow: 10, c: pick(['#8ce99a', '#69db7c', '#c3a06b']), a: .8}); }
      if (robot && Math.random() < .3) D.emit(me.x + rand(-carW * .4, carW * .4), meY + carH * .4, rand(-50, 50), rand(80, 160), {life: .4, r: 4, grow: 10, c: 'rgba(200,180,140,1)', a: .6});
      if (me.gold > 0 && Math.random() < .4) D.emit(me.x + rand(-carW * .6, carW * .6), meY + rand(-carH * .5, carH * .5), 0, rand(40, 90), {life: .5, r: 4, grow: 2, c: pick(['#ffd43b', '#fff3bf']), a: 1});
      engine(Math.min(1, me.v / 860));
      // Đối thủ
      botCd -= dt;
      for (const a of ai) {
        a.ph += dt;
        const gap = a.d - me.d;
        const band = gap > 600 ? .88 : gap < -600 ? 1.12 : 1;
        if (a.slow > 0) a.slow -= dt;
        if (a.spin > 0) { a.spin -= dt; a.v *= 1 - dt * 2; }
        else a.v += (a.base * band * (a.slow > 0 ? .5 : 1) * (1 + .06 * Math.sin(a.ph * .7)) - a.v) * Math.min(1, dt * (a.slow > 0 ? 2 : .8));
        a.d += a.v * dt;
        a.off += Math.sin(a.ph * .4) * .1 * dt;
        a.off = Math.max(-.8, Math.min(.8, a.off));
        const ax = cx(a.d) + a.off * rw, ay = meY - (a.d - me.d);
        if (Math.random() < .25 && ay > -carH && ay < H + carH) D.emit(ax + rand(-4, 4), ay + carH * .52, rand(-10, 10), rand(20, 50), {life: .4, r: 3, grow: 10, c: 'rgba(173,181,189,1)', a: .4});
        // Xe máy chơi xấu: thả dầu khi đang dẫn trước, bắn tên lửa khi ở sau bé
        if (a.spin <= 0 && a.slow <= 0 && a.d < LEN - 300) {
          if (gap > 250 && gap < 1100 && Math.random() < atkOil * dt) { items.push({d: a.d - carH, off: a.off, k: 'oil'}); if (ay > 0) F.text(ax, ay - 30, 'Dầu!', '#ced4da'); }
          if (gap < -150 && gap > -700 && botCd <= 0 && Math.random() < atkRkt * dt * 5) { botCd = ramp(lv, 5, 2.6); botR.push({d: a.d + carH * .6, x: ax, v: a.v + 300, life: 4}); sfx('shoot'); }
        }
        if (!fl && Math.abs(ay - meY) < carH * .85 && Math.abs(ax - me.x) < carW * .9 && a.spin <= 0 && (me.inv <= 0 || tough())) {
          const push = me.x < ax ? 1 : -1;
          if (tough()) { knock(a, push); F.text(ax, ay - 30, robot ? 'BỤP!' : 'BẬT!', '#ffd43b'); if (me.gold > 0) me.coins += 2; }
          else if (absorb((me.x + ax) / 2, (meY + ay) / 2)) { a.v *= .85; me.x -= push * 26; me.vx = -push * 380; me.bump = .25; if (ay < meY) a.d += 10; else a.d -= 10; }  // giáp đỡ: bật ra, không mất tốc, miễn va chạm .8 giây
          else {
            me.x -= push * 26; me.vx = -push * 380; me.v *= .82; a.v *= .95; SH.add(5); me.bump = .25; sfx('hit');
            D.sparks((me.x + ax) / 2, (meY + ay) / 2, 10, '#ffe066', 260);
            if (ay < meY) a.d += 6; else a.d -= 6;
          }
        }
        // Xe máy cán bom dầu của bé
        for (let j = traps.length - 1; j >= 0; j--) {
          const tr = traps[j];
          if (a.spin <= 0 && Math.abs(a.d - tr.d) < carH * .5 && Math.abs(a.off - tr.off) * rw < carW * .9) { traps.splice(j, 1); knock(a, 0); if (ay > -40 && ay < H + 40) F.text(ax, ay - 30, 'TRƠN!', '#ffd43b'); }
        }
        if (a.d >= LEN && !finishOrder.includes(a)) finishOrder.push(a);
      }
      // Bom dầu: bỏ khi mọi xe máy đã qua hoặc quá nhiều
      const minAi = Math.min(...ai.map(a => a.d));
      for (let j = traps.length - 1; j >= 0; j--) if (traps[j].d < minAi - 300 || traps.length > 14) traps.splice(j, 1);
      // Tên lửa: bay theo đường, tự tìm xe phía trước
      for (let i = rockets.length - 1; i >= 0; i--) {
        const r = rockets[i];
        r.life -= dt; r.d += r.v * dt;
        if (!r.target || r.target.spin > 0) r.target = ai.filter(a => a.d > r.d - 50 && a.d - r.d < 1400 && a.spin <= 0).sort((x, y) => x.d - y.d)[0] || null;
        const px = r.x;
        if (r.target) { const txx = cx(r.target.d) + r.target.off * rw; r.x += (txx - r.x) * Math.min(1, dt * (r.turn || 6)); }
        else r.x += (cx(r.d) - r.x) * Math.min(1, dt * 2);
        r.rot = Math.atan2(r.x - px, Math.max(1, r.v * dt));
        const ry = meY - (r.d - me.d);
        D.emit(r.x + rand(-3, 3), ry + 22, rand(-15, 15), rand(30, 80), {life: .5, r: 4, grow: 14, c: 'rgba(240,240,240,1)', a: .6});
        if (Math.random() < .6) D.emit(r.x, ry + 18, 0, 60, {life: .15, r: 5, grow: 2, c: pick(['#ffa94d', '#ffe066']), a: 1});
        const hitA = ai.find(a => a.spin <= 0 && Math.abs(a.d - r.d) < carH * .7 && Math.abs(cx(a.d) + a.off * rw - r.x) < carW);
        if (hitA) { knock(hitA, 0); F.text(r.x, ry - 30, 'TRÚNG!', '#ff6b6b'); rockets.splice(i, 1); continue; }
        if (r.life <= 0 || r.d > me.d + H * 1.5) rockets.splice(i, 1);
      }
      // Tên lửa của xe máy: đuổi theo bé chậm, lái né được
      for (let i = botR.length - 1; i >= 0; i--) {
        const r = botR[i];
        r.life -= dt; r.d += r.v * dt;
        const px = r.x; r.x += (me.x - r.x) * Math.min(1, dt * 1.3); r.rot = Math.atan2(r.x - px, Math.max(1, r.v * dt));
        const ry = meY - (r.d - me.d);
        if (Math.random() < .5) D.emit(r.x + rand(-3, 3), ry + 22, rand(-15, 15), rand(30, 80), {life: .4, r: 4, grow: 12, c: 'rgba(240,240,240,1)', a: .5});
        if (!fl && Math.abs(r.d - me.d) < carH * .6 && Math.abs(r.x - me.x) < carW * .7) {
          botR.splice(i, 1); B.add(me.x, meY - carH * .3, carH);
          if (tough()) { sfx('boom'); F.text(me.x, meY - carH, 'BẬT!', '#ffd43b'); }
          else if (!absorb(me.x, meY - carH * .3)) { me.spin = .8; me.v *= .5; sfx('boom'); SH.add(8); F.text(me.x, meY - carH, 'Ối!', '#ff6b6b'); }
          continue;
        }
        if (r.life <= 0 || r.d > me.d + H) botR.splice(i, 1);
      }
      // Vật phẩm trên đường
      for (let i = items.length - 1; i >= 0; i--) {
        const it = items[i], iy = meY - (it.d - me.d);
        if (iy > H + 60) { items.splice(i, 1); continue; }
        if (iy < -H) continue;
        let x = ix(it);
        // Nam châm hút xu
        if (it.k === 'coin' && me.magnet > 0 && iy > meY - 380 && iy < meY + 40) { it.off += ((me.x - x) / rw) * Math.min(1, dt * 6); x = ix(it); it.d -= (it.d - me.d) * Math.min(1, dt * 4); }
        const near = Math.abs(iy - meY) < carH * .55 && Math.abs(x - me.x) < carW * .8;
        if (!near) continue;
        if (fl && it.k !== 'coin' && it.k !== 'box') continue;
        if (it.k === 'coin') { items.splice(i, 1); me.coins++; sfx('coin'); F.text(x, iy - 20, '+1', '#ffd43b'); D.sparks(x, iy, 6, '#ffe066', 160); if (me.coins - lastSaved >= 10) saveMid(); }
        else if (it.k === 'box') { items.splice(i, 1); F.burst(x, iy, 14, ['#ff6b6b', '#ffd43b', '#4dabf7', '#69db7c']); D.sparks(x, iy, 10, '#fff', 220); giveItem(); }
        else if (it.k === 'boost') { me.nitro = Math.max(me.nitro, 1.4); sfx('power'); F.text(x, iy - 30, 'VÙÙ!', '#ff922b'); items.splice(i, 1); SH.add(3); }
        else if (it.k === 'ramp') { me.air = .9; sfx('jump'); F.text(x, iy - 30, 'BAY!', '#4dabf7'); items.splice(i, 1); D.puff(me.x, meY + carH * .4, 6, 'rgba(220,220,220,1)', 80, 8); }
        else if (it.k === 'oil') { items.splice(i, 1); if (!tough() && me.nitro <= 0 && !absorb(x, iy)) { me.spin = .8; sfx('hit'); F.text(x, iy - 30, 'Trơn quá!', '#ced4da'); } }
        else if (it.k === 'cone') {
          items.splice(i, 1); D.debris(x, iy, 10, '#ff922b', 280);
          if (tough()) { sfx('boom'); F.text(x, iy - 30, 'ĐẬP TAN!', '#ffd43b'); me.coins += 2; B.add(x, iy, 80); SH.add(4); }
          else if (!absorb(x, iy)) { me.slow = .9; sfx('hit'); SH.add(5); me.bump = .25; }
        }
      }
      // Khi đang bay mà vừa đáp: bụi + rung
      if ((me.air > 0 && me.air < dt * 1.5) || (me.fly > 0 && me.fly < dt * 1.5)) { SH.add(4); D.puff(me.x, meY + carH * .3, 8, 'rgba(220,220,220,1)', 90, 9); }
      flash = Math.max(0, flash - dt);
      if (me.d >= LEN) {
        const pos = 1 + finishOrder.length;
        const bonus = [0, 30, 20, 10, 5, 3, 2][pos] || 0, earn = RANK_COINS[pos] || 0;
        end = {win: pos <= goalPos, score: me.coins + bonus + me.hits * 2, pos, earn: me.coins + earn, carry: build(earn)};
        sfx(pos <= 3 ? 'win' : 'pop'); F.burst(me.x, meY, 40);
        for (let k = 0; k < 40; k++) D.emit(rand(0, W), -10, rand(-60, 60), rand(120, 320), {life: 2.2, r: 5, grow: 0, c: pick(['#ffd43b', '#ff6b6b', '#4dabf7', '#69db7c', '#fff']), k: 2, g: 120, a: 1});
      }
      F.update(dt);
      return null;
    },
    draw() {
      ctx.save();
      SH.apply(ctx);
      // Đường đua vẽ bằng dải đa giác dọc theo tâm đường (ít lệnh vẽ, nhẹ máy) thay vì tô từng dòng.
      const NS = rowsY.length;
      for (let i = 0; i < NS; i++) rowsC[i] = cx(me.d + (meY - rowsY[i]));
      const strip = (a, b, col) => {
        ctx.fillStyle = col; ctx.beginPath(); ctx.moveTo(rowsC[0] + a, rowsY[0]);
        for (let i = 1; i < NS; i++) ctx.lineTo(rowsC[i] + a, rowsY[i]);
        for (let i = NS - 1; i >= 0; i--) ctx.lineTo(rowsC[i] + b, rowsY[i]);
        ctx.fill();
      };
      const yOf = d => meY - (d - me.d);
      // Đoạn [d0, d1) của dải [a, b]: tứ giác
      const quad = (d0, d1, a, b) => { const y0 = yOf(d0), y1 = yOf(d1), c0 = cx(d0), c1 = cx(d1); ctx.moveTo(c0 + a, y0); ctx.lineTo(c0 + b, y0); ctx.lineTo(c1 + b, y1); ctx.lineTo(c1 + a, y1); ctx.closePath(); };
      const dTop = me.d + meY + 8, dBot = me.d + meY - H - 8;
      ctx.fillStyle = th.ground; ctx.fillRect(0, 0, W, H);
      ctx.fillStyle = 'rgba(0,0,0,.05)';
      for (let d = Math.floor(dBot / 160) * 160 + 80; d < dTop; d += 160) { const y1 = yOf(d), y0 = yOf(d + 80); ctx.fillRect(0, y0, W, y1 - y0); }
      // Hoa, bụi cỏ
      for (let d = Math.ceil(dBot / 22) * 22; d < dTop; d += 22) {
        const r1 = hsh(d / 22), r2 = hsh(d / 22 + 7.3);
        const side = r1 < .5 ? -1 : 1, gx = cx(d) + side * (rw + 50 + r2 * Math.min(220, W * .25));
        if (gx > 0 && gx < W) { ctx.fillStyle = r2 > .7 ? '#ffd43b' : r2 > .4 ? '#ff8787' : 'rgba(43,138,62,.55)'; ctx.beginPath(); ctx.arc(gx, yOf(d), r2 > .4 ? 4 : 7, 0, 7); ctx.fill(); }
      }
      strip(-rw - 34, -rw - 14, 'rgba(233,196,106,.85)'); strip(rw + 14, rw + 34, 'rgba(233,196,106,.85)');
      strip(-rw - 14, -rw, '#f8f9fa'); strip(rw, rw + 14, '#f8f9fa');
      ctx.fillStyle = '#e03131'; ctx.beginPath();
      for (let d = Math.floor(dBot / 72) * 72 + 36; d < dTop; d += 72) { quad(d, d + 36, -rw - 14, -rw); quad(d, d + 36, rw, rw + 14); }
      ctx.fill();
      strip(-rw - 3, -rw, 'rgba(0,0,0,.18)'); strip(rw + 11, rw + 14, 'rgba(0,0,0,.18)');
      strip(-rw, rw, '#525962');
      strip(-rw, -rw * .72, 'rgba(0,0,0,.14)'); strip(rw * .72, rw, 'rgba(0,0,0,.14)');
      strip(-rw, -rw * .88, 'rgba(0,0,0,.08)'); strip(rw * .88, rw, 'rgba(0,0,0,.08)');
      // Vạch làn đứt khúc
      ctx.fillStyle = 'rgba(255,255,255,.85)'; ctx.beginPath();
      for (let d = Math.floor(dBot / 140) * 140 + 70; d < dTop; d += 140) { quad(d, d + 70, -rw / 3 - 3, -rw / 3 + 3); quad(d, d + 70, rw / 3 - 3, rw / 3 + 3); }
      ctx.fill();
      // Vạch xuất phát / đích ca-rô
      for (const [d0, d1] of [[0, 36], [LEN, LEN + 48]]) {
        if (d1 < dBot || d0 > dTop) continue;
        for (let d = d0; d < d1; d += 12) for (let k = 0; k < 2 * rw / 18; k++) {
          ctx.fillStyle = ((k + Math.floor(d / 12)) % 2) ? '#fff' : '#212529';
          const y = yOf(d + 12); ctx.fillRect(cx(d) - rw + k * 18, y, 18, 12.5);
        }
      }
      // Vệt lốp
      ctx.fillStyle = 'rgba(20,20,20,.28)';
      for (const k of skids) { const ky = meY - (k.d - me.d); if (ky > -10 && ky < H + 10) ctx.fillRect(cx(k.d) + k.o - 3, ky - 3, 6, 7); }
      // Cổng đích: hai cột và băng rôn
      const finY = meY - (LEN - me.d);
      if (finY > -120 && finY < H + 80) {
        const fc = cx(LEN);
        ctx.fillStyle = 'rgba(0,0,0,.25)'; ctx.fillRect(fc - rw - 30, finY - 12, rw * 2 + 70, 26);
        ctx.fillStyle = '#495057'; ctx.fillRect(fc - rw - 34, finY - 70, 14, 80); ctx.fillRect(fc + rw + 20, finY - 70, 14, 80);
        ctx.fillStyle = '#e03131'; roundRect(ctx, fc - rw - 34, finY - 92, rw * 2 + 68, 40, 10); ctx.fill();
        ctx.fillStyle = '#fff'; ctx.font = '800 28px "Baloo 2", sans-serif'; ctx.textAlign = 'center'; ctx.fillText('🏁 VỀ ĐÍCH 🏁', fc, finY - 62);
      }
      const tt = performance.now() / 1000;
      // Bom dầu của bé (viền đỏ nhấp nháy để bé nhận ra)
      for (const tr of traps) {
        const ty = yOf(tr.d); if (ty < -60 || ty > H + 60) continue;
        const x = cx(tr.d) + tr.off * rw;
        spr(ctx, rs, 'oil', x, ty, 64, {rot: tr.d % 6});
        ctx.strokeStyle = `rgba(255,107,107,${.5 + .4 * Math.sin(tt * 8)})`; ctx.lineWidth = 4; ctx.beginPath(); ctx.arc(x, ty, 36, 0, 7); ctx.stroke();
      }
      for (const it of items) {
        const iy = meY - (it.d - me.d); if (iy < -60 || iy > H + 60) continue;
        const x = ix(it);
        if (it.k === 'coin') coin(ctx, fxs, tt + it.d * .01, x, iy, 34);
        else if (it.k === 'box') {
          // Hộp quà cầu vồng nảy lên xuống, có dấu ?
          const bob = Math.sin(tt * 5 + it.off * 5);
          ctx.fillStyle = 'rgba(0,0,0,.2)'; ctx.beginPath(); ctx.ellipse(x + 4, iy + 22, 20 - bob * 3, 7, 0, 0, 7); ctx.fill();
          ctx.save(); ctx.translate(x, iy - 6 - bob * 6); ctx.rotate(Math.sin(tt * 3 + it.off * 5) * .2);
          const hue = (tt * 120 + it.off * 200) % 360;
          ctx.fillStyle = `hsl(${hue},85%,60%)`; roundRect(ctx, -22, -22, 44, 44, 9); ctx.fill();
          ctx.strokeStyle = '#fff'; ctx.lineWidth = 3; ctx.stroke();
          ctx.fillStyle = '#fff'; ctx.font = '800 30px "Baloo 2", sans-serif'; ctx.textAlign = 'center'; ctx.fillText('?', 0, 11);
          ctx.restore();
        } else if (it.k === 'boost') {
          ctx.fillStyle = 'rgba(255,146,43,.55)'; roundRect(ctx, x - 36, iy - 42, 72, 84, 12); ctx.fill();
          for (let k = 0; k < 3; k++) { const ph = ((tt * 2.2 + k / 3) % 1); spr(ctx, rs, 'arrow_yellow', x, iy + 26 - ph * 60, 30, {alpha: Math.sin(ph * Math.PI)}); }
        } else if (it.k === 'ramp') {
          const g = ctx.createLinearGradient(0, iy + 30, 0, iy - 30); g.addColorStop(0, '#5c940d'); g.addColorStop(1, '#ffd43b');
          ctx.fillStyle = g; ctx.beginPath(); ctx.moveTo(x - 46, iy + 30); ctx.lineTo(x + 46, iy + 30); ctx.lineTo(x + 34, iy - 30); ctx.lineTo(x - 34, iy - 30); ctx.closePath(); ctx.fill();
          spr(ctx, rs, 'arrow_white', x, iy, 26);
        } else if (it.k === 'oil') spr(ctx, rs, 'oil', x, iy, 52, {rot: it.d % 6});
        else if (it.k === 'cone') { spr(ctx, rs, 'cone_straight', x - 14, iy, 36); spr(ctx, rs, 'cone_straight', x + 14, iy + 6, 36); }
      }
      for (const a of ai) {
        const ay = meY - (a.d - me.d); if (ay <= -carH || ay >= H + carH) continue;
        const ax = cx(a.d) + a.off * rw;
        drawCar(ctx, ax, ay, carW, carH, a.spr, {num: a.num, ang: a.spin > 0 ? a.spin * 9 : Math.sin(a.ph * .4) * .06, steer: Math.cos(a.ph * .4) * .2, brake: a.spin > 0 || a.slow > 0 ? 1 : 0});
        if (a.slow > 0) draw(ctx, 'Cloud with lightning', ax, ay - carH * .62 + Math.sin(tt * 9) * 3, 46);
      }
      // Khói, bụi, tia lửa dưới xe của bé
      D.draw(ctx);
      for (const r of rockets) { const ry = meY - (r.d - me.d); spr(ctx, sp, 'missile', r.x, ry, 44, {rot: r.rot || 0}); }
      // Tên lửa xe máy: chấm đỏ cảnh báo ở mép dưới khi còn ngoài màn
      for (const r of botR) {
        const ry = meY - (r.d - me.d);
        if (ry > H - 10) { ctx.fillStyle = `rgba(250,82,82,${.6 + .4 * Math.sin(tt * 14)})`; ctx.beginPath(); ctx.moveTo(r.x, H - 46); ctx.lineTo(r.x - 18, H - 14); ctx.lineTo(r.x + 18, H - 14); ctx.closePath(); ctx.fill(); ctx.fillStyle = '#fff'; ctx.font = '800 22px "Baloo 2", sans-serif'; ctx.textAlign = 'center'; ctx.fillText('!', r.x, H - 18); }
        else { ctx.fillStyle = 'rgba(250,82,82,.35)'; ctx.beginPath(); ctx.arc(r.x, ry, 26, 0, 7); ctx.fill(); spr(ctx, sp, 'missile', r.x, ry, 40, {rot: r.rot || 0}); }
      }
      if (me.nitro > 0) for (const sx of [-carW * .2, carW * .2]) {
        const fl = carH * (.45 + Math.random() * .25), fg = ctx.createLinearGradient(0, meY + carH * .5, 0, meY + carH * .5 + fl);
        fg.addColorStop(0, '#fff3bf'); fg.addColorStop(.3, '#ffa94d'); fg.addColorStop(1, 'rgba(240,62,62,0)');
        ctx.fillStyle = fg; ctx.beginPath(); ctx.moveTo(me.x + sx - 9, meY + carH * .5); ctx.quadraticCurveTo(me.x + sx, meY + carH * .5 + fl * 1.2, me.x + sx + 9, meY + carH * .5); ctx.fill();
      }
      if (me.v > 600) { ctx.strokeStyle = `rgba(255,255,255,${Math.min(.5, (me.v - 600) / 400)})`; ctx.lineWidth = 3; for (let k = 0; k < 10; k++) { const lx = hsh(k + Math.floor(tt * 8)) * W, ly = hsh(k * 3.7 + Math.floor(tt * 8)) * H; ctx.beginPath(); ctx.moveTo(lx, ly); ctx.lineTo(lx, ly + 60); ctx.stroke(); } }
      // Xe của bé (đang bay thì to hơn, bóng tách ra); nảy nhẹ khi va chạm
      const flyK = me.fly > 0 ? Math.min(1, me.fly / .4, ((me.tmax.fly || 1) - me.fly) / .4) : 0;
      const air = Math.max(me.air > 0 ? Math.sin(me.air / .9 * Math.PI) : 0, flyK);
      const bumpK = me.bump > 0 ? Math.sin(me.bump / .25 * Math.PI) * .08 : 0;
      if (me.fly > 0) for (const sd of [-1, 1]) draw(ctx, 'Wing', me.x + sd * carW * (.75 + air * .2), meY - air * 20 - carH * .05, carW * 1.1, carW * 1.1 * (.8 + .2 * Math.sin(tt * 18)), {flip: sd > 0, alpha: .4 + .6 * flyK});
      if (me.robot > 0 && me.morph <= .35 && robotS) {
        ctx.fillStyle = 'rgba(0,0,0,.22)'; ctx.beginPath(); ctx.ellipse(me.x, meY + carH * .38, carW * .6, carH * .14, 0, 0, 7); ctx.fill();
        anim(ctx, robotS, 'run', tt, me.x, meY + carH * .42 - air * 20, carH * 1.15 * (1 + air * .3), {flip: me.vx < -40});
      } else if (!(me.inv > 0 && Math.floor(tt * 16) % 2)) drawCar(ctx, me.x, meY - air * 20, carW, carH, mySpr, {ang: me.ang + (me.morph > 0 ? me.morph * 12 : 0), hero: opts.hero, scale: 1 + air * .35 + bumpK, steer: me.steer || 0, brake, lift: air, decal: myDecal});
      if (me.morph > 0) for (let k = 0; k < 3; k++) draw(ctx, 'Sparkles', me.x + rand(-40, 40), meY + rand(-50, 50), 30);
      if (me.shield > 0) { ctx.strokeStyle = `rgba(116,192,252,${.5 + .3 * Math.sin(tt * 10)})`; ctx.lineWidth = 5; ctx.beginPath(); ctx.ellipse(me.x, meY, carW * .9 + Math.sin(tt * 6) * 3, carH * .7 + Math.sin(tt * 6) * 3, 0, 0, 7); ctx.stroke(); }
      if (me.gold > 0) { ctx.strokeStyle = `rgba(255,212,59,${.7 + .3 * Math.sin(tt * 12)})`; ctx.lineWidth = 8; ctx.beginPath(); ctx.ellipse(me.x, meY, carW * 1 + Math.sin(tt * 8) * 4, carH * .76 + Math.sin(tt * 8) * 4, 0, 0, 7); ctx.stroke(); draw(ctx, 'Glowing star', me.x, meY - carH * .8, 34, 34, {rot: tt * 3}); }
      if (me.magnet > 0) draw(ctx, 'Magnet', me.x + carW * .7, meY - carH * .5, 30, 30, {rot: Math.sin(tt * 8) * .3});
      B.draw(ctx);
      for (const sc of scen) {
        const sy2 = meY - (sc.d - me.d); if (sy2 < -130 || sy2 > H + 130) continue;
        const sx2 = cx(sc.d) + sc.side * (rw + 40 + sc.gap + sc.s / 2);
        if (sc.ken) { spr(ctx, rs, sc.k, sx2, sy2, sc.s, {rot: sc.tri ? sc.side * Math.PI / 2 : 0}); continue; }
        ctx.fillStyle = 'rgba(0,0,0,.18)'; ctx.beginPath(); ctx.ellipse(sx2 + sc.s * .15, sy2 + sc.s * .38, sc.s * .38, sc.s * .12, 0, 0, 7); ctx.fill();
        draw(ctx, sc.k, sx2, sy2, sc.s);
      }
      F.draw(ctx);
      ctx.restore();
      if (flash > 0) { ctx.fillStyle = `rgba(255,255,230,${flash * 1.6})`; ctx.fillRect(0, 0, W, H); }
      // HUD
      const pos = end ? end.pos : place();
      ctx.fillStyle = 'rgba(0,0,0,.35)'; roundRect(ctx, 12, 10, 150, 64, 20); ctx.fill();
      ctx.fillStyle = '#fff'; ctx.textAlign = 'left'; ctx.font = '800 22px "Baloo 2", sans-serif'; ctx.fillText('Hạng', 26, 36);
      ctx.font = '800 34px "Baloo 2", sans-serif'; ctx.fillStyle = pos === 1 ? '#ffd43b' : '#fff'; ctx.fillText(`${pos}/6`, 26, 66);
      ctx.fillStyle = 'rgba(0,0,0,.35)'; roundRect(ctx, 172, 10, 110, 44, 22); ctx.fill();
      spr(ctx, fxs, 'coin', 196, 32, 28); ctx.fillStyle = '#fff'; ctx.font = '800 26px "Baloo 2", sans-serif'; ctx.fillText(String(me.coins), 216, 42);
      // Giáp còn lại: khiên nhỏ dưới ô xu
      for (let k = 0; k < armor0; k++) draw(ctx, 'Shield', 186 + k * 24, 68, 22, 22, {alpha: k < me.armor ? 1 : .25});
      const bx = W - 26, by = 80, bh = H - 260;
      ctx.fillStyle = 'rgba(0,0,0,.3)'; roundRect(ctx, bx - 6, by, 12, bh, 6); ctx.fill();
      for (const a of ai) { ctx.fillStyle = a.color; ctx.beginPath(); ctx.arc(bx, by + bh * (1 - Math.min(1, a.d / LEN)), 6, 0, 7); ctx.fill(); }
      ctx.fillStyle = car.color; ctx.strokeStyle = '#fff'; ctx.lineWidth = 3; ctx.beginPath(); ctx.arc(bx, by + bh * (1 - Math.min(1, me.d / LEN)), 10, 0, 7); ctx.fill(); ctx.stroke();
      draw(ctx, 'Chequered flag', bx, by - 18, 30);
      // Nút dùng đồ (nảy khi nhận/dùng đồ); ô phụ phía trên
      const bs = 1 + (popItem > 0 ? Math.sin(popItem / .35 * Math.PI) * .18 : 0);
      for (let i = slots - 1; i >= 0; i--) {
        const sb = sbtn[i], r = i === 0 ? btnR * bs : sb.r, k = me.bag[i];
        ctx.fillStyle = k ? `rgba(255,212,59,${.85 + .15 * Math.sin(tt * 8)})` : 'rgba(255,255,255,.55)';
        ctx.beginPath(); ctx.arc(sb.x, sb.y, r, 0, 7); ctx.fill();
        ctx.strokeStyle = '#fff'; ctx.lineWidth = i === 0 ? 5 : 4; ctx.stroke();
        if (i === me.bag.length && roulette > 0) draw(ctx, ITEMS[ITEM_KEYS[Math.floor(tt * 14) % ITEM_KEYS.length]].img, sb.x, sb.y, r * 1.1);
        else if (k) draw(ctx, ITEMS[k].img, sb.x, sb.y, r * 1.2, r * 1.2, {rot: k === 'rocket' || k === 'triple' ? -Math.PI / 4 : Math.sin(tt * 6) * .12});
        else draw(ctx, 'Wrapped gift', sb.x, sb.y, r * .9, r * .9, {alpha: .45});
      }
      // Nút nitro: số bình còn lại
      ctx.fillStyle = me.tanks > 0 ? 'rgba(255,146,43,.9)' : 'rgba(255,255,255,.4)';
      ctx.beginPath(); ctx.arc(nbtn.x, nbtn.y, nbtn.r, 0, 7); ctx.fill(); ctx.strokeStyle = '#fff'; ctx.lineWidth = 4; ctx.stroke();
      draw(ctx, 'Fuel pump', nbtn.x, nbtn.y - 4, nbtn.r * 1.05, nbtn.r * 1.05, {alpha: me.tanks > 0 ? 1 : .4});
      ctx.fillStyle = '#212529'; ctx.beginPath(); ctx.arc(nbtn.x + nbtn.r * .72, nbtn.y + nbtn.r * .62, 15, 0, 7); ctx.fill();
      ctx.fillStyle = '#fff'; ctx.textAlign = 'center'; ctx.font = '800 20px "Baloo 2", sans-serif'; ctx.fillText(String(me.tanks), nbtn.x + nbtn.r * .72, nbtn.y + nbtn.r * .62 + 7);
      let hy = 84;
      for (const [k, im] of [['robot', 'Robot'], ['gold', 'Glowing star'], ['fly', 'Wing'], ['shield', 'Shield'], ['magnet', 'Magnet'], ['nitro', 'High voltage']]) {
        if (me[k] <= 0) continue;
        ctx.fillStyle = 'rgba(0,0,0,.3)'; roundRect(ctx, 72, hy, 130, 34, 17); ctx.fill();
        draw(ctx, im, 92, hy + 17, 26);
        ctx.fillStyle = '#ffd43b'; roundRect(ctx, 110, hy + 11, 82 * Math.min(1, me[k] / (me.tmax[k] || 3)), 12, 6); ctx.fill();
        hy += 40;
      }
      if (t < 0) {
        const n = Math.ceil(-t), ph = -t - Math.floor(-t);
        ctx.fillStyle = '#212529'; roundRect(ctx, W / 2 - 90, H * .3 - 40, 180, 80, 20); ctx.fill();
        ['#fa5252', '#fab005', '#40c057'].forEach((c, i) => { ctx.fillStyle = (3 - i) >= n ? c : '#495057'; ctx.beginPath(); ctx.arc(W / 2 - 55 + i * 55, H * .3, 24, 0, 7); ctx.fill(); });
        ctx.save(); ctx.translate(W / 2, H / 2); const k = easeOutBack(Math.min(1, (1 - ph) * 2.5)); ctx.scale(k, k); ctx.translate(-W / 2, -H / 2);
        banner(ctx, W, H, n > 0 ? String(n) : 'ĐI!', `Cấp ${lv + 1} · ${th.vi} · 🎯 ${goalTxt}`);
        ctx.restore();
        // Đầu màn: khoe đồ đang mang (ô đồ + nitro + giáp)
        const gearIc = [...me.bag.map(k => ITEMS[k].img), ...Array(me.tanks).fill('Fuel pump'), ...Array(me.armor).fill('Shield')];
        if (gearIc.length) {
          const gw = Math.min(W - 40, gearIc.length * 48 + 24), gx = W / 2 - gw / 2, gy = H / 2 + 80, st = (gw - 24) / gearIc.length;
          ctx.fillStyle = 'rgba(0,0,0,.4)'; roundRect(ctx, gx, gy, gw, 56, 28); ctx.fill();
          gearIc.forEach((im, i) => draw(ctx, im, gx + 12 + st * (i + .5), gy + 28, Math.min(40, st - 4)));
        }
      } else if (t < .8) { ctx.save(); ctx.globalAlpha = 1 - t / .8; ctx.translate(W / 2, H / 2); ctx.scale(1 + t, 1 + t); ctx.translate(-W / 2, -H / 2); banner(ctx, W, H, 'ĐI!'); ctx.restore(); }
      if (end) banner(ctx, W, H, end.win ? endText(true, lv) : `🏁 VỀ THỨ ${end.pos}`, end.win ? `Về thứ ${end.pos} · +${end.earn} xu` : `Cần ${goalTxt.toLowerCase()} · +${end.earn} xu`);
    }
  }, () => { const ok = opts.alive(); if (!ok) stopEngine(); return ok; });
}
