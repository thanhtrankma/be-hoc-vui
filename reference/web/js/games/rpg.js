// Thế giới phiêu lưu (nhập vai, đợt 13): một nhân vật đi qua 10 vùng đất, mỗi vùng một kiểu chơi, 5 màn + 1 trùm.
// Cấp, kinh nghiệm, vàng, trang bị, đồng đội lưu ở p.rpg. Mỗi màn tốn 1 vé như game khác (bố mẹ chơi thử không tốn vé, không lưu).
import * as store from '../store.js?v=4c51d34a6e';
import {h, img, confetti, overlay, toast} from '../ui.js?v=4c51d34a6e';
import {sfx, sayPhrase} from '../audio.js?v=4c51d34a6e';
import {forest, sea, sky, swamp, castle} from './rpgzones1.js?v=4c51d34a6e';
import {mine, snow, desert, candy, volcano} from './rpgzones2.js?v=4c51d34a6e';
import {COSTUMES, costumeOf, drawFigure, figureEl, petEl, heroOf} from './figure.js?v=4c51d34a6e';
import {loadSheet} from './sheets.js?v=4c51d34a6e';
import {PET_RIG} from './rpgcore.js?v=4c51d34a6e';

export const ZONES = [
  {id: 'forest', vi: 'Rừng Xanh', img: 'Deciduous tree', boss: 'Troll', color: '#2f9e44', run: forest},
  {id: 'sea', vi: 'Biển Ngọc', img: 'Sailboat', boss: 'Squid', color: '#1971c2', run: sea},
  {id: 'mine', vi: 'Hang Mỏ', img: 'Pick', boss: 'Spider', color: '#795548', run: mine},
  {id: 'snow', vi: 'Xứ Tuyết', img: 'Snowman', boss: 'Mammoth', color: '#4dabf7', run: snow},
  {id: 'desert', vi: 'Sa Mạc', img: 'Cactus', boss: 'Scorpion', color: '#f08c00', run: desert},
  {id: 'sky', vi: 'Thành Mây', img: 'Eagle', boss: 'Cloud with lightning', color: '#7048e8', run: sky},
  {id: 'candy', vi: 'Rừng Kẹo', img: 'Lollipop', boss: 'Spider', color: '#e64980', run: candy},
  {id: 'volcano', vi: 'Núi Lửa', img: 'Volcano', boss: 'T-Rex', color: '#e8590c', run: volcano},
  {id: 'swamp', vi: 'Đầm Lầy Ma', img: 'Ghost', boss: 'Ghost', color: '#5f3dc4', run: swamp},
  {id: 'castle', vi: 'Lâu Đài Rồng', img: 'Castle', boss: 'Dragon', color: '#c92a2a', run: castle}
];
export const STAGES = 6;  // 5 màn + trùm
const rec = r => 1 + r * 4;  // cấp nên có

export const WEAPONS = [
  {img: 'Wood', vi: 'Gậy gỗ', atk: 0, cost: 0},
  {img: 'Dagger', vi: 'Dao găm', atk: 5, cost: 60},
  {img: 'Bow and arrow', vi: 'Cung tên', atk: 12, cost: 200},
  {img: 'Hammer', vi: 'Búa thần', atk: 20, cost: 450},
  {img: 'Axe', vi: 'Rìu chiến', atk: 30, cost: 800},
  {img: 'Crossed swords', vi: 'Song kiếm', atk: 42, cost: 1300},
  {img: 'Trident emblem', vi: 'Đinh ba', atk: 56, cost: 2000},
  {img: 'Magic wand', vi: 'Đũa phép', atk: 72, cost: 3000}
];
export const ARMORS = [
  {img: 'Coat', vi: 'Áo khoác', def: 0, hp: 0, cost: 0},
  {img: 'Military helmet', vi: 'Mũ sắt', def: 3, hp: 20, cost: 100},
  {img: 'Shield', vi: 'Khiên', def: 7, hp: 50, cost: 300},
  {img: 'Martial arts uniform', vi: 'Áo võ', def: 12, hp: 90, cost: 650},
  {img: 'Kimono', vi: 'Áo choàng phép', def: 18, hp: 140, cost: 1100},
  {img: 'Crown', vi: 'Vương miện', def: 26, hp: 200, cost: 1800}
];
export const CHARMS = [
  {img: 'Running shoe', vi: 'Giày gió', fx: {spd: .2}, txt: 'Chạy nhanh hơn', cost: 150},
  {img: 'Four leaf clover', vi: 'Cỏ may mắn', fx: {gold: .3}, txt: 'Thêm 30% vàng', cost: 250},
  {img: 'Ring', vi: 'Nhẫn sức mạnh', fx: {crit: .15}, txt: 'Hay đánh chí mạng', cost: 400},
  {img: 'Nazar amulet', vi: 'Bùa hồi máu', fx: {regen: .01}, txt: 'Tự hồi máu', cost: 650},
  {img: 'Sports medal', vi: 'Huy chương', fx: {xp: .3}, txt: 'Thêm 30% kinh nghiệm', cost: 900}
];
export const PETS = [
  {id: 'dog', vi: 'Cún con', txt: 'Chạy tới cắn quái', unlock: -1},
  {id: 'fairy', vi: 'Mèo thần', txt: 'Hồi máu cho bé', unlock: 2},
  {id: 'dragon', vi: 'Cáo lửa', txt: 'Phun lửa vào quái', unlock: 5}
];
const POTION = 25, MAX_POT = 5, MAX_LV = 50;
// Bạn phiêu lưu trong làng (máy), nói mẹo chơi.
const NPCS = [
  {c: {shirt: '#7048e8', pants: '#5f3dc4', dress: true, hair: '#ced4da', long: true}, wp: 'Magic wand', name: 'Bé Mây', tips: ['Mua vũ khí mới ở cửa hàng để đánh mạnh hơn!', 'Ở Đầm Lầy Ma, bấm 💡 để ma bị choáng.']},
  {c: {shirt: '#40c057', pants: '#2b8a3e', hair: '#fab005', long: true, hat: 'ears', ear: 'cat', hatC: '#fab005'}, wp: 'Bow and arrow', name: 'Bé Lá', tips: ['Ở Sa Mạc, ô màu đỏ là gần kho báu đó!', 'Thua thì về làng mua áo giáp rồi thử lại nhé.']},
  {c: COSTUMES['Ninja'], wp: 'Dagger', name: 'Bé Gió', tips: ['Ở Xứ Tuyết, bấm 👊 khi vạch ở ô xanh để đánh thật mạnh!', 'Thấy vòng đỏ dưới đất thì chạy ra ngoài ngay!']},
  {c: costumeOf('Princess'), name: 'Công chúa', tips: ['Rồng Lửa ở cuối bản đồ. Cả làng trông cậy vào bé!', 'Ở Rừng Kẹo, chạm vào lính để nâng cấp.']}
];

// Cảnh làng động (đợt 15): lát ô Kenney Tiny Town (cỏ, đường đất, nhà, cây, hàng rào), bạn bè đi lại trên đường,
// dừng chào rồi đi tiếp. Canvas tự dừng khi rời trang.
function villageEl(npcs) {
  const cv = document.createElement('canvas'), dpr = Math.min(2, window.devicePixelRatio || 1), HH = 190;
  cv.className = 'rpgvillage';
  Object.assign(cv.style, {width: '100%', height: HH + 'px', display: 'block', borderRadius: '18px', margin: '0 0 12px', boxShadow: '0 4px 0 rgba(0,0,0,.12)'});
  const ctx = cv.getContext('2d');
  let T = null, W = 0, bg = null, last = performance.now(), t = 0, started = false;
  loadSheet('kenney-tiny-town/town').then(sh => { T = sh; });
  const walkers = npcs.map((n, i) => ({c: n.c, wp: n.wp, x: 60 + i * 140, v: (i % 2 ? -1 : 1) * (38 + i * 7), pause: 0, wave: 0}));
  const build = () => {
    const ts = 38, cols = Math.ceil(W / ts) + 1, rows = Math.ceil(HH / ts);
    const c = document.createElement('canvas'); c.width = Math.round(W * dpr); c.height = Math.round(HH * dpr);
    const g = c.getContext('2d'); g.scale(dpr, dpr); g.imageSmoothingEnabled = false;
    const put = (fr, x, y, w = ts, hh = ts) => { const f = T.frames[fr]; if (f) g.drawImage(T.img, f[0], f[1], f[2], f[3], x, y, w, hh); };
    let seed = 3; const rnd = () => { seed = (seed * 9301 + 49297) % 233280; return seed / 233280; };
    for (let y = 0; y < rows; y++) for (let x = 0; x < cols; x++) put(rnd() < .85 ? 't0' : rnd() < .5 ? 't1' : 't2', x * ts, y * ts);
    const pathY = 3 * ts;
    for (let x = 0; x < cols; x++) put(x % 3 ? 't40' : 't39', x * ts, pathY);
    // Nhà mái đỏ / mái xanh xen kẽ, cây, hàng rào, giếng, tổ ong, bia tập bắn
    for (let i = 0, x = 1; x < cols - 3; i++, x += 6) {
      const red = i % 2 === 0, X = x * ts;
      put(red ? 't52' : 't48', X, 0); put(red ? 't53' : 't49', X + ts, 0); put(red ? 't54' : 't50', X + ts * 2, 0);
      put(red ? 't64' : 't60', X, ts); put(red ? 't65' : 't61', X + ts, ts); put(red ? 't66' : 't62', X + ts * 2, ts);
      put(red ? 't72' : 't76', X, ts * 2); put(red ? 't74' : 't78', X + ts, ts * 2); put(red ? 't75' : 't79', X + ts * 2, ts * 2);
      put(['t16', 't28', 't15', 't27'][i % 4], X + ts * 3.4, ts * 1.4, ts * 1.2, ts * 1.2);
      put(['t94', 't83', 't95', 't104'][i % 4], X + ts * 4.4, ts * 2);
      put('t44', X - ts * .2, ts * 4); put('t45', X + ts * .8, ts * 4); put('t45', X + ts * 1.8, ts * 4); put('t46', X + ts * 2.8, ts * 4);
      put(['t29', 't17', 't5'][i % 3], X + ts * 4.2, ts * 4.1);
    }
    return c;
  };
  const frame = now => {
    if (started && !cv.isConnected) return;
    if (cv.isConnected) started = true;
    const dt = Math.min(.05, (now - last) / 1000); last = now; t += dt;
    const w = cv.clientWidth || 360;
    if (w !== W) { W = w; cv.width = Math.round(W * dpr); cv.height = Math.round(HH * dpr); bg = null; }
    if (T && T.img.naturalWidth && !bg) bg = build();
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    if (bg) ctx.drawImage(bg, 0, 0, W, HH); else { ctx.fillStyle = '#8ce99a'; ctx.fillRect(0, 0, W, HH); }
    const feet = 3 * 38 + 34;
    for (const k of walkers) {
      if (k.pause > 0) { k.pause -= dt; if (k.pause <= 0) k.v = -k.v; }
      else { k.x += k.v * dt; if (k.x < 30 || k.x > W - 30 || Math.random() < dt * .12) { k.x = Math.max(30, Math.min(W - 30, k.x)); k.pause = 1.2 + Math.random() * 1.5; k.wave = Math.random() < .5; } }
    }
    walkers.sort((a, b) => a.x - b.x);
    walkers.forEach((k, i) => drawFigure(ctx, k.x, feet + (i % 2) * 6, 64, {c: k.c, pose: k.pause > 0 ? (k.wave ? 'cheer' : 'idle') : 'run', t: t * (k.pause > 0 ? 1 : .7) + i, face: k.v > 0 ? 1 : -1, weapon: k.wp}));
    requestAnimationFrame(frame);
  };
  requestAnimationFrame(frame);
  return cv;
}

export function rpgOf(p) {
  if (!p.rpg) p.rpg = {lv: 1, xp: 0, gold: 30, w: 0, a: 0, c: null, ownW: [0], ownA: [0], ownC: [], pet: 'dog', pot: 2, prog: {}};
  return p.rpg;
}
export const need = L => 30 + L * 20;
export function stats(R) {
  const w = WEAPONS[R.w], a = ARMORS[R.a], c = R.c != null ? CHARMS[R.c].fx : {};
  return {lv: R.lv, atk: 10 + R.lv * 3 + w.atk, def: a.def + Math.floor(R.lv / 2), maxhp: 80 + R.lv * 15 + a.hp,
    spd: 1 + (c.spd || 0), crit: .05 + (c.crit || 0), goldMul: 1 + (c.gold || 0), xpMul: 1 + (c.xp || 0), regen: c.regen || 0};
}
const prog = (R, r) => R.prog[r] || 0;
export const unlockedZone = (R, r) => r === 0 || prog(R, r - 1) >= STAGES;
export const canPlay = (p, r, s) => { const R = rpgOf(p); r = +r; s = +s; return r >= 0 && r < ZONES.length && s >= 0 && s < STAGES && unlockedZone(R, r) && s <= prog(R, r); };
const petOk = (R, pt) => pt.unlock < 0 || prog(R, pt.unlock) >= STAGES;

// ---------- Làng ----------
// ctx: {el, go, back, heroImg, free, tickets()}
export function town(ctx) {
  const p = store.profile(), R = rpgOf(p), st = stats(R);
  if (!ctx.quiet) sayPhrase('rpgTown');
  const npc = NPCS[Math.floor(Math.random() * NPCS.length)], tip = npc.tips[Math.floor(Math.random() * npc.tips.length)];
  const chip = (i, v, c) => h('span', {class: 'rpgchip', style: {'--c': c}}, i, ' ', v);
  const zoneTile = (z, r) => {
    const open = unlockedZone(R, r), done = prog(R, r);
    return h('button', {class: 'rpgzone' + (open ? '' : ' locked'), style: {'--c': z.color}, onclick: () => {
      if (!open) { sfx('wrong'); toast(`Thắng trùm ${ZONES[r - 1].vi} để mở vùng này`); return; }
      sfx('tap'); stagePicker(ctx, r);
    }},
    h('span', {class: 'zn'}, r + 1), img(open ? z.img : 'Locked'), h('b', {}, z.vi),
    h('span', {class: 'zrec'}, `Nên cấp ${rec(r)}`),
    h('span', {class: 'zdots'}, Array.from({length: STAGES}, (_, s) => h('i', {class: s < done ? 'on' : ''}, s === STAGES - 1 ? '👑' : ''))));
  };
  ctx.el.replaceChildren(...[
    h('div', {class: 'topbar'}, ctx.back('/fun'), h('h1', {}, '⚔️ Thế giới phiêu lưu'), h('span', {class: 'pill'}, img('Admission tickets'), ctx.free ? '∞' : ctx.tickets())),
    ctx.free ? h('p', {class: 'note', style: {textAlign: 'center', fontWeight: 700}}, '👨‍👩‍👦 Bố mẹ chơi thử: không tốn vé, không lưu tiến độ') : null,
    villageEl(NPCS),
    h('div', {class: 'rpghero card'},
      h('div', {class: 'rpgava'}, Object.assign(figureEl(heroOf(ctx.heroImg), {size: 150, cls: 'fig'}), {weapon: WEAPONS[R.w].img}), R.pet ? petEl(PET_RIG[R.pet] || 'dog', {size: 70, cls: 'pt'}) : null),
      h('div', {class: 'rpginfo'},
        h('div', {class: 'rpglv'}, h('b', {}, `Cấp ${R.lv}`), h('span', {class: 'xpbar'}, h('i', {style: {width: `${R.lv >= MAX_LV ? 100 : Math.round(R.xp / need(R.lv) * 100)}%`}}), h('em', {}, R.lv >= MAX_LV ? 'Cấp cao nhất' : `${R.xp}/${need(R.lv)} kinh nghiệm`))),
        h('div', {class: 'rpgchips'}, chip('❤️', st.maxhp, '#ffe3e3'), chip('⚔️', st.atk, '#fff4e6'), chip('🛡', st.def, '#e7f5ff'), chip(img('Coin'), R.gold, '#fff9db'), chip('🧪', R.pot, '#ebfbee')),
        h('div', {class: 'rpgbtns'},
          h('button', {class: 'btn blue', onclick: () => { sfx('tap'); shop(ctx); }}, '🛒 Cửa hàng'),
          h('button', {class: 'btn ghost', onclick: () => { sfx('tap'); petPicker(ctx); }}, '🐾 Đồng đội')))),
    h('div', {class: 'rpgnpc'}, Object.assign(figureEl(npc.c, {size: 76, cls: 'npcfig'}), {weapon: npc.wp || null}), h('div', {class: 'say'}, h('b', {}, npc.name, ': '), tip)),
    h('h2', {class: 'title funsec'}, '🗺️ Bản đồ thế giới'),
    h('div', {class: 'rpgmap'}, ZONES.map(zoneTile))
  ].filter(Boolean));
}

function stagePicker(ctx, r) {
  const p = store.profile(), R = rpgOf(p), z = ZONES[r], done = prog(R, r);
  const ov = overlay(
    h('h2', {}, img(z.img, {style: {width: '56px', verticalAlign: 'middle'}}), ' ', z.vi),
    h('p', {class: 'note'}, `Cấp nên có: ${rec(r)} · Bé đang cấp ${R.lv}`),
    h('div', {class: 'rpgstages'}, Array.from({length: STAGES}, (_, s) => {
      const open = s <= done, boss = s === STAGES - 1;
      return h('button', {class: 'rpgst' + (s < done ? ' done' : '') + (open ? '' : ' locked') + (boss ? ' boss' : ''), onclick: () => {
        if (!open) { sfx('wrong'); return; }
        if (!ctx.free && ctx.tickets() <= 0) { sfx('wrong'); sayPhrase('noTicket'); toast('Hết vé rồi! Học thêm một bài để có vé nhé'); return; }
        ov.remove(); ctx.go(`/rpg/${r}/${s}`);
      }}, boss ? img(z.boss) : h('b', {}, s + 1), h('span', {}, boss ? 'Trùm' : `Màn ${s + 1}`), s < done ? h('i', {}, '✔') : open ? null : h('i', {}, '🔒'));
    })),
    h('p', {class: 'note'}, ctx.free ? '' : '🎟️ Mỗi màn tốn 1 vé'),
    h('div', {class: 'row'}, h('button', {class: 'btn ghost', onclick: () => ov.remove()}, 'Đóng')));
}

function shop(ctx) {
  const p = store.profile(), R = rpgOf(p);
  let tab = 'w';
  const ov = overlay(h('div', {class: 'rpgshop'}));
  const box = ov.querySelector('.rpgshop');
  const buy = (cost, then) => { if (R.gold < cost) { sfx('wrong'); toast('Chưa đủ vàng'); return; } R.gold -= cost; then(); sfx('coin'); confetti(30); store.save(); render(); };
  const row = (it, owned, using, onBuy, onUse, stat) => h('div', {class: 'rpgitem' + (using ? ' using' : '')},
    img(it.img), h('div', {class: 'it'}, h('b', {}, it.vi), h('span', {}, stat)),
    using ? h('span', {class: 'tag'}, 'Đang dùng') : owned ? h('button', {class: 'small-btn', onclick: () => { onUse(); sfx('tap'); store.save(); render(); }}, 'Dùng')
      : h('button', {class: 'small-btn buy' + (R.gold < it.cost ? ' poor' : ''), onclick: () => buy(it.cost, () => { onBuy(); onUse(); })}, img('Coin'), it.cost));
  function render() {
    const list = tab === 'w' ? WEAPONS.map((it, i) => row(it, R.ownW.includes(i), R.w === i, () => R.ownW.push(i), () => { R.w = i; }, `⚔️ +${it.atk} sức đánh`))
      : tab === 'a' ? ARMORS.map((it, i) => row(it, R.ownA.includes(i), R.a === i, () => R.ownA.push(i), () => { R.a = i; }, `🛡 +${it.def} giáp · ❤️ +${it.hp}`))
      : tab === 'c' ? CHARMS.map((it, i) => row(it, R.ownC.includes(i), R.c === i, () => R.ownC.push(i), () => { R.c = i; }, it.txt))
      : [h('div', {class: 'rpgitem'}, img('Test tube'), h('div', {class: 'it'}, h('b', {}, `Bình máu (${R.pot}/${MAX_POT})`), h('span', {}, 'Hồi một nửa máu khi bấm 🧪')),
          R.pot >= MAX_POT ? h('span', {class: 'tag'}, 'Đầy túi') : h('button', {class: 'small-btn buy' + (R.gold < POTION ? ' poor' : ''), onclick: () => buy(POTION, () => { R.pot++; })}, img('Coin'), POTION))];
    box.replaceChildren(
      h('h2', {}, '🛒 Cửa hàng'), h('p', {class: 'note'}, img('Coin', {style: {width: '28px', verticalAlign: 'middle'}}), ` Bé có ${R.gold} vàng`),
      h('div', {class: 'rpgtabs'}, [['w', '⚔️ Vũ khí'], ['a', '🛡 Áo giáp'], ['c', '✨ Bùa'], ['p', '🧪 Bình máu']].map(([k, l]) => h('button', {class: tab === k ? 'on' : '', onclick: () => { tab = k; sfx('tap'); render(); }}, l))),
      h('div', {class: 'rpglist'}, list),
      h('div', {class: 'row'}, h('button', {class: 'btn', onclick: () => { ov.remove(); town({...ctx, quiet: true}); }}, 'Xong')));
  }
  render();
}

function petPicker(ctx) {
  const p = store.profile(), R = rpgOf(p);
  const ov = overlay(h('h2', {}, '🐾 Đồng đội'), h('p', {class: 'note'}, 'Chọn một bạn đi phiêu lưu cùng bé'),
    h('div', {class: 'rpglist'}, PETS.map(pt => {
      const ok = petOk(R, pt);
      return h('div', {class: 'rpgitem' + (R.pet === pt.id ? ' using' : '')}, ok ? petEl(PET_RIG[pt.id], {size: 64, cls: 'petfig'}) : img('Locked'), h('div', {class: 'it'}, h('b', {}, pt.vi), h('span', {}, ok ? pt.txt : `Thắng trùm ${ZONES[pt.unlock].vi} để mở`)),
        R.pet === pt.id ? h('span', {class: 'tag'}, 'Đang đi cùng') : ok ? h('button', {class: 'small-btn', onclick: () => { R.pet = pt.id; store.save(); sfx('tap'); ov.remove(); town({...ctx, quiet: true}); }}, 'Chọn') : null);
    })),
    h('div', {class: 'row'}, h('button', {class: 'btn ghost', onclick: () => ov.remove()}, 'Đóng')));
}

// ---------- Chơi một màn ----------
// opts: {box, r, s, heroImg, alive, free}. Trả kết quả đã cộng thưởng (hoặc null khi thoát giữa chừng).
export async function playStage(opts) {
  const p = store.profile(), R = rpgOf(p), r = +opts.r, s = +opts.s, z = ZONES[r], st = stats(R);
  const Z = {st, heroImg: opts.heroImg, weaponImg: WEAPONS[R.w].img, pet: R.pet, potions: R.pot, r, s, boss: s === STAGES - 1, alive: opts.alive};
  sayPhrase(s === STAGES - 1 ? 'rpgBoss' : `rpgZ${r}`);
  const res = await z.run(opts.box, Z);
  if (!res) return null;
  const first = res.win && s >= prog(R, r);
  const bonusXp = res.win ? Math.round((20 + r * 25 + s * 6) * (Z.boss ? 3 : 1) * (first ? 1 : .5)) : 0;
  const bonusGold = res.win ? Math.round((15 + r * 15) * (Z.boss ? 3 : 1) * (first ? 1 : .5) * st.goldMul) : 0;
  const out = {win: res.win, gold: res.gold + bonusGold, xp: Math.round((res.xp + bonusXp) * st.xpMul), kills: res.kills, ups: 0, cleared: false, unlocked: null, r, s};
  if (opts.free) return out;
  R.gold += out.gold; R.pot = res.potions;
  if (first) { R.prog[r] = s + 1; if (s === STAGES - 1) { out.cleared = true; out.unlocked = PETS.find(pt => pt.unlock === r) || null; } }
  R.xp += out.xp;
  while (R.lv < MAX_LV && R.xp >= need(R.lv)) { R.xp -= need(R.lv); R.lv++; out.ups++; }
  if (R.lv >= MAX_LV) R.xp = 0;
  out.lv = R.lv;
  store.save();
  return out;
}

// Bảng kết quả sau màn. ctx: {go, free, tickets(), onNext(r, s)}
export function resultPanel(res, ctx) {
  const R = rpgOf(store.profile()), z = ZONES[res.r];
  if (res.win) { sfx('win'); confetti(); sayPhrase(res.cleared ? 'rpgClear' : res.ups ? 'rpgLevelUp' : 'youWin'); } else sayPhrase('rpgLose');
  const nextS = res.win ? res.s + 1 : res.s, nextR = nextS >= STAGES ? res.r + 1 : res.r, nS = nextS >= STAGES ? 0 : nextS;
  const canNext = nextR < ZONES.length && (ctx.free || canPlay(store.profile(), nextR, nS));
  const ov = overlay(
    h('h2', {}, res.win ? (res.cleared ? `👑 Giải cứu ${z.vi}!` : '🏆 Chiến thắng!') : '💫 Hết máu rồi!'),
    h('div', {class: 'rpgreward'}, h('span', {}, img('Coin'), `+${res.gold}`), h('span', {}, '⭐ ', `+${res.xp} kinh nghiệm`)),
    res.ups && !ctx.free ? h('div', {class: 'prize'}, img('Glowing star'), `Lên cấp ${res.lv}! Mạnh hơn rồi đó`) : null,
    res.unlocked && !ctx.free ? h('div', {class: 'prize'}, petEl(PET_RIG[res.unlocked.id], {size: 76}), `Mở khoá đồng đội: ${res.unlocked.vi}!`) : null,
    res.cleared && nextR < ZONES.length && !ctx.free ? h('div', {class: 'prize'}, img(ZONES[nextR].img), `Mở vùng mới: ${ZONES[nextR].vi}`) : null,
    res.cleared && nextR >= ZONES.length && !ctx.free ? h('div', {class: 'prize'}, img('Trophy'), 'Bé đã đánh bại Rồng Lửa! Anh hùng của cả làng!') : null,
    !res.win ? h('p', {class: 'note'}, 'Về làng mua vũ khí, áo giáp hoặc bình máu rồi thử lại nhé!') : null,
    ctx.free ? h('p', {class: 'note'}, '👨‍👩‍👦 Bố mẹ chơi thử nên không lưu') : null,
    h('div', {class: 'row'},
      h('button', {class: 'btn ghost', onclick: () => { ov.remove(); ctx.go('/rpg'); }}, '🏘️ Về làng'),
      canNext && (ctx.free || ctx.tickets() > 0)
        ? h('button', {class: 'btn blue', onclick: () => { ov.remove(); ctx.onNext(nextR, nS); }}, res.win ? '▶ Màn tiếp' : '🔄 Thử lại', ctx.free ? '' : ' (🎟️ 1)')
        : !ctx.free && ctx.tickets() <= 0 ? h('button', {class: 'btn green', onclick: () => { ov.remove(); ctx.go('/map'); }}, '📚 Học để có vé') : null));
  return ov;
}
