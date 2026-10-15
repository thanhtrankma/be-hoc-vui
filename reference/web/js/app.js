// Bé Vui Học: điều hướng màn hình (theo #hash), hồ sơ bé, bản đồ đảo, màn chơi, Góc bố mẹ.
import * as store from './store.js?v=4c51d34a6e';
import * as audio from './audio.js?v=4c51d34a6e';
import * as sync from './sync.js?v=4c51d34a6e';
import {t, L, lang} from './i18n.js?v=4c51d34a6e';
import {h, img, src, wait, confetti, toast, overlay, isIOS, isStandalone, setPhotos, setPhotoMode, watchStage, shuffle, sample, icon, iconize} from './ui.js?v=4c51d34a6e';

// Code từng đảo chỉ tải khi bé mở đảo đó (màn đầu mở nhanh).
const loadGame = name => import(`./games/${name}.js?v=${window.BVH_VERSION}`);
// Danh sách bài lấy thẳng từ dữ liệu, không cần tải code trò chơi.
const LEVEL_KEY = {count: 'countLevels', memory: 'memoryLevels', spell: 'spellLevels', trace: 'traceLevels', math: 'mathLevels',
  logic: 'logicLevels', music: 'musicLevels', art: 'artLevels', explore: 'exploreLevels', read: 'readLevels', life: 'lifeLevels', arcade: 'arcadeLevels', code: 'codeLevels'};
function levelsOf(isl) {
  const key = isl.id === 'letters' ? 'letterLevels' : isl.id === 'english' ? 'englishLevels' : LEVEL_KEY[isl.game];
  return content[key].map((l, i) => ({i, tier: l.tier || 0, hide: !!l.hide, name: typeof l.name === 'object' ? L(l.name) : l.name, img: isl.id === 'english' || isl.game !== 'pick' ? l.img : null}));
}

// ---------- Cấp học: 1 Mầm (3-4 tuổi), 2 Chồi (5 tuổi), 3 Lớp 1 (6 tuổi). Bài tier 0 thuộc mọi cấp. ----------
const TIERS = [
  {id: 1, img: 'Seedling', color: '#51cf66', vi: 'Mầm', en: 'Sprout', age: {vi: '3–4 tuổi', en: 'Age 3–4'},
    what: {vi: 'Chữ cái, đếm đến 10, màu sắc, hình khối', en: 'Letters, counting to 10, colors, shapes'}},
  {id: 2, img: 'Herb', color: '#20c997', vi: 'Chồi', en: 'Bud', age: {vi: '5 tuổi', en: 'Age 5'},
    what: {vi: 'Dấu thanh, ghép tiếng, tập viết, cộng trừ trong 10', en: 'Tones, syllables, writing, +/− within 10'}},
  {id: 3, img: 'Deciduous tree', color: '#3d8bfd', vi: 'Lớp 1', en: 'Grade 1', age: {vi: '6 tuổi', en: 'Age 6'},
    what: {vi: 'Vần khó, đọc từ, xếp câu, toán đến 100, lời văn', en: 'Harder rhymes, reading, sentences, math to 100'}}
];
const tierOf = id => TIERS.find(x => x.id === id) || TIERS[2];
const islTiers = isl => [...new Set(levelsOf(isl).filter(l => !l.hide).map(l => l.tier).filter(Boolean))].sort();
// Cấp hiển thị cho một đảo: cấp bé đang chọn, đảo không có cấp đó thì lấy cấp gần nhất (ưu tiên thấp hơn).
const viewTier = {};
function tierFor(isl, p) {
  const have = islTiers(isl);
  if (!have.length) return 0;
  const want = viewTier[isl.id] || p.tier || 3;
  if (have.includes(want)) return want;
  return have.filter(x => x < want).pop() || have[0];
}
function tierLevels(isl, p, tier = tierFor(isl, p)) {
  return levelsOf(isl).filter(l => !l.hide && (!tier || !l.tier || l.tier === tier));
}
// Mặc định mọi bài trong cấp đều mở (bé tự chọn); bố mẹ bật "khoá theo thứ tự" thì phải xong bài trước.
function unlocked(p, isl, i) {
  if (!store.settings().lockOrder) return true;
  const list = tierLevels(isl, p, levelsOf(isl)[i] ? levelsOf(isl)[i].tier : 0);
  const pos = list.findIndex(l => l.i === i);
  return pos <= 0 || store.levelStars(p, isl.id, list[pos - 1].i) > 0;
}

function chooseTier(p, then) {
  audio.sayPhrase('pickTier');
  const ov = overlay(
    h('h2', {}, t('pickTier')),
    h('div', {class: 'tiers'}, TIERS.map(x => h('button', {class: `tiercard ${p.tier === x.id ? 'on' : ''}`, style: {'--c': x.color}, onclick: () => {
      audio.sfx('pop');
      store.updateProfile(p.id, {tier: x.id});
      for (const k in viewTier) delete viewTier[k];
      ov.remove();
      then && then();
    }}, img(x.img), h('b', {}, L(x)), h('span', {class: 'age'}, L(x.age)), h('span', {class: 'what'}, L(x.what))))),
    h('p', {class: 'note'}, t('tierHint')));
  ov.classList.add('tierov');
}
const app = document.getElementById('app');
let content, data, photos = {}, started = false, leaveGame = null;

const go = path => { location.hash = path; };
const mascot = id => data.mascots.find(m => m.id === id) || data.mascots[0];
const island = id => data.islands.find(i => i.id === id);
const back = path => h('button', {class: 'icon-btn', 'aria-label': 'Back', onclick: () => { audio.sfx('tap'); go(path); }}, icon('back'));

function screen(cls, ...kids) {
  const el = h('section', {class: `screen ${cls}`}, ...kids);
  app.replaceChildren(el);
  window.scrollTo(0, 0);
  return el;
}

// Linh vật kèm đồ đang đeo (mũ, kính, đồ cầm tay) và nền.
function dressed(p, cls = '') {
  const o = p.outfit || {};
  const item = id => data.wardrobe.find(w => w.id === id);
  const el = h('div', {class: `dressed ${cls}`}, img(mascot(p.mascot).img, {class: 'dm'}),
    ['hat', 'eyes', 'hand'].map(slot => o[slot] && item(o[slot]) ? img(item(o[slot]).img, {class: `o-${slot}`}) : null));
  if (o.bg && item(o.bg) && !cls.includes('buddy')) el.style.background = item(o.bg).bg;
  return el;
}

const BADGES = [
  {id: 'first', img: 'Glowing star', vi: 'Bài đầu tiên', en: 'First level', test: p => p.rounds >= 1},
  {id: 'r10', img: 'Sports medal', vi: '10 lượt chơi', en: '10 rounds', test: p => p.rounds >= 10},
  {id: 'r50', img: 'Trophy', vi: '50 lượt chơi', en: '50 rounds', test: p => p.rounds >= 50},
  {id: 's100', img: 'Star', vi: '100 ngôi sao', en: '100 stars', test: p => p.stars >= 100},
  {id: 's300', img: 'Shooting star', vi: '300 ngôi sao', en: '300 stars', test: p => p.stars >= 300},
  {id: 'streak3', img: 'Fire', vi: '3 ngày liên tiếp', en: '3-day streak', test: p => (p.streak || {}).count >= 3},
  {id: 'streak7', img: 'Sparkles', vi: '7 ngày liên tiếp', en: '7-day streak', test: p => (p.streak || {}).count >= 7},
  {id: 'abc', img: 'Books', vi: 'Thuộc chữ cái', en: 'Letter master', test: p => allDone(p, 'letters')},
  {id: 'writer', img: 'Pencil', vi: 'Viết đẹp', en: 'Neat writer', test: p => allDone(p, 'trace')},
  {id: 'math', img: 'Abacus', vi: 'Nhà toán học', en: 'Math whiz', test: p => allDone(p, 'math')},
  {id: 'reader', img: 'Open book', vi: 'Mọt sách', en: 'Bookworm', test: p => allDone(p, 'read')},
  {id: 'stickers', img: 'Rainbow', vi: '15 hình dán', en: '15 stickers', test: p => p.stickers.length >= 15},
  {id: 'explorer', img: 'Globe showing Asia-Australia', vi: 'Nhà thám hiểm', en: 'Explorer', test: p => gameIslands().every(i => store.levelStars(p, i.id, 0) > 0)},
  {id: 'fashion', img: 'Crown', vi: 'Thời trang', en: 'Fashionista', test: p => (p.owned || []).length >= 3}
];
const gameIslands = () => data.islands.filter(i => i.game);
// Huy hiệu "thuộc hết" tính theo cấp bé đang học.
const allDone = (p, id) => tierLevels(island(id), p).every(l => store.levelStars(p, id, l.i) > 0);

// Thanh thử thách hằng ngày trên bản đồ.
function dailyBar(p) {
  const dl = store.daily(gameIslands().map(i => i.id));
  const streak = (p.streak || {}).count || 0;
  return h('div', {class: `daily ${dl.claimed ? 'claimed' : ''}`},
    h('span', {class: 'dtitle'}, '🎯 ', t('daily')),
    h('span', {class: 'dtasks'}, dl.tasks.map(id => {
      const isl = island(id);
      const done = dl.done.includes(id);
      return h('button', {class: `dtask ${done ? 'done' : ''}`, title: t('playIn', {name: L(isl)}), style: {'--c': isl.color},
        onclick: () => { audio.sfx('tap'); go('/island/' + id); }}, img(isl.img), done ? h('b', {}, '✔') : null);
    })),
    streak ? h('span', {class: 'streak'}, '🔥 ', t('streak', {n: streak})) : null,
    dueCount(p) >= 2 ? h('button', {class: 'dreview', onclick: () => { audio.sfx('tap'); go('/review'); }}, '🔁 Ôn bài ', h('b', {}, dueCount(p))) : null);
}

// Máy tự tải lại trang (iPad giải phóng bộ nhớ, đổi bản mới): bấm Bắt đầu xong quay về đúng màn bé đang ở.
const RESUME = ['map', 'island', 'fun', 'pet', 'album', 'room', 'buddies', 'rpg', 'lop1'];
function resumeRoute() {
  try {
    const r = sessionStorage.getItem('bvh.route') || '';
    return RESUME.includes(r.replace(/^#?\//, '').split('/')[0]) ? r.replace(/^#/, '') : null;
  } catch (e) { return null; }
}

// Báo DatPilot có hồ sơ mới (để đếm số gia đình dùng app). KHÔNG gửi tên bé hay tiến độ: chỉ loại máy, hồ sơ thứ mấy trên máy,
// đã cài lên màn hình chính chưa, ngôn ngữ. Chỉ chạy trên datpilot.com thật, không chạy khi test tự động (navigator.webdriver).
function hello(n) {
  try {
    if (location.hostname !== 'datpilot.com' || navigator.webdriver) return;
    const dev = devKind();
    fetch('/api/bvh/hello', {method: 'POST', headers: {'Content-Type': 'application/json'}, keepalive: true,
      body: JSON.stringify({ev: 'new_profile', n, dev, app: isStandalone() ? 1 : 0, lang: lang(), v: window.BVH_VERSION, ...firstTouch()})}).catch(() => {});
  } catch (e) { /* không ảnh hưởng bé */ }
}

// Nguồn của lần đầu ghé (2026-10-15): nhãn ?src= của link chia sẻ + nhóm trang dẫn sang (facebook/zalo/google…).
// Trang /be-vui-hoc ghi cùng 2 khoá này (chung tên miền), app chỉ ghi khi chưa có. Gửi kèm tín hiệu tạo hồ sơ, không gửi URL đầy đủ.
const SRC_OK = ['giaykhen', 'app', 'fb', 'link', 'web', 'webfb', 'weblink'];
function refKind() {
  const ua = navigator.userAgent;
  if (/FBAN|FBAV|FB_IAB|Instagram/.test(ua)) return 'facebook';
  if (/Zalo/i.test(ua)) return 'zalo';
  let host = '';
  try { host = document.referrer ? new URL(document.referrer).hostname : ''; } catch (e) { /* bỏ qua */ }
  if (!host) return 'direct';
  for (const [k, re] of [['facebook', /facebook\.|fb\.|messenger\./], ['zalo', /zalo/], ['google', /google\./], ['bing', /bing\./],
    ['tiktok', /tiktok/], ['youtube', /youtube|youtu\.be/], ['datpilot', /datpilot\.com$/]]) if (re.test(host)) return k;
  return 'other';
}
(function noteSource() {
  try {
    const q = new URLSearchParams(location.search).get('src');
    if (q && SRC_OK.includes(q) && !localStorage.getItem('bvh.src')) localStorage.setItem('bvh.src', q);
    if (!localStorage.getItem('bvh.ref')) localStorage.setItem('bvh.ref', refKind());
  } catch (e) { /* bỏ qua */ }
})();
function firstTouch() {
  try { return {src: localStorage.getItem('bvh.src') || undefined, ref: localStorage.getItem('bvh.ref') || undefined}; } catch (e) { return {}; }
}
// Bấm nút chia sẻ (k = nút nào). Bảng chia sẻ của máy chỉ đếm khi chia sẻ xong (không đếm khi bấm huỷ).
function shareEvent(k) {
  try {
    if (location.hostname !== 'datpilot.com' || navigator.webdriver) return;
    fetch('/api/bvh/hello', {method: 'POST', headers: {'Content-Type': 'application/json'}, keepalive: true,
      body: JSON.stringify({ev: 'share', k, dev: devKind(), app: isStandalone() ? 1 : 0, lang: lang(), v: window.BVH_VERSION})}).catch(() => {});
  } catch (e) { /* bỏ qua */ }
}

// Mỗi ngày (giờ VN) máy có bé học báo 1 lần để đếm bao nhiêu nhà quay lại. KHÔNG có mã máy hay tên bé: chỉ số ngày từ khi
// tạo hồ sơ đầu tiên (age), số ngày đã mở app (ad), loại máy, đã cài app chưa. Đếm ad lưu ở localStorage bvh.act.
function active() {
  try {
    const day = new Date(Date.now() + 7 * 3600e3).toISOString().slice(0, 10);
    let a = {};
    try { a = JSON.parse(localStorage.getItem('bvh.act')) || {}; } catch (e) { /* bỏ qua */ }
    if (a.d === day) return;
    a = {d: day, c: (a.c || 0) + 1};
    try { localStorage.setItem('bvh.act', JSON.stringify(a)); } catch (e) { return; }
    if (location.hostname !== 'datpilot.com' || navigator.webdriver) return;
    // age theo ngày lịch giờ VN (hồ sơ tạo hôm qua = 1) để khớp nhóm "vào ngày X" trong tin tổng kết (portal bvhreport.py).
    const vnDay = ms => Math.floor((ms + 7 * 3600e3) / 864e5);
    const first = Math.min(...store.profiles().map(p => p.created || Date.now()));
    const age = Math.max(0, vnDay(Date.now()) - vnDay(first));
    fetch('/api/bvh/hello', {method: 'POST', headers: {'Content-Type': 'application/json'}, keepalive: true,
      body: JSON.stringify({ev: 'active', age, ad: a.c, dev: devKind(), app: isStandalone() ? 1 : 0, lang: lang(), v: window.BVH_VERSION})}).catch(() => {});
  } catch (e) { /* không ảnh hưởng bé */ }
}

function devKind() {
  const ua = navigator.userAgent;
  return isIOS() ? (/iPhone|iPod/.test(ua) ? 'iphone' : 'ipad') : /Android/.test(ua) ? (/Mobile/.test(ua) ? 'android-phone' : 'android-tablet') : 'desktop';
}

// Bố mẹ mở mã QR cà phê: báo 1 lần mỗi máy để biết bao nhiêu nhà quan tâm ủng hộ (không biết ai có chuyển hay không).
function cafeSeen() {
  try {
    if (localStorage.getItem('bvh.cafe')) return;
    localStorage.setItem('bvh.cafe', '1');
    if (location.hostname !== 'datpilot.com' || navigator.webdriver) return;
    fetch('/api/bvh/hello', {method: 'POST', headers: {'Content-Type': 'application/json'}, keepalive: true,
      body: JSON.stringify({ev: 'cafe', dev: devKind(), app: isStandalone() ? 1 : 0, lang: lang(), v: window.BVH_VERSION})}).catch(() => {});
  } catch (e) { /* bỏ qua */ }
}

// Lưu ảnh QR: điện thoại mở bảng chia sẻ (iPhone có "Lưu hình ảnh"), máy khác tải file về.
async function saveQR() {
  const url = 'ungho.webp?v=' + window.BVH_VERSION, name = 'ung-ho-be-vui-hoc.png';
  try {
    const bmp = await createImageBitmap(await (await fetch(url)).blob());
    const cv = document.createElement('canvas'); cv.width = bmp.width; cv.height = bmp.height;
    cv.getContext('2d').drawImage(bmp, 0, 0);
    const blob = await new Promise(r => cv.toBlob(r, 'image/png'));   // PNG để app ngân hàng nào cũng đọc được
    const file = new File([blob], name, {type: 'image/png'});
    if (navigator.canShare && navigator.canShare({files: [file]}) && (isIOS() || /Android/.test(navigator.userAgent))) {
      try { await navigator.share({files: [file]}); return; } catch (e) { if (e.name === 'AbortError') return; }
    }
    const a = h('a', {href: URL.createObjectURL(blob), download: name});
    document.body.append(a); a.click(); a.remove();
    toast('Đã lưu ảnh mã QR');
  } catch (e) { toast('Chưa lưu được, bố mẹ nhấn giữ vào mã hoặc chụp màn hình nhé'); }
}

async function copyText(text, msg) {
  try { await navigator.clipboard.writeText(text); toast(msg); }
  catch (e) { prompt('Chép số tài khoản:', text); }
}

// ---------- Màn Bắt đầu: lần chạm đầu mở khoá âm thanh trên iPad ----------
let ready = null;  // Promise: dữ liệu + âm thanh đã sẵn sàng
function start() {
  const btn = h('button', {class: 'btn big', onclick: async () => {
      audio.unlock();
      if (!content) {
        // Mạng chậm: báo đang tải thay vì nút im lặng; tải hỏng thì dọn bản lưu và tải lại (BVH_FAIL trong index.html).
        btn.disabled = true;
        btn.textContent = '⏳ Đang tải…';
        try { await ready; } catch (e) { if (window.BVH_FAIL) window.BVH_FAIL('không tải được dữ liệu'); else location.reload(); return; }
      }
      audio.music();
      store.persist();
      started = true;
      audio.sfx('win');
      const p = store.profile();
      if (store.profiles().length) active();
      if (!store.profiles().length) { audio.sayPhrase('welcome'); go('/new'); }
      else if (store.profiles().length === 1 && p) go(resumeRoute() || '/map');
      else go('/kids');
    }}, '▶ ', t('start'));
  screen('start',
    h('div', {class: 'parade'}, ['Man superhero', 'Robot', 'T-rex', 'Princess'].map(n => img(n))),
    h('h1', {class: 'logo'}, 'Bé ', h('span', {}, 'Vui'), ' Học'),
    h('p', {class: 'tagline'}, t('tagline')),
    btn,
    // iOS cũ (chưa có audioSession) vẫn tắt tiếng khi gạt nút im lặng: nhắc bố mẹ.
    isIOS() && !navigator.audioSession ? h('p', {class: 'mutehint'}, '🔇 Không nghe tiếng? Gạt nút im lặng bên hông máy') : null,
    h('p', {class: 'startlinks'}, h('a', {href: '/be-vui-hoc', target: '_blank', rel: 'noopener'}, 'Giới thiệu'), ' · ',
      h('a', {href: '/be-vui-hoc/ghi-cong', target: '_blank', rel: 'noopener'}, 'Ghi công')));
}

// ---------- Chọn bé ----------
function kids() {
  audio.sayPhrase('whoPlays');
  screen('',
    h('div', {class: 'topbar'}, h('span', {class: 'spacer'}), h('h1', {}, t('whoPlays')),
      h('span', {class: 'spacer', style: {textAlign: 'right'}}, parentBtn())),
    h('div', {class: 'kids'},
      store.profiles().map(p => h('button', {class: 'kid card', onclick: () => { audio.sfx('tap'); store.setActive(p.id); go('/map'); }},
        img(mascot(p.mascot).img), h('span', {class: 'name'}, p.name), h('span', {class: 'stars'}, '⭐ ', p.stars))),
      h('button', {class: 'kid card add', onclick: () => { audio.sfx('tap'); go('/new'); }}, h('b', {}, '+'), t('addKid'))
    ),
    installBanner()
  );
}

// ---------- Tạo hồ sơ: nhập tên rồi chọn linh vật ----------
function newKid() {
  let name = '', chosen = null;
  const input = h('input', {class: 'name-input', maxlength: 20, placeholder: t('namePh'), autocomplete: 'off', enterkeyhint: 'next'});
  const nextBtn = h('button', {class: 'btn', disabled: true, onclick: step2}, t('next'), ' ➜');
  input.addEventListener('input', () => { name = input.value.trim(); nextBtn.disabled = !name; });
  input.addEventListener('keydown', e => { if (e.key === 'Enter' && name) step2(); });
  screen('',
    h('div', {class: 'topbar'}, store.profiles().length ? back('/kids') : h('span', {class: 'spacer'}), h('h1', {}, t('yourName')), h('span', {class: 'spacer'})),
    h('div', {class: 'center-col', style: {marginTop: '6vh'}}, img('Sparkles', {style: {width: '120px'}}), input, nextBtn,
      // Máy mới của nhà đã dùng app: bố mẹ nhập mã gia đình để lấy hồ sơ của bé về.
      !store.profiles().length && sync.supported() ? h('button', {class: 'small-btn joinfam', onclick: async () => {
        audio.sfx('tap');
        const v = prompt('Nhà mình đã dùng Bé Vui Học trên máy khác? Nhập mã gia đình (ở Góc bố mẹ trên máy đó):');
        if (!v) return;
        const r = await sync.join(v);
        if (r === 'ok' && store.profiles().length) { store.setActive(store.profiles()[0].id); go('/kids'); }
        else toast(r === 'notfound' ? 'Không tìm thấy mã này' : r === 'bad' ? 'Mã gồm 16 chữ và số' : 'Chưa kết nối được, thử lại sau');
      }}, '🔑 Đã có mã gia đình') : null)
  );
  setTimeout(() => input.focus(), 300);

  function step2() {
    input.blur();
    audio.sayPhrase('pickMascot');
    const go2 = h('button', {class: 'btn green big', disabled: true, onclick: () => {
      store.addProfile(name, chosen);
      hello(store.profiles().length);
      active();
      audio.sfx('win'); confetti();
      go('/map');
    }}, t('letsGo'));
    const grid = h('div', {class: 'mascots'}, data.mascots.filter(m => !m.stars).map(m => {
      const b = h('button', {class: 'mascot', onclick: () => {
        grid.querySelectorAll('.on').forEach(x => x.classList.remove('on'));
        b.classList.add('on');
        chosen = m.id; go2.disabled = false;
        audio.say(audio.tpl(lang() === 'en' ? 'mascotEn' : 'mascotVi', m));
      }}, img(m.img), L(m));
      return b;
    }));
    screen('',
      h('div', {class: 'topbar'}, h('button', {class: 'icon-btn', 'aria-label': 'Back', onclick: newKid}, icon('back')), h('h1', {}, t('pickBuddy')), h('span', {class: 'spacer'})),
      h('div', {class: 'center-col'}, grid, go2)
    );
  }
}

// ---------- Bản đồ đảo ----------
function levelCount(isl) { return levelsOf(isl).length; }

function map() {
  const p = store.profile();
  const m = mascot(p.mascot);
  islandScreen.said = null;
  audio.sayPhrase('pickIsland');
  screen('',
    h('div', {class: 'topbar home'},
      h('button', {class: 'hello', onclick: () => { audio.sfx('tap'); go('/buddies'); }},
        h('span', {class: 'avatar'}, dressed(p)),
        h('span', {style: {minWidth: 0, textAlign: 'left'}}, h('div', {class: 'who'}, t('hi', {name: p.name})), h('div', {class: 'sub'}, t('pickIsland')))),
      h('button', {class: 'pill tierpill', style: {'--c': tierOf(p.tier).color}, onclick: () => { audio.sfx('tap'); chooseTier(p, map); }},
        img(tierOf(p.tier).img), L(tierOf(p.tier))),
      h('span', {class: 'pill'}, img('Glowing star'), p.stars),
      h('button', {class: 'icon-btn', 'aria-label': t('album'), onclick: () => { audio.sfx('tap'); go('/album'); }}, img('Trophy')),
      h('button', {class: 'icon-btn', 'aria-label': t('switchKid'), onclick: () => { audio.sfx('tap'); go('/kids'); }}, icon('kids')),
      parentBtn()
    ),
    dailyBar(p),
    h('div', {class: 'bars2'},
      store.settings().fun ? h('button', {class: 'funbar', onclick: () => { audio.sfx('tap'); go('/fun'); }},
        img('Joystick'), h('span', {class: 'ft'}, t('funZone')), h('span', {class: 'fsub'}, img('Admission tickets'), ' ', t('tickets', {n: store.tickets(p)})),
        h('span', {class: 'fgames'}, img('Racing car'), img('Rocket'), img('Robot'))) : null,
      h('button', {class: 'funbar petbar', onclick: () => { audio.sfx('tap'); go('/pet'); }},
        img(p.pet ? (data.pets.find(x => x.id === p.pet.type) || data.pets[0]).img : 'Paw prints'),
        h('span', {class: 'ft'}, p.pet ? p.pet.name : t('petRoom')), h('span', {class: 'fsub'}, '❤️ ', p.pet ? t('petCare') : t('petAdopt')))),
    // Bé Lớp 1: ô Học cùng lớp lên đầu bản đồ.
    h('div', {class: 'islands'}, (p.tier === 3 ? [...data.islands].sort((a, b) => (b.id === 'lop1') - (a.id === 'lop1')) : data.islands).map(isl => {
      if (isl.route) {
        return h('button', {class: 'island special', style: {'--c': isl.color}, onclick: () => { audio.sfx('tap'); go(isl.route); }},
          img(isl.img), h('span', {class: 'iname'}, L(isl)), h('span', {class: 'prog'}, isl.id === 'room' ? `⭐ ${store.wallet(p)}` : isl.id === 'lop1' ? `Tuần ${classWeek(p)}` : '👨‍👩‍👦'));
      }
      if (isl.soon) {
        return h('button', {class: 'island soon', 'data-soon': t('soon'), style: {'--c': isl.color}, onclick: () => { audio.sfx('pop'); audio.sayPhrase('soon'); }},
          img(isl.img), h('span', {class: 'iname'}, L(isl)));
      }
      const lv = tierLevels(isl, p);
      const total = lv.length;
      const done = lv.filter(l => store.levelStars(p, isl.id, l.i) > 0).length;
      return h('button', {class: `island ${total && done === total ? 'full' : ''}`, style: {'--c': isl.color}, onclick: () => { audio.sfx('tap'); go('/island/' + isl.id); }},
        img(isl.img), h('span', {class: 'iname'}, L(isl)),
        h('span', {class: 'prog'}, h('span', {class: 'ibar'}, h('i', {style: {width: (total ? done / total * 100 : 0) + '%'}})), h('span', {class: 'inum'}, `${done}/${total}`)));
    })),
    installBanner()
  );
  if (!p.tier) chooseTier(p, map);
}

// ---------- Danh sách bài của một đảo ----------
const INTRO = {letters: 'lettersIntro', count: 'countIntro', english: 'englishIntro', memory: 'memoryIntro', spell: 'spellIntro',
  trace: 'traceIntro', math: 'mathIntro', logic: 'logicIntro', music: 'musicIntro', art: 'artIntro', explore: 'exploreIntro',
  read: 'readIntro', life: 'lifeIntro', arcade: 'arcadeIntro', code: 'codeIntro'};

function islandScreen(id) {
  const isl = island(id);
  if (!isl || isl.soon || isl.route) return go('/map');
  const p = store.profile();
  if (!islandScreen.said || islandScreen.said !== id) audio.sayPhrase(INTRO[id]);
  islandScreen.said = id;
  const have = islTiers(isl);
  const cur = tierFor(isl, p);
  const lvls = tierLevels(isl, p, cur);
  const done = lvls.filter(l => store.levelStars(p, id, l.i) > 0).length;
  const firstOpen = lvls.find(l => store.levelStars(p, id, l.i) === 0 && unlocked(p, isl, l.i));
  screen('',
    h('div', {class: 'topbar'}, back('/map'), h('h1', {}, L(isl)), h('span', {class: 'pill'}, img('Glowing star'), p.stars)),
    have.length > 1 ? h('div', {class: 'tiertabs'}, have.map(k => h('button', {class: k === cur ? 'on' : '', style: {'--c': tierOf(k).color}, onclick: () => {
      audio.sfx('tap'); viewTier[id] = k; islandScreen(id);
    }}, img(tierOf(k).img), h('b', {}, L(tierOf(k))), h('span', {}, L(tierOf(k).age))))) : null,
    h('div', {class: 'tierprog', style: {'--c': isl.color}}, h('i', {style: {width: (lvls.length ? done / lvls.length * 100 : 0) + '%'}}), h('span', {}, t('levelsDone', {a: done, b: lvls.length}))),
    h('div', {class: 'levels', style: {'--c': isl.color}}, lvls.map((lv, n) => {
      const stars = store.levelStars(p, id, lv.i);
      const open = unlocked(p, isl, lv.i);
      return h('button', {class: `level ${open ? '' : 'locked'} ${firstOpen === lv ? 'next' : ''} ${stars ? 'done' : ''}`, onclick: () => {
        if (!open) { audio.sfx('wrong'); audio.sayPhrase('locked'); return; }
        audio.sfx('tap'); go(`/play/${id}/${lv.i}`);
      }},
        h('span', {class: 'num'}, open ? (lv.img ? img(lv.img) : n + 1) : '🔒'),
        h('span', {class: 'lname'}, lv.name),
        h('span', {class: 'lstars'}, [0, 1, 2].map(k => k < stars ? h('b', {}, '★') : '★')));
    }))
  );
}

// ---------- Học cùng lớp (đợt 18): lộ trình theo thứ tự bài sách Lớp 1, tự đi theo tuần học ----------
// Tuần hiện tại = tuần bố mẹ đã chọn (p.cls.wk vào ngày p.cls.at) + số tuần đã qua; chưa chọn thì tính từ ngày khai giảng.
const DAY = 864e5;
const ymd = d => d.toISOString().slice(0, 10);
const monday = d => { const x = new Date(d); x.setHours(12, 0, 0, 0); x.setDate(x.getDate() - (x.getDay() + 6) % 7); return x; };
function classWeek(p) {
  const now = monday(new Date());
  const c = p.cls || {};
  const wk = c.wk && c.at ? c.wk + Math.round((now - monday(new Date(c.at + 'T12:00:00'))) / (7 * DAY))
    : 1 + Math.floor((now - monday(new Date(content.kntt.start + 'T12:00:00'))) / (7 * DAY));
  return Math.max(1, Math.min(35, wk));
}
// Mọi "bài" của lộ trình: Tiếng Việt tập 1 (theo bài), tập 2 (theo tuần chủ đề), Toán (theo bài).
function classItems(subj) {
  const k = content.kntt;
  if (subj === 'toan') return k.toan.map(x => ({...x, key: 'toan' + x.b, title: `Bài ${x.b}`, sub: x.name}));
  return [...k.tv.map(x => ({...x, key: 'tv' + x.b, title: `Bài ${x.b}`, sub: x.name})),
    ...k.tv2.map(x => ({...x, key: 'tv2w' + x.wk, title: `Tuần ${x.wk}`, sub: x.name}))];
}
const actDone = (p, a) => store.levelStars(p, a[0], a[1]) > 0;
const itemDone = (p, it) => it.acts.length > 0 && it.acts.every(a => actDone(p, a));
// Sau một hoạt động: hoạt động kế tiếp trong cùng bài, và thưởng khi vừa xong cả bài.
function classDone(p, islId, li) {
  for (const subj of ['tv', 'toan']) {
    const it = classItems(subj).find(x => x.acts.some(a => a[0] === islId && a[1] === li));
    if (!it) continue;
    const next = it.acts.find(a => !actDone(p, a)) || null;
    let reward = null;
    p.cls = p.cls || {};
    p.cls.done = p.cls.done || {};
    if (itemDone(p, it) && !p.cls.done[it.key]) {
      p.cls.done[it.key] = 1;
      if (store.settings().fun) store.addTickets(3);
      store.save();
      reward = `${subj === 'toan' ? 'Toán' : 'Tiếng Việt'} · ${it.title}`;
    }
    return {next, reward};
  }
  return {next: null, reward: null};
}
const actName = a => {
  const isl = island(a[0]);
  const lv = levelsOf(isl)[a[1]];
  return lv ? lv.name.replace(/^Bài \d+: /, '') : L(isl);
};
let classSubj = 'tv', classOpen = {};
function classCard(p, it, now) {
  const done = itemDone(p, it);
  return h('div', {class: `clscard ${done ? 'done' : ''} ${now ? 'now' : ''}`},
    h('div', {class: 'clshead'}, h('b', {}, it.title), h('span', {}, it.sub), done ? h('i', {class: 'clsok'}, '✔') : null),
    it.thin ? h('div', {class: 'clsthin'}, 'Bài này đang soạn thêm từ cho bé luyện.') : null,
    it.stories ? h('div', {class: 'clsnote'}, 'Truyện cùng chủ đề do Bé Vui Học viết.') : null,
    h('div', {class: 'clsacts'}, it.acts.map(a => {
      const isl = island(a[0]);
      const st = store.levelStars(p, a[0], a[1]);
      return h('button', {class: `clsact ${st ? 'ok' : ''}`, style: {'--c': isl.color}, onclick: () => { audio.sfx('tap'); go(`/play/${a[0]}/${a[1]}/lop1`); }},
        img(levelsOf(isl)[a[1]].img || isl.img), h('span', {}, actName(a)), h('em', {}, [0, 1, 2].map(k => k < st ? h('b', {}, '★') : '★')));
    })));
}
function classScreen() {
  const p = store.profile();
  if (!content.kntt) return go('/map');
  const wk = classWeek(p);
  const items = classItems(classSubj);
  const byWk = n => items.filter(x => x.wk === n);
  // Tuần không mở bài mới (bài kéo dài nhiều tuần): bài gần nhất vẫn là bài của tuần này.
  let cur = byWk(wk);
  if (!cur.length) { const last = items.filter(x => x.wk < wk).pop(); if (last && wk !== 18) cur = [last]; }
  const prev = items.filter(x => x.wk <= wk && !cur.includes(x)), next = items.filter(x => x.wk > wk);
  const firstTodo = cur.find(x => x.acts.length && !itemDone(p, x));
  const fold = (id, label, list) => list.length ? h('div', {class: 'clsfold'},
    h('button', {class: 'clsmore', onclick: () => { audio.sfx('tap'); classOpen[id] = !classOpen[id]; classScreen(); }}, (classOpen[id] ? '▾ ' : '▸ ') + label + ` (${list.length})`),
    classOpen[id] ? h('div', {class: 'clslist'}, list.map(it => classCard(p, it, false))) : null) : null;
  screen('cls',
    h('div', {class: 'topbar'}, back('/map'), h('h1', {}, 'Học cùng lớp'), h('span', {class: 'pill'}, img('School'), `Tuần ${wk}`)),
    h('div', {class: 'tiertabs clstabs'}, [['tv', 'Tiếng Việt', 'Open book', '#ff6f91'], ['toan', 'Toán', 'Abacus', '#4dabf7']].map(([id, name, ic, col]) =>
      h('button', {class: id === classSubj ? 'on' : '', style: {'--c': col}, onclick: () => { audio.sfx('tap'); classSubj = id; classScreen(); }}, img(ic), h('b', {}, name)))),
    h('h2', {class: 'clsh'}, `Tuần ${wk} trên lớp`),
    cur.length ? h('div', {class: 'clslist'}, cur.map(it => classCard(p, it, it === firstTodo)))
      : h('div', {class: 'clsnote big'}, wk === 18 || wk > 35 ? 'Tuần này lớp ôn tập. Bé luyện lại các bài cũ ở dưới nhé.' : 'Tuần này lớp học tiếp bài cũ. Bé xem các bài đã qua ở dưới nhé.'),
    fold('prev', 'Bài đã qua: ôn lại', prev.slice().reverse()),
    fold('next', 'Bài sắp tới', next),
    h('div', {class: 'clsfoot'},
      h('p', {}, 'Thứ tự bài theo sách Tiếng Việt 1 và Toán 1 bộ Kết nối tri thức với cuộc sống. Từ ngữ, câu, truyện do Bé Vui Học soạn. Phần luyện âm, vần của mỗi bài chỉ dùng âm, vần, dấu bé đã học tới bài đó.'),
      h('button', {class: 'btn ghost', onclick: async () => { audio.sfx('tap'); if (await gate()) pickClassWeek(p); }}, '👨‍👩‍👦 Lớp của con đang học tuần khác?')));
}
// Bố mẹ chọn tuần lớp đang học; app tự đi tiếp mỗi tuần từ mốc này.
function pickClassWeek(p) {
  const wk = classWeek(p);
  const tv = classItems('tv');
  const label = n => { const xs = tv.filter(x => x.wk === n && !/^Ôn tập/.test(x.sub)); return xs.length ? xs.map(x => x.sub).join(' · ') : n === 18 ? 'Ôn tập cuối học kì 1' : ''; };
  const ov = overlay(
    h('h2', {}, 'Lớp đang học tuần nào?'),
    h('p', {class: 'note'}, 'Chọn tuần có bài cô đang dạy. Mỗi tuần sau app tự chuyển sang bài kế tiếp.'),
    h('div', {class: 'clsweeks'}, Array.from({length: 35}, (_, i) => i + 1).map(n => h('button', {class: n === wk ? 'on' : '', onclick: () => {
      audio.sfx('tap'); p.cls = {...(p.cls || {}), wk: n, at: ymd(monday(new Date()))}; store.save(); ov.remove(); classScreen();
    }}, h('b', {}, `Tuần ${n}`), h('span', {}, label(n))))),
    h('div', {class: 'row'},
      p.cls && p.cls.wk ? h('button', {class: 'btn ghost', onclick: () => { const d = p.cls.done; p.cls = d ? {done: d} : {}; store.save(); ov.remove(); classScreen(); }}, 'Theo lịch năm học') : null,
      h('button', {class: 'btn blue', onclick: () => ov.remove()}, t('cancel'))));
  ov.classList.add('clsov');
}

// ---------- Màn chơi ----------
async function play(id, li, from) {
  const isl = island(id);
  const p = store.profile();
  li = Number(li);
  const home = from === 'lop1' ? '/lop1' : '/island/' + id;
  const total = isl ? levelCount(isl) : 0;
  if (!isl || isl.soon || isl.route || !(li >= 0 && li < total) || !unlocked(p, isl, li)) return go('/map');
  let aborted = false;
  const progressEl = h('div', {class: 'progress'});
  const stage = h('div', {class: 'stage'});
  const unwatch = watchStage(stage);
  leaveGame = () => { aborted = true; unwatch(); audio.stopVoice(); };
  const buddy = dressed(p, 'buddy');
  setPhotoMode(true);
  screen('game', h('div', {class: 'topbar'}, back(home), progressEl, h('span', {class: 'pill'}, img('Glowing star'), p.stars)), stage);
  app.append(buddy);
  const anim = cls => { buddy.classList.remove('cheer', 'sad'); void buddy.offsetWidth; buddy.classList.add(cls); };
  ensureLearn(p);
  const lvData = levelData(isl, li), ns = confNs(isl, lvData);
  const g = {
    stage,
    aborted: () => aborted,
    // Đợt 15: kết quả từng câu (quiz.js gọi) cho Báo cáo bố mẹ và ôn tập ngắt quãng.
    record: (q, picks, ms) => recordQ(isl.id, itemKeys(isl, lvData, q), ns, q, picks, ms),
    buddySrc: src(mascot(p.mascot).img),
    hideBuddy: () => buddy.remove(),
    gate,   // khoá bố mẹ (đọc to: hỏi đồng ý trước lần bật micro đầu)
    cheer: () => anim('cheer'),
    sad: () => anim('sad'),
    progress(i, n) {
      progressEl.replaceChildren(...Array.from({length: n}, (_, k) => h('i', {class: k < i ? 'done' : k === i ? 'now' : ''})));
    }
  };
  const mod = await loadGame(isl.game);
  if (aborted) return;
  const result = await mod.run(g, id, content, li);
  if (aborted || !result) return;
  unwatch();
  leaveGame = null;
  finishRound(isl, li, result.stars, total, from);
}

async function finishRound(isl, li, stars, total, from) {
  setPhotoMode(false);
  const p = store.profile();
  const before = p.stars;
  const sticker = store.recordRound(isl.id, li, stars, data.stickers);
  const dailyDone = store.dailyProgress(isl.id);
  const funOn = store.settings().fun;
  const petHappy = !!p.pet;
  if (petHappy) { p.pet.happy = Math.min(100, (p.pet.happy || 50) + 8); p.pet.xp = (p.pet.xp || 0) + 5; store.save(); }
  if (funOn) store.addTickets(store.settings().ticketsPer + (dailyDone ? 2 : 0));
  const unlocked = data.mascots.filter(m => m.stars > before && m.stars <= p.stars);
  const badges = store.newBadges(BADGES.filter(b => b.test(p)).map(b => b.id)).map(id => BADGES.find(b => b.id === id));
  const ms = checkMilestones(p), due = dueCount(p);
  audio.sfx('win'); confetti();
  audio.sayPhrase('roundDone');
  const starImgs = [0, 1, 2].map(() => img('Star'));
  // Bài tiếp: bài sau trong cùng cấp đang xem.
  const list = tierLevels(isl, p, tierFor(isl, p));
  // Học cùng lớp: "bài tiếp" là hoạt động sau trong cùng bài sách; xong cả bài thì thưởng vé một lần.
  const cls = from === 'lop1' ? classDone(p, isl.id, li) : null;
  const nextPath = cls ? (cls.next ? `/play/${cls.next[0]}/${cls.next[1]}/lop1` : null) : (n => n ? `/play/${isl.id}/${n.i}` : null)(list[list.findIndex(l => l.i === li) + 1]);
  const hasNext = !!nextPath;
  const homePath = cls ? '/lop1' : '/island/' + isl.id;
  const ov = overlay(
    h('h2', {}, t('great')),
    h('div', {class: 'bigstars'}, starImgs),
    sticker ? h('div', {class: 'prize'}, img(sticker), t('newSticker')) : null,
    unlocked.map(m => h('div', {class: 'prize'}, img(m.img), t('newBuddy'), ' ', L(m))),
    dailyDone ? h('div', {class: 'prize'}, img('Fire'), t('daily'), ' ✔ +5 ⭐') : null,
    petHappy ? h('div', {class: 'prize'}, img((data.pets.find(x => x.id === p.pet.type) || data.pets[0]).img), t('petHappyLearn', {name: p.pet.name})) : null,
    funOn ? h('div', {class: 'prize ticket'}, img('Admission tickets'), t('gotTicket', {n: store.settings().ticketsPer + (dailyDone ? 2 : 0)})) : null,
    cls && cls.reward ? h('div', {class: 'prize'}, img('Backpack'), `Xong ${cls.reward}`, funOn ? ' · +3 vé' : '') : null,
    badges.map(b => h('div', {class: 'prize'}, img(b.img), t('badges'), ': ', L(b))),
    ms.map(id => h('button', {class: 'prize msprize', onclick: () => certificate(p, id)}, img(msInfo(id).img), msInfo(id).text, ' 🏅')),
    due >= 3 ? h('button', {class: 'revbtn', onclick: () => { ov.remove(); go('/review'); }}, '🔁 Ôn nhanh ', due, ' chỗ hay nhầm') : null,
    h('div', {class: 'row'},
      h('button', {class: 'btn ghost', onclick: () => { ov.remove(); go(homePath); }}, cls ? '🎒 Bài học' : ['🗺️ ', t('map')]),
      h('button', {class: 'btn blue', onclick: () => { ov.remove(); route(true); }}, '🔄 ', t('again')),
      hasNext ? h('button', {class: 'btn green', onclick: () => { ov.remove(); go(nextPath); }}, t('nextLevel'), ' ➜') : null)
  );
  ov.classList.add('resultov');
  for (let k = 0; k < stars; k++) {
    await wait(380);
    if (!ov.isConnected) return;  // bé đã rời màn: không đọc lời khen trên màn mới
    starImgs[k].classList.add('lit');
    audio.sfx('star');
  }
  await wait(1600);
  if (!ov.isConnected) return;
  if (ms.length) return celebrate(p, ms);
  if (dailyDone) audio.sayPhrase('dailyDone');
  else if (badges.length) audio.sayPhrase('badge');
  else if (unlocked.length) audio.sayPhrase('newMascot');
  else if (sticker) audio.sayPhrase('newSticker');
}

// ---------- Album hình dán ----------
function album() {
  const p = store.profile();
  audio.sayPhrase('album');
  screen('',
    h('div', {class: 'topbar'}, back('/map'), h('h1', {}, t('albumTitle')), h('span', {class: 'pill'}, `${p.stickers.length}/${data.stickers.length}`)),
    h('div', {class: 'album'}, data.stickers.map(s => {
      const have = p.stickers.includes(s);
      return h('button', {class: `sticker ${have ? '' : 'missing'}`, onclick: () => audio.sfx(have ? 'pop' : 'tap')}, img(s));
    })),
    h('h2', {class: 'title', style: {margin: '22px 0 10px'}}, '🏅 ', t('badges')),
    h('div', {class: 'badges'}, BADGES.map(b => {
      const have = (p.badges || []).includes(b.id);
      return h('div', {class: `badge ${have ? '' : 'missing'}`}, img(b.img), h('span', {}, L(b)));
    }))
  );
}

// ---------- Đổi linh vật ----------
function buddies() {
  const p = store.profile();
  const grid = h('div', {class: 'mascots'}, data.mascots.map(m => {
    const open = p.stars >= m.stars;
    const b = h('button', {class: `mascot ${open ? '' : 'locked'} ${p.mascot === m.id ? 'on' : ''}`, onclick: () => {
      if (!open) { audio.sfx('wrong'); audio.sayPhrase('needStars'); return; }
      store.updateProfile(p.id, {mascot: m.id});
      grid.querySelectorAll('.on').forEach(x => x.classList.remove('on'));
      b.classList.add('on');
      audio.sfx('pop');
      audio.say(audio.tpl(lang() === 'en' ? 'mascotEn' : 'mascotVi', m));
    }}, img(m.img), L(m), open ? null : h('span', {class: 'need'}, '⭐', m.stars));
    return b;
  }));
  screen('',
    h('div', {class: 'topbar'}, back('/map'), h('h1', {}, t('buddies')), h('span', {class: 'pill'}, img('Glowing star'), p.stars)),
    grid
  );
}

// ---------- Khoá bố mẹ: phép nhân bé 5 tuổi chưa làm được ----------
function gate() {
  return new Promise(resolve => {
    const a = 3 + Math.floor(Math.random() * 7), b = 3 + Math.floor(Math.random() * 7);
    let typed = '';
    const ans = h('div', {class: 'ans'}, '?');
    const done = ok => { ov.remove(); resolve(ok); };
    const press = k => {
      audio.sfx('tap');
      if (k === '⌫') typed = typed.slice(0, -1);
      else if (k === 'OK') { if (Number(typed) === a * b) return done(true); typed = ''; toast('✖'); }
      else if (typed.length < 3) typed += k;
      ans.textContent = typed || '?';
    };
    const ov = overlay(
      h('h2', {}, t('gateTitle')),
      h('p', {class: 'note'}, t('gateHint')),
      h('div', {class: 'q'}, `${a} × ${b} = ?`),
      ans,
      h('div', {class: 'keypad'}, ['1', '2', '3', '4', '5', '6', '7', '8', '9', '⌫', '0', 'OK'].map(k =>
        h('button', {class: k === 'OK' ? 'ok' : '', onclick: () => press(k)}, k))),
      h('div', {class: 'row'}, h('button', {class: 'btn ghost', onclick: () => done(false)}, t('cancel')))
    );
  });
}

function parentBtn() {
  // Có chữ "Bố mẹ" cạnh bánh răng: chỉ icon thì phụ huynh không biết là nút cài đặt
  return h('button', {class: 'icon-btn parentbtn', 'aria-label': t('parentArea'), onclick: async () => {
    audio.sfx('tap');
    if (await gate()) go('/parent');
  }}, icon('gear'), h('span', {}, t('parentShort')));
}

// ---------- Góc bố mẹ ----------
// Đợt 18: dùng trên nhiều máy bằng mã gia đình (không tài khoản). Dữ liệu mã hoá trên máy trước khi gửi.
function syncCard() {
  if (!sync.supported()) return null;
  const c = sync.code();
  const when = sync.lastAt() ? new Date(sync.lastAt()).toLocaleString('vi-VN', {hour: '2-digit', minute: '2-digit', day: '2-digit', month: '2-digit'}) : '—';
  const err = sync.lastErr();
  const msg = r => toast(r === 'ok' ? '✔ Đã đồng bộ' : r === 'notfound' ? 'Không tìm thấy mã này' : r === 'bad' ? 'Mã gồm 16 chữ và số' : 'Chưa kết nối được, thử lại sau');
  const codeEl = h('b', {class: 'synccode'}, c ? '••••-••••-••••-' + c.slice(-4) : '');
  return h('div', {class: 'card section sync'},
    h('h3', {}, '📱 Dùng trên nhiều máy'),
    c ? [
      h('p', {class: 'note'}, 'Máy này đang đồng bộ. Nhập mã gia đình trên máy khác (điện thoại, iPad) để bé học tiếp đúng chỗ.'),
      h('div', {class: 'syncrow'}, codeEl, h('button', {class: 'small-btn', onclick: () => { codeEl.textContent = sync.code(); }}, '👁 Hiện mã')),
      h('p', {class: 'note'}, 'Lần đồng bộ gần nhất: ', when, err ? ` · lần cuối lỗi (${err === 'offline' ? 'mất mạng' : 'máy chủ'})` : ''),
      h('div', {class: 'row', style: {justifyContent: 'flex-start'}},
        h('button', {class: 'small-btn', onclick: async () => { msg(await sync.syncNow()); parent(); }}, '🔄 Đồng bộ ngay'),
        h('button', {class: 'small-btn', onclick: async () => { if (confirm('Ngắt máy này khỏi mã gia đình? Dữ liệu trên máy này vẫn giữ.')) { await sync.leave(false); parent(); } }}, 'Ngắt máy này'),
        h('button', {class: 'small-btn danger', onclick: async () => { if (confirm('Xoá bản đồng bộ trên máy chủ? Các máy khác sẽ không nhận dữ liệu mới nữa (dữ liệu trên từng máy vẫn giữ).')) { await sync.leave(true); parent(); } }}, 'Xoá bản trên máy chủ'))
    ] : [
      h('p', {class: 'note'}, 'Bé học trên nhiều máy? Bật đồng bộ để sao, bài đã học, đồ trong game đi theo bé. Không cần email hay mật khẩu: app tạo một mã gia đình 16 ký tự. Dữ liệu được mã hoá ngay trên máy bằng mã này rồi mới gửi lên máy chủ datpilot.com, nên máy chủ không đọc được. Giữ mã như giữ chìa khoá nhà.'),
      h('div', {class: 'row', style: {justifyContent: 'flex-start'}},
        h('button', {class: 'small-btn', onclick: async () => { const r = await sync.create(); msg(r); parent(); }}, '✨ Tạo mã gia đình'),
        h('button', {class: 'small-btn', onclick: async () => {
          const v = prompt('Nhập mã gia đình (16 chữ và số, lấy ở Góc bố mẹ trên máy đã bật đồng bộ):');
          if (v) { const r = await sync.join(v); msg(r); if (r === 'ok' && !store.profile() && store.profiles().length) store.setActive(store.profiles()[0].id); parent(); }
        }}, '🔑 Nhập mã từ máy khác'))
    ]);
}

function seg(options, value, onPick) {
  const el = h('div', {class: 'seg'});
  for (const [v, label] of options) {
    el.append(h('button', {class: v === value ? 'on' : '', onclick: () => { audio.sfx('tap'); onPick(v); }}, label));
  }
  return el;
}

function weekBars(p) {
  const days = [];
  for (let k = 6; k >= 0; k--) {
    const d = new Date(Date.now() - k * 864e5);
    const key = store.dayKey(d);
    days.push([d.getDate(), Math.round((p.usage[key] || 0) / 60)]);
  }
  const max = Math.max(10, ...days.map(x => x[1]));
  return h('div', {class: 'bars'}, days.map(([d, m]) => h('span', {'data-d': d, title: `${m}′`, style: {height: (m / max * 100) + '%'}})));
}

function parent() {
  const s = store.settings();
  const set = (k, v) => { store.setSetting(k, v); if (k === 'music') audio.music(); parent(); };
  const fileIn = h('input', {type: 'file', accept: 'application/json,.json', style: {display: 'none'}, onchange: async () => {
    const f = fileIn.files[0];
    if (!f) return;
    try { store.importData(await f.text()); toast(t('restored')); parent(); } catch (e) { toast(t('badFile')); }
  }});
  const doneLevels = p => Object.values(p.levels).filter(x => x > 0).length;
  const totalLevels = data.islands.filter(i => !i.soon && !i.route).reduce((n, i) => n + levelCount(i), 0);
  screen('parent',
    h('div', {class: 'topbar'}, back(store.profile() ? '/map' : '/kids'), h('h1', {}, t('parentArea')), h('span', {class: 'spacer'})),
    h('div', {class: 'card section'},
      h('h3', {}, t('settings')),
      h('div', {class: 'opt'}, t('language'), seg([['vi', 'Tiếng Việt'], ['en', 'English']], s.lang, v => { set('lang', v); document.documentElement.lang = v; })),
      h('div', {class: 'opt'}, t('music'), seg([[true, t('on')], [false, t('off')]], s.music, v => set('music', v))),
      h('div', {class: 'opt'}, t('sound'), seg([[true, t('on')], [false, t('off')]], s.sound, v => set('sound', v))),
      h('div', {class: 'opt'}, t('limit'), seg([[0, t('off')], [15, '15′'], [20, '20′'], [30, '30′'], [45, '45′']], s.limit, v => set('limit', v))),
      h('div', {class: 'opt'}, t('lockOrder'), seg([[true, t('on')], [false, t('off')]], s.lockOrder, v => set('lockOrder', v))),
      h('div', {class: 'opt'}, t('funZone'), seg([[true, t('on')], [false, t('off')]], s.fun, v => set('fun', v))),
      h('div', {class: 'opt'}, t('ticketsPer'), seg([[1, '1 🎟️'], [2, '2 🎟️']], s.ticketsPer, v => set('ticketsPer', v))),
      h('div', {class: 'opt'}, t('giveTickets'), h('div', {style: {display: 'flex', gap: '8px', flexWrap: 'wrap'}},
        store.profiles().map(k => h('button', {class: 'small-btn', onclick: () => {
          const cur = store.profile(); store.setActive(k.id); store.addTickets(3); if (cur) store.setActive(cur.id);
          toast(`${k.name} +3 🎟️`); parent();
        }}, `${k.name} (🎟️ ${store.tickets(k)}) +3`))))
    ),
    h('div', {class: 'card section'},
      h('h3', {}, t('kids')),
      store.profiles().map(p => h('div', {class: 'kidstat'},
        img(mascot(p.mascot).img),
        h('div', {class: 'info'},
          h('b', {}, p.name),
          h('div', {class: 'meta'}, `⭐ ${p.stars} · ${t('levelsDone', {a: doneLevels(p), b: totalLevels})} · ${t('rounds', {n: p.rounds})} · ${t('today', {n: Math.round((p.usage[store.today()] || 0) / 60)})}`),
          weekBars(p)),
        h('div', {style: {display: 'flex', gap: '8px', flexWrap: 'wrap'}},
          h('button', {class: 'small-btn rp-open', onclick: () => { audio.sfx('tap'); go('/report/' + p.id); }}, '📊 Báo cáo của con'),
          h('button', {class: 'small-btn', onclick: () => chooseTier(p, parent)}, '🌱 ', t('tier'), ': ', L(tierOf(p.tier))),
          h('button', {class: 'small-btn', onclick: () => {
            const n = (prompt(t('newName'), p.name) || '').trim().slice(0, 20);
            if (n) { store.updateProfile(p.id, {name: n}); parent(); }
          }}, t('rename')),
          h('button', {class: 'small-btn danger', onclick: () => {
            if (confirm(t('confirmRemove', {name: p.name}))) { store.removeProfile(p.id); parent(); }
          }}, t('remove')))
      )),
      h('div', {class: 'row', style: {justifyContent: 'flex-start'}}, h('button', {class: 'small-btn', onclick: () => go('/new')}, '+ ', t('addKid')))
    ),
    h('div', {class: 'card section'},
      h('h3', {}, t('backup')),
      h('p', {class: 'note'}, t('backupNote')),
      h('div', {class: 'row', style: {justifyContent: 'flex-start'}},
        h('button', {class: 'small-btn', onclick: () => {
          const blob = new Blob([store.exportData()], {type: 'application/json'});
          const a = h('a', {href: URL.createObjectURL(blob), download: `be-vui-hoc-${store.today()}.json`});
          document.body.append(a); a.click(); a.remove();
        }}, '⬇️ ', t('download')),
        h('button', {class: 'small-btn', onclick: () => fileIn.click()}, '⬆️ ', t('restore')),
        fileIn)
    ),
    syncCard(),
    h('div', {class: 'card section'},
      h('h3', {}, '💬 Góp ý, báo lỗi'),
      h('p', {class: 'note'}, 'App không tự gửi lỗi về. Bố mẹ thấy bài sai, game lỗi hay muốn thêm bài gì thì nhắn Zalo DatPilot 0888 998 098 (ghi máy đang dùng, ví dụ iPad, Android).'),
      h('div', {class: 'row', style: {justifyContent: 'flex-start'}},
        h('a', {class: 'small-btn', href: 'https://zalo.me/0888998098', target: '_blank', rel: 'noopener'}, '💬 Nhắn Zalo'),
        h('a', {class: 'small-btn', href: '/be-vui-hoc', target: '_blank', rel: 'noopener'}, 'ℹ️ Giới thiệu'),
        h('button', {class: 'small-btn', onclick: () => {
          try { localStorage.removeItem('bvh.micOK'); } catch (e) { /* bỏ qua */ }
          toast('Lần sau bé bấm 🎤 app sẽ hỏi lại bố mẹ');
        }}, '🎤 Hỏi lại về micro'))
    ),
    shareCard(),
    h('div', {class: 'card section cafe'},
      h('h3', {}, '☕ Ủng hộ một ly cà phê'),
      h('p', {class: 'note'}, 'Bé Vui Học miễn phí, không quảng cáo. Nếu app có ích cho bé, bố mẹ có thể mời người làm app một ly cà phê để có thêm bài học mới. Không bắt buộc, bé vẫn học đầy đủ.'),
      h('details', {ontoggle: e => { if (e.target.open) cafeSeen(); }}, h('summary', {class: 'small-btn'}, '☕ Xem mã QR'),
        h('img', {src: 'ungho.webp?v=' + window.BVH_VERSION, alt: 'Mã QR chuyển khoản Techcombank, BUI VAN DAT, 1903 4632 8620 19', width: 417, height: 440, class: 'cafeqr'}),
        h('div', {class: 'row', style: {justifyContent: 'flex-start'}},
          h('button', {class: 'small-btn', onclick: saveQR}, '📥 Lưu ảnh QR'),
          h('button', {class: 'small-btn', onclick: () => copyText('19034632862019', 'Đã chép số tài khoản')}, '📋 Chép số tài khoản')),
        h('p', {class: 'note'}, 'Techcombank · BUI VAN DAT · 1903 4632 8620 19. Lưu ảnh rồi mở app ngân hàng, chọn quét QR từ ảnh. Trên iPhone, iPad cũng có thể nhấn giữ vào mã để lưu.'))
    ),
    h('div', {class: 'card section'},
      h('h3', {}, t('credits')),
      h('p', {class: 'note'}, t('creditsNote', {n: Object.keys(photos).length})),
      h('details', {class: 'credits'}, h('summary', {}, t('creditsShow')),
        h('ul', {}, Object.entries(photos).map(([k, c]) => h('li', {}, h('b', {}, k), ' — ', c.by || '?', ' — ', c.lic, ' — ',
          h('a', {href: c.src, target: '_blank', rel: 'noopener'}, 'Wikimedia Commons')))),
        h('p', {class: 'note'}, t('creditsSfx'), ' ', h('a', {href: 'sfx/CREDITS.txt', target: '_blank'}, 'sfx/CREDITS.txt')))
    ),
    h('div', {class: 'card section'},
      h('h3', {}, t('install')),
      h('p', {class: 'note'}, t('installWhy')),
      h('ol', {class: 'steps'}, t('installSteps').map(x => h('li', {}, x))),
      h('p', {class: 'note'}, `${t('version')} ${window.BVH_VERSION}`)
    )
  );
}

// ---------- Phòng của bé: mua và đeo đồ cho linh vật ----------
const SLOTS = [['hat', '🎩'], ['eyes', '🕶️'], ['hand', '🎈'], ['bg', '🖼️']];
let roomSlot = 'hat';
function room() {
  const p = store.profile();
  const owned = new Set(p.owned || []);
  const o = p.outfit || {};
  const render = () => room();
  screen('room',
    h('div', {class: 'topbar'}, back('/map'), h('h1', {}, L(island('room'))), h('span', {class: 'pill'}, img('Glowing star'), store.wallet(p))),
    h('div', {class: 'roomwrap'},
      h('div', {class: 'stagebox'}, dressed(p, 'big')),
      h('div', {class: 'shopbox'},
        h('div', {class: 'seg'}, SLOTS.map(([k, ic]) => h('button', {class: k === roomSlot ? 'on' : '', onclick: () => { roomSlot = k; audio.sfx('tap'); render(); }}, ic))),
        h('div', {class: 'wardrobe'}, data.wardrobe.filter(w => w.slot === roomSlot).map(w => {
          const have = owned.has(w.id), on = o[w.slot] === w.id;
          return h('button', {class: `ward ${have ? 'have' : ''} ${on ? 'on' : ''}`, onclick: () => {
            if (have) { store.equip(w.slot, on ? null : w.id); audio.sfx('pop'); return render(); }
            if (store.buy(w)) { audio.sfx('win'); confetti(30); audio.sayPhrase('buyOk'); return render(); }
            audio.sfx('wrong'); audio.sayPhrase('needMore');
          }}, img(w.img), h('span', {class: 'wname'}, w.vi), have ? h('span', {class: 'wtag'}, on ? '✔' : t('wear')) : h('span', {class: 'wprice'}, '⭐ ', w.price));
        })))));
}

// ---------- Khu vui chơi ----------
// Bố mẹ (qua khoá phép tính) được chơi không cần vé; không đổi cấp và kỷ lục của bé.
let parentFun = false;
async function funZone() {
  const p = store.profile();
  const [{FUN_GAMES}, F] = await Promise.all([loadGame('fun'), applyLook(p)]);
  if (location.hash !== '#/fun') return;  // đã rời màn trong lúc tải
  if (!funZone.said) { audio.sayPhrase('funIntro'); funZone.said = true; }
  const rpgCard = h('button', {class: 'fungame rpgcard', style: {'--c': '#7048e8'}, onclick: () => { audio.sfx('tap'); go('/rpg'); }},
    img('Crossed swords'), h('b', {}, 'Thế giới phiêu lưu'),
    h('span', {}, 'Nhập vai · Cấp ', (p.rpg && p.rpg.lv) || 1));
  // Mở công khai: hiện hết game, không gập; mỗi nhóm lấp kín hàng cuối (fillGrid) để không trống chỗ.
  const groups = [[t('funHot'), [rpgCard, ...FUN_GAMES.filter(gm => gm.hot).map(funCard)]],
    ...[['action', t('funAction')], ['vs', t('funVs')], ['casual', t('funCasual')], ['brain', t('funBrain')]].map(([kind, title]) =>
      [title, FUN_GAMES.filter(gm => gm.kind === kind && !gm.hot).map(funCard)])];
  const el = screen('funzone',
    h('div', {class: 'topbar'}, back('/map'), h('h1', {}, t('funZone')), h('span', {class: 'pill'}, img('Admission tickets'), store.tickets(p))),
    h('p', {class: 'note', style: {textAlign: 'center', fontWeight: 700}}, t('funHow')),
    lookCard(p, F),
    parentFun
      ? h('div', {class: 'parentfun on'}, '👨‍👩‍👦 ', t('parentFunOn'), h('button', {class: 'small-btn', onclick: () => { parentFun = false; funZone(); }}, t('exitParent')))
      : h('div', {class: 'parentfun'}, h('button', {class: 'small-btn', onclick: async () => { if (await gate()) { parentFun = true; funZone(); } }}, '👨‍👩‍👦 ', t('parentPlay'))),
    groups.filter(([, cards]) => cards.length).map(([title, cards], i) => [h('h2', {class: 'title funsec'}, title), h('div', {class: i ? 'fungames' : 'fungames hot'}, cards)])
  );
  fillGrids(el);
  function funCard(gm) {
    return h('button', {class: 'fungame', style: {'--c': gm.color}, onclick: () => {
      if (!parentFun && store.tickets(p) <= 0) { audio.sfx('wrong'); audio.sayPhrase('noTicket'); toast(t('noTicket')); return; }
      audio.sfx('tap'); go('/fun/' + gm.id);
    }}, img(gm.img), h('b', {}, L(gm)),
      h('span', {}, gm.levels ? `${t('level')} ${store.funLevel(p, gm.id) + 1}/${store.FUN_MAX} · ` : '', '🏆 ', (p.best || {})[gm.id] || 0));
  }
}

async function funPlay(id) {
  const p = store.profile();
  const [{FUN_GAMES}] = await Promise.all([loadGame('fun'), applyLook(p)]);
  if (location.hash !== '#/fun/' + id) return;  // bé đã rời màn trong lúc tải code game
  const gm = FUN_GAMES.find(x => x.id === id);
  if (!gm || !store.settings().fun) return go('/map');
  const free = parentFun;
  if (!free && !store.useTicket()) { audio.sayPhrase('noTicket'); return go('/fun'); }
  let alive = true;
  leaveGame = () => { alive = false; };
  const box = h('div', {class: 'funbox'});
  screen('funplay', h('button', {class: 'icon-btn funquit', 'aria-label': t('close'), onclick: () => location.hash === '#/fun' ? route() : go('/fun')}, icon('close')), box);
  await wait(50);
  const res = await gm.run(box, {hero: mascot(p.mascot).img, alive: () => alive, level: store.funLevel(p, id), content,
    levelUp: () => { if (!free) store.funLevelUp(id); },
    carry: store.gear(p, id), saveGear: c => { if (!free) store.saveGear(id, c); }});
  if (!alive || !res) return;
  leaveGame = null;
  const rec = free || res.pvp ? false : store.saveBest(id, res.score);
  audio.sfx('win'); if (res.win || rec) confetti();
  audio.sayPhrase(rec ? 'newRecord' : res.win ? 'youWin' : 'gameOver');
  const ov = overlay(
    h('h2', {}, res.title ? res.title : res.pos ? (res.pos === 1 ? '🏆 ' + t('first') : `🏁 ${t('place', {n: res.pos})}`) : res.win ? '🏆 ' + t('youWin') : t('gameOver')),
    h('div', {class: 'funscore'}, img('Coin'), res.score),
    res.lvUp && !free ? h('div', {class: 'prize'}, img('Glowing star'), `+${res.ups || 1} ${t('level').toLowerCase()} → ${t('level')} ${store.funLevel(store.profile(), id) + 1}/${store.FUN_MAX}`) : null,
    rec ? h('div', {class: 'prize'}, img('Trophy'), t('newRecord')) : h('p', {class: 'note'}, '🏆 ', (p.best || {})[id] || 0),
    h('div', {class: 'row'},
      h('button', {class: 'btn ghost', onclick: () => { ov.remove(); go('/fun'); }}, '🎮 ', t('funZone')),
      free || store.tickets(p) > 0
        ? h('button', {class: 'btn blue', onclick: () => { ov.remove(); route(); }}, res.lvUp ? '▶ ' : '🔄 ', t(res.lvUp ? 'nextLv' : 'again'), free ? '' : ' (🎟️ 1)')
        : h('button', {class: 'btn green', onclick: () => { ov.remove(); go('/map'); }}, '📚 ', t('learnMore')))
  );
  ov.classList.add('resultov');
}

// Thẻ "Nhân vật của bé" ở đầu Khu vui chơi: bé trai / bé gái, màu áo, mũ. Mặc định theo linh vật (chưa có p.look).
function lookCard(p, F) {
  const card = h('div', {class: 'lookcard card'});
  const cur = () => store.profile().look || {base: F.costumeOf(mascot(p.mascot).img).base === 'girl' ? 'girl' : 'boy'};
  const pick = fields => {
    audio.sfx('tap');
    const look = {...cur(), ...fields};
    store.updateProfile(p.id, {look});
    F.setPlayer(mascot(p.mascot).img, look);
    render();
  };
  function render() {
    const lk = cur();
    const prev = F.figureEl(F.lookOf(lk), {size: 120, pose: 'cheer', cls: 'lookfig'});
    card.replaceChildren(
      prev,
      h('div', {class: 'lookopts'},
        h('b', {}, 'Nhân vật của ', store.profile().name),
        h('div', {class: 'seg lookbase'},
          h('button', {class: lk.base === 'boy' ? 'on' : '', 'data-base': 'boy', onclick: () => pick({base: 'boy'})}, '👦 Bé trai'),
          h('button', {class: lk.base === 'girl' ? 'on' : '', 'data-base': 'girl', onclick: () => pick({base: 'girl'})}, '👧 Bé gái')),
        h('div', {class: 'lookrow'}, F.LOOK_SHIRTS.map(c => h('button', {class: 'swatch' + ((F.lookOf(lk).shirt === c) ? ' on' : ''),
          style: {background: c}, 'aria-label': 'Màu áo ' + c, onclick: () => pick({shirt: c})}))),
        h('div', {class: 'lookrow'}, F.LOOK_HATS.map(hat => h('button', {class: 'hatbtn' + ((lk.hat || null) === hat ? ' on' : ''),
          'aria-label': hat || 'Không đội mũ', onclick: () => pick({hat})}, hat ? img(hat, {photo: false}) : '✖')))));
  }
  render();
  return card;
}

// Lưới game: hàng cuối thiếu thì kéo dài thẻ cuối cho kín hàng (số cột thay đổi theo cỡ màn).
function fillGrids(root) {
  const run = () => {
    if (!root.isConnected) return window.removeEventListener('resize', run);
    for (const g of root.querySelectorAll('.fungames')) {
      const kids = [...g.children];
      kids.forEach(k => { k.style.gridColumn = ''; k.classList.remove('wide'); });
      const cols = getComputedStyle(g).gridTemplateColumns.split(' ').filter(Boolean).length;
      const r = kids.length % cols;
      if (cols > 1 && r) { const last = kids[kids.length - 1]; last.style.gridColumn = `span ${cols - r + 1}`; last.classList.add('wide'); }
    }
  };
  run();
  window.addEventListener('resize', run);
}

// Nhân vật bé chọn (p.look: bé trai/bé gái, màu áo, mũ) áp cho mọi game có nhân vật của bé.
async function applyLook(p) {
  const F = await loadGame('figure');
  F.setPlayer(mascot(p.mascot).img, p.look);
  return F;
}

// ---------- Thế giới phiêu lưu (nhập vai) ----------
const rpgCtx = el => ({el, go, back, heroImg: mascot(store.profile().mascot).img, free: parentFun, tickets: () => store.tickets(store.profile())});
async function rpgTown() {
  const el = screen('rpgscreen');
  const [R] = await Promise.all([loadGame('rpg'), applyLook(store.profile())]);
  R.town(rpgCtx(el));
}
async function rpgPlay(r, s) {
  const p = store.profile();
  const [R] = await Promise.all([loadGame('rpg'), applyLook(p)]);
  if (location.hash !== `#/rpg/${r}/${s}`) return;  // bé đã rời màn trong lúc tải
  const free = parentFun;
  if (!free && !R.canPlay(p, r, s)) return go('/rpg');
  if (!free && !store.useTicket()) { audio.sayPhrase('noTicket'); return go('/rpg'); }
  let alive = true;
  leaveGame = () => { alive = false; };
  const box = h('div', {class: 'funbox'});
  screen('funplay', h('button', {class: 'icon-btn funquit', 'aria-label': t('close'), onclick: () => location.hash === '#/rpg' ? route() : go('/rpg')}, icon('close')), box);
  await wait(50);
  const res = await R.playStage({box, r, s, heroImg: mascot(p.mascot).img, alive: () => alive, free});
  if (!alive || !res) return;
  leaveGame = null;
  R.resultPanel(res, {...rpgCtx(null), onNext: (nr, ns) => { const hs = `#/rpg/${nr}/${ns}`; if (location.hash === hs) route(); else location.hash = hs; }});
}

// ---------- Phòng thú cưng ----------
async function petRoom() {
  const el = screen('petscreen');
  const {petScreen} = await loadGame('pet');
  petScreen(el, {data, onExit: () => { audio.sayPhrase('petWash'); go('/map'); }});
}

// ---------- Bố con thi tài ----------
async function duelScreen() {
  const p = store.profile();
  const el = screen('duel-screen');
  const {duel} = await loadGame('duel');
  duel(el, {content, kidImg: mascot(p.mascot).img, kidName: p.name, onExit: () => go('/map')});
}

// ---------- Nghỉ mắt ----------
function rest() {
  audio.sayPhrase('rest');
  screen('rest',
    img('Sleeping face', {class: 'zz'}),
    h('h1', {class: 'title'}, t('restTitle')),
    h('p', {style: {maxWidth: '520px', margin: 0, fontWeight: 600}}, t('restText')),
    img('Glass of milk', {style: {width: '90px'}}),
    h('button', {class: 'btn ghost', onclick: async () => {
      if (await gate()) { store.addBonus(10); go('/map'); }
    }}, '⏱️ ', t('moreTime'))
  );
}

// ---------- Banner hướng dẫn cài lên màn hình chính (iPad/iPhone) ----------
function installBanner() {
  let hidden = false;
  try { hidden = sessionStorage.getItem('bvh.noinstall') === '1'; } catch (e) { /* bỏ qua */ }
  if (!isIOS() || isStandalone() || hidden) return null;
  const el = h('div', {class: 'install'},
    h('b', {}, '📲'), h('span', {}, t('installBanner')),
    h('button', {class: 'small-btn', onclick: () => {
      const ov = overlay(h('h2', {}, t('install')), h('p', {class: 'note'}, t('installWhy')),
        h('ol', {class: 'steps'}, t('installSteps').map(x => h('li', {}, x))),
        h('div', {class: 'row'}, h('button', {class: 'btn', onclick: () => ov.remove()}, t('gotIt'))));
    }}, '?'),
    h('button', {class: 'x', 'aria-label': t('close'), onclick: () => {
      try { sessionStorage.setItem('bvh.noinstall', '1'); } catch (e) { /* bỏ qua */ }
      el.remove();
    }}, '✕'));
  return el;
}

// ======================= Đợt 15: Báo cáo của con, ôn tập thông minh, mốc tiến bộ, bằng khen =======================
// Mỗi câu hỏi của khuôn runQuiz gọi g.record(q, các lựa chọn sai, ms). Câu được quy về "mục" (tiếng, chữ cái, phép tính,
// từ tiếng Anh...) bằng cách tra ngược câu đọc trong voice.json (template có 'for' trỏ vào bộ dữ liệu), nên không phải sửa khuôn.
let voiceData = null, revIdx = null;
const REV_SETS = ['vnwords', 'twoWords', 'sentences', 'ruleWords', 'addFacts', 'subFacts', 'add100', 'sub100', 'add2d', 'sub2d'];
const FACT_SETS = ['addFacts', 'subFacts', 'add100', 'sub100', 'add2d', 'sub2d'];
const itemId = (it, i) => it.id ?? it.ch ?? (it.a != null && it.b != null ? `${it.a},${it.b}` : i);
const splitKey = k => { const i = k.indexOf(':'); return [k.slice(0, i), k.slice(i + 1)]; };
function revIndex() {
  if (revIdx || !voiceData || !content) return revIdx || new Map();
  revIdx = new Map();
  for (const set of REV_SETS) {
    const arr = content[set] || [];
    for (const tp of Object.values(voiceData.templates)) {
      if (!(tp.for || []).includes(set)) continue;
      arr.forEach((it, i) => {
        const k = tp.lang + '|' + tp.text.replace(/\{(\w+)\}/g, (_, f) => it[f] ?? '');
        if (!revIdx.has(k)) revIdx.set(k, `${set}:${itemId(it, i)}`);
      });
    }
  }
  return revIdx;
}
const lookup = say => Array.isArray(say) ? revIndex().get(say.join('|')) : null;
function itemOf(key) {
  const [set, id] = splitKey(key);
  if (set === 'tone') return {set, label: id === 'ngang' ? 'không dấu' : 'dấu ' + id};
  if (set === 'letters') { const l = content.letters.find(x => x.ch === id); return l && {set, label: id, img: l.img, it: l}; }
  const arr = content[set];
  if (!Array.isArray(arr)) return null;
  const k = arr.findIndex((x, i) => String(itemId(x, i)) === id);
  if (k < 0) return null;
  const it = arr[k];
  const label = it.w ?? it.t ?? it.en ?? (it.a != null ? `${it.a} ${set.startsWith('sub') ? '−' : '+'} ${it.b}` : id);
  return {set, label, img: it.img, it};
}
const skillOfSet = set => set === 'letters' ? 'letters' : set.startsWith('en_') ? 'english' : FACT_SETS.includes(set) ? 'math' : 'spell';

// Hồ sơ cũ chưa có p.learn: tạo, ghi ngày bắt đầu theo dõi, đánh dấu sẵn các đảo đã xong (không ăn mừng lại chuyện cũ).
function ensureLearn(p) {
  const l = store.learn(p);
  if (!l.since) {
    l.since = store.today();
    for (const id of milestoneIds(p)) if (!l.ms.includes(id)) { l.ms.push(id); l.msAt[id] = l.since; }
    store.save();
  }
  return l;
}

function itemKeys(isl, lv, q) {
  const keys = [];
  if (isl.id === 'letters') keys.push('letters:' + q.answer);
  else if (isl.id === 'english' && lv && lv.set) keys.push(lv.set + ':' + q.answer);
  else { const k = lookup(q.say) || lookup(q.reward); if (k) keys.push(k); }
  if (isl.id === 'spell' && lv && lv.kind === 'tone') keys.push('tone:' + q.answer);
  return keys;
}
// Loại cặp nhầm (để báo "con hay nhầm b/d", "dấu hỏi/ngã"). Khuôn chọn hình (id vô nghĩa) thì không ghi.
function confNs(isl, lv) {
  if (isl.id === 'letters') return 'letters';
  if (isl.id === 'english') return lv && lv.set;
  if (isl.id === 'spell' && lv) return lv.kind === 'tone' ? 'tone' : ['onset', 'rime', 'build', 'rule'].includes(lv.kind) ? 'spell' : null;
  return null;
}
function recordQ(skill, keys, ns, q, picks, ms) {
  const ok = !picks.length;
  const conf = ns ? [...new Set(picks)].filter(x => x !== q.answer && (typeof x === 'string' || typeof x === 'number')).map(x => `${ns}|${q.answer}|${x}`) : [];
  store.recordAnswer(skill, keys, ok, conf, ms);
}
function levelData(isl, li) {
  const key = isl.id === 'letters' ? 'letterLevels' : isl.id === 'english' ? 'englishLevels' : LEVEL_KEY[isl.game];
  return (content[key] || [])[li];
}

// ---------- Mốc tiến bộ ----------
const MS_STEPS = {w: [10, 25, 50, 100], e: [10, 25, 50, 100], m: [20, 50, 100]};
function masteredCount(p, test) {
  const items = store.learn(p).items;
  let n = 0;
  for (const k in items) if (items[k][4] && test(k)) n++;
  return n;
}
const isEn = k => k.startsWith('en_'), isFact = k => FACT_SETS.includes(splitKey(k)[0]);
function milestoneIds(p) {
  const out = [];
  const w = masteredCount(p, k => k.startsWith('vnwords:')), l = masteredCount(p, k => k.startsWith('letters:'));
  const e = masteredCount(p, isEn), m = masteredCount(p, isFact);
  for (const n of MS_STEPS.w) if (w >= n) out.push('w' + n);
  for (const n of MS_STEPS.e) if (e >= n) out.push('e' + n);
  for (const n of MS_STEPS.m) if (m >= n) out.push('m' + n);
  if (l >= 10) out.push('l10');
  if (l >= content.letters.length) out.push('lall');
  for (const isl of gameIslands()) {
    const tier = tierFor(isl, p);
    const lv = tierLevels(isl, p, tier);
    if (lv.length && lv.every(x => store.levelStars(p, isl.id, x.i) > 0)) out.push(`i:${isl.id}:${tier}`);
  }
  return out;
}
function msInfo(id) {
  const m = /^([weml])(\d+|all)$/.exec(id);
  if (m) {
    const n = m[2];
    const txt = {w: `Con đã đọc đúng ${n} tiếng!`, e: `Con đã thuộc ${n} từ tiếng Anh!`, m: `Con đã làm đúng ${n} phép tính!`,
      l: n === 'all' ? 'Con đã thuộc cả bảng chữ cái!' : `Con đã nhận ra ${n} chữ cái!`}[m[1]];
    const pic = {w: 'Open book', e: 'Globe showing Asia-Australia', m: 'Abacus', l: 'Books'}[m[1]];
    return {text: txt, img: pic, phrase: 'ms_' + id};
  }
  const [, iid, tier] = id.split(':');
  const isl = island(iid);
  return {text: `Con đã học xong đảo ${isl ? L(isl) : iid}${tier && tier !== '0' ? ` (${L(tierOf(Number(tier)))})` : ''}!`, img: isl ? isl.img : 'Trophy', phrase: 'ms_isl'};
}
function checkMilestones(p) {
  ensureLearn(p);
  return store.addMilestones(milestoneIds(p));
}
const fmtDate = d => d ? d.split('-').reverse().join('/') : '';

function celebrate(p, ids) {
  if (!ids.length) return;
  const main = ids[ids.length - 1], info = msInfo(main);
  confetti(140);
  audio.sfx('win');
  audio.sayPhrase(info.phrase);
  const ov = overlay(
    h('div', {class: 'ms-burst'}, img('Trophy', {class: 'ms-trophy'}), img(info.img, {class: 'ms-pic'})),
    h('h2', {class: 'ms-title'}, '🎉 ', t('great')),
    ids.map(id => h('div', {class: 'ms-line'}, msInfo(id).text)),
    h('div', {class: 'row'},
      h('button', {class: 'btn ghost', onclick: () => ov.remove()}, t('next'), ' ➜'),
      h('button', {class: 'btn green', onclick: () => { ov.remove(); certificate(p, main); }}, '🏅 Bằng khen')));
  ov.classList.add('msov');
}

// ---------- Chia sẻ (2026-10-14): ảnh bằng khen để bố mẹ khoe, link giới thiệu app ----------
const SHARE_URL = 'https://datpilot.com/be-vui-hoc';
const APP_PITCH = 'Bé Vui Học: web học mà chơi miễn phí cho bé 3–6 tuổi. Ghép vần, đếm số, toán, tiếng Anh, có lộ trình theo thứ tự bài sách lớp 1. Không quảng cáo, không cần tài khoản.';
const shareLink = src => `${SHARE_URL}?src=${src}`;
const isTouch = () => isIOS() || /Android/.test(navigator.userAgent);

function loadImg(u) {
  return new Promise(res => { const i = new Image(); i.onload = () => res(i); i.onerror = () => res(null); i.src = u; });
}
function wrapText(ctx, text, maxW) {
  const out = []; let line = '';
  for (const w of text.split(' ')) {
    const tst = line ? line + ' ' + w : w;
    if (ctx.measureText(tst).width > maxW && line) { out.push(line); line = w; } else line = tst;
  }
  if (line) out.push(line);
  return out;
}
// Vẽ bằng khen ra ảnh PNG 1080×1350 (tỉ lệ bài đăng Facebook). Vẽ ngay trên máy, không gửi gì đi.
async function certImage(p, id, showName) {
  const info = msInfo(id), when = fmtDate(store.learn(p).msAt[id] || store.today());
  const F = '"Baloo 2", "Nunito", system-ui, sans-serif';
  try { await Promise.all(['800 100px', '700 50px', '600 40px'].map(f => document.fonts.load(`${f} "Baloo 2"`))); } catch (e) { /* dùng font máy */ }
  const [medal, pic] = await Promise.all([loadImg(src('Sports medal')), loadImg(src(info.img))]);
  const W = 1080, H = 1350, cv = document.createElement('canvas'); cv.width = W; cv.height = H;
  const c = cv.getContext('2d');
  const g = c.createLinearGradient(0, 0, 0, H); g.addColorStop(0, '#fff9e6'); g.addColorStop(1, '#ffe8cc');
  c.fillStyle = g; c.fillRect(0, 0, W, H);
  const rr = (x, y, w, h, r) => { c.beginPath(); c.roundRect ? c.roundRect(x, y, w, h, r) : c.rect(x, y, w, h); };
  c.lineWidth = 14; c.strokeStyle = '#f59f00'; rr(30, 30, W - 60, H - 60, 44); c.stroke();
  c.lineWidth = 4; c.strokeStyle = '#ffd43b'; rr(58, 58, W - 116, H - 116, 30); c.stroke();
  c.textAlign = 'center'; c.textBaseline = 'alphabetic';
  if (medal) c.drawImage(medal, W / 2 - 80, 92, 160, 160);
  c.fillStyle = '#d9480f'; c.font = `800 112px ${F}`; c.fillText('BẰNG KHEN', W / 2, 360);
  c.fillStyle = '#495057'; c.font = `600 44px ${F}`;
  c.fillText(showName ? 'Bé Vui Học trân trọng tặng bé' : 'Bé Vui Học trân trọng tặng bé yêu', W / 2, 430);
  let y = 430;
  if (showName) {
    let fs = 120; c.font = `800 ${fs}px ${F}`;
    while (c.measureText(p.name).width > W - 220 && fs > 60) { fs -= 6; c.font = `800 ${fs}px ${F}`; }
    c.fillStyle = '#1c7ed6'; c.fillText(p.name, W / 2, y += 140);
  }
  if (pic) c.drawImage(pic, W / 2 - 140, y += 40, 280, 280);
  y += 280;
  c.fillStyle = '#212529'; c.font = `700 58px ${F}`;
  for (const ln of wrapText(c, info.text, W - 200)) c.fillText(ln, W / 2, y += 78);
  c.fillStyle = '#868e96'; c.font = `600 40px ${F}`; c.fillText(`Ngày ${when} · ${p.stars} sao`, W / 2, y += 72);
  c.fillStyle = '#f59f00'; rr(110, H - 230, W - 220, 140, 70); c.fill();
  c.fillStyle = '#fff'; c.font = `800 50px ${F}`; c.fillText('Học miễn phí tại datpilot.com/kids', W / 2, H - 165);
  c.font = `600 34px ${F}`; c.fillText('Bé Vui Học · học mà chơi cho bé 3–6 tuổi', W / 2, H - 118);
  return new Promise(r => cv.toBlob(r, 'image/png'));
}
// Chia sẻ file ảnh (bảng chia sẻ của máy: Zalo, Facebook, Messenger…); máy tính thì tải ảnh + chép lời giới thiệu.
async function shareImage(blob, name, text, k) {
  const file = new File([blob], name, {type: 'image/png'});
  if (isTouch() && navigator.canShare && navigator.canShare({files: [file]})) {
    try { await navigator.share({files: [file], text}); shareEvent(k); return; } catch (e) { if (e.name === 'AbortError') return; }
  }
  shareEvent(k);
  const a = h('a', {href: URL.createObjectURL(blob), download: name});
  document.body.append(a); a.click(); a.remove();
  try { await navigator.clipboard.writeText(text); toast('Đã lưu ảnh và chép lời giới thiệu, dán vào bài đăng nhé'); }
  catch (e) { toast('Đã lưu ảnh bằng khen'); }
}
async function shareApp(src) {
  const url = shareLink(src);
  if (isTouch() && navigator.share) {
    try { await navigator.share({title: 'Bé Vui Học', text: APP_PITCH, url}); shareEvent(src); return; } catch (e) { if (e.name === 'AbortError') return; }
  }
  shareEvent('link');
  copyText(`${APP_PITCH} ${shareLink('link')}`, 'Đã chép link, dán vào Zalo hoặc Facebook nhé');
}
function shareCard() {
  return h('div', {class: 'card section sharecard'},
    h('h3', {}, '📣 Giới thiệu cho bạn bè'),
    h('p', {class: 'note'}, 'Bé Vui Học miễn phí. Bố mẹ thấy có ích thì gửi giúp vào nhóm Zalo của lớp hoặc bạn bè có con nhỏ nhé.'),
    h('div', {class: 'row', style: {justifyContent: 'flex-start'}},
      // Điện thoại: link sharer.php bị app Facebook chặn mở và làm mất link, nên dùng bảng chia sẻ của máy (chọn Facebook trong đó).
      navigator.share && isTouch() ? h('button', {class: 'small-btn', onclick: () => shareApp('app')}, '📤 Chia sẻ Zalo, Facebook, Messenger…')
        : h('a', {class: 'small-btn', href: 'https://www.facebook.com/sharer/sharer.php?u=' + encodeURIComponent(shareLink('fb')), target: '_blank', rel: 'noopener', onclick: () => shareEvent('fb')}, '📘 Facebook'),
      h('button', {class: 'small-btn', onclick: () => shareEvent('link') || copyText(`${APP_PITCH} ${shareLink('link')}`, 'Đã chép link, dán vào Zalo hoặc Facebook nhé')}, '📋 Chép link')));
}

// Bằng khen có tên bé để bố mẹ khoe người thân. parent=true khi mở từ Báo cáo (đã qua khoá bố mẹ), không thì nút khoe hỏi phép tính.
function certificate(p, id, parent = false) {
  const info = msInfo(id);
  const when = fmtDate(store.learn(p).msAt[id] || store.today());
  let showName = true, blob = null;
  const render = () => { blob = null; certImage(p, id, showName).then(b => { blob = b; }).catch(() => {}); };
  render();   // vẽ sẵn để lúc bấm khoe gọi share ngay trong lượt chạm (Safari đòi)
  const nameBox = h('input', {type: 'checkbox', checked: true, onchange: () => { showName = nameBox.checked; render(); }});
  const shareBtn = h('button', {class: 'btn green certshare', onclick: async () => {
    audio.sfx('tap');
    if (!parent && !(await gate())) return;
    if (!blob) blob = await certImage(p, id, showName);
    if (!blob) return toast('Chưa tạo được ảnh, bố mẹ chụp màn hình nhé');
    shareImage(blob, 'bang-khen-be-vui-hoc.png', `${showName ? 'Bé ' + p.name : 'Bé nhà mình'} vừa được bằng khen: ${info.text} Học miễn phí ở Bé Vui Học: ${shareLink('giaykhen')}`, 'giaykhen');
  }}, '📤 Khoe với người thân');
  audio.sayPhrase('cert');
  const ov = overlay(
    h('div', {class: 'cert'},
      h('div', {class: 'cert-in'},
        h('div', {class: 'cert-rib'}, img('Sports medal')),
        h('div', {class: 'cert-top'}, 'BẰNG KHEN'),
        h('div', {class: 'cert-to'}, 'Bé Vui Học trân trọng tặng bé'),
        h('div', {class: 'cert-name'}, p.name),
        h('div', {class: 'cert-art'}, dressed(p, 'cert-kid'), img(info.img, {class: 'cert-pic'})),
        h('div', {class: 'cert-ach'}, info.text),
        h('div', {class: 'cert-foot'}, h('span', {}, '📅 ', when), h('span', {}, '⭐ ', p.stars, ' sao'), h('span', {class: 'seal'}, 'Bé Vui Học')))),
    h('label', {class: 'note certname'}, nameBox, ' Hiện tên bé trên ảnh'),
    h('div', {class: 'row'}, h('button', {class: 'btn ghost', onclick: () => ov.remove()}, t('close')), shareBtn));
  ov.classList.add('certov');
}

// ---------- Ôn tập: dựng lại câu hỏi cho từng mục ----------
const near = (ans, n, lo, hi) => {
  const c = new Set([ans]);
  for (let d = 1; c.size < n && d <= hi - lo; d++) for (const k of shuffle([ans - d, ans + d])) if (k >= lo && k <= hi && c.size < n) c.add(k);
  return shuffle([...c]);
};
const face = it => it.img ? img(it.img) : it.color ? h('span', {class: 'swatch', style: {background: it.color}}) : h('span', {}, it.digit ?? it.en);
const txtChoices = list => list.map(x => ({id: x, node: () => h('span', {}, x)}));
const confWith = (p, ns, ans) => Object.entries(store.learn(p).conf).filter(([k]) => k.startsWith(`${ns}|${ans}|`)).sort((a, b) => b[1] - a[1]).map(([k]) => k.split('|')[2]);
const TONE_LIST = ['ngang', 'huyền', 'sắc', 'hỏi', 'ngã', 'nặng'];

function wordQ(p, w, placeTone, toneFocus) {
  // Nghe tiếng, nhìn hình, chọn cách viết đúng giữa các tiếng gần giống (khác dấu, khác âm đầu/vần).
  const bad = confWith(p, 'tone', w.tone);
  const tones = [...new Set([...bad, ...shuffle(TONE_LIST)])].filter(x => x !== w.tone);
  const variants = tones.map(x => w.c + placeTone(w.v, x));
  const others = content.vnwords.filter(x => x.w !== w.w && (x.c === w.c || x.v === w.v)).map(x => x.w);
  const pool = toneFocus ? variants.slice(0, 3) : [...variants.slice(0, 2), ...sample(others, 1)];
  const opts = shuffle([w.w, ...[...new Set(pool)].filter(x => x !== w.w).slice(0, 3)]);
  return {say: audio.tpl('vnWord', w), stage: () => h('div', {class: 'word-pic'}, img(w.img)), choices: txtChoices(opts), cls: 'syll', cols: opts.length,
    answer: w.w, reward: audio.tpl('spell', w), rewardNode: () => [img(w.img), h('div', {class: 'big'}, w.w)]};
}
function reviewQ(p, key, placeTone) {
  const info = itemOf(key);
  if (!info) return null;
  const {set, it} = info;
  if (set === 'letters') {
    const opts = shuffle([it.ch, ...[...new Set([...confWith(p, 'letters', it.ch), ...shuffle(content.letters.map(l => l.ch))])].filter(x => x !== it.ch).slice(0, 3)]);
    return {say: audio.tpl('findLetter', it), label: t('findLetter'), choices: txtChoices(opts), answer: it.ch,
      reward: audio.tpl('letterWord', it), rewardNode: () => [img(it.img), h('div', {class: 'big'}, it.ch), h('div', {class: 'small'}, it.word)]};
  }
  if (set === 'tone') {
    const id = splitKey(key)[1];
    const pool = content.vnwords.filter(w => w.tone === id);
    return pool.length ? wordQ(p, sample(pool, 1)[0], placeTone, true) : null;
  }
  if (set === 'vnwords') return wordQ(p, it, placeTone, false);
  if (set === 'twoWords' || set === 'sentences') {
    const all = content[set];
    const opts = shuffle([it, ...sample(all.filter(x => x.img !== it.img), 2)]);
    return {say: null, label: it.w || it.t, labelCls: set === 'twoWords' ? 'readword' : 'readsent', choices: opts.map(x => ({id: x.id, node: () => img(x.img)})),
      answer: it.id, reward: audio.tpl(set === 'twoWords' ? 'twoWord' : 'sentence', it), rewardNode: () => [img(it.img), h('div', {class: 'big'}, it.w || it.t)]};
  }
  if (set === 'ruleWords') {
    return {say: audio.tpl('ruleSay', it), stage: () => h('div', {class: 'word-pic'}, img(it.img)), choices: txtChoices(shuffle([it.w, it.bad])), cls: 'syll words',
      answer: it.w, reward: audio.tpl('ruleSay', it), rewardNode: () => [img(it.img), h('div', {class: 'big'}, it.w)]};
  }
  if (FACT_SETS.includes(set)) {
    const add = !set.startsWith('sub'), big = !['addFacts', 'subFacts'].includes(set);
    const sign = add ? '+' : '−';
    const q = big ? (add ? 'add100Q' : 'sub100Q') : (add ? 'addQ' : 'subQ'), a = big ? (add ? 'add100A' : 'sub100A') : (add ? 'addA' : 'subA');
    return {say: audio.tpl(q, it), stage: () => h('div', {class: 'mathbox'}, h('div', {class: 'eq'}, `${it.a} ${sign} ${it.b} = ?`)),
      choices: near(it.c, 4, 0, Math.max(10, it.c + 5)).map(k => ({id: k, node: () => h('span', {}, k)})), cls: 'nums',
      answer: it.c, reward: audio.tpl(a, it), rewardNode: () => h('div', {class: 'big'}, `${it.a} ${sign} ${it.b} = ${it.c}`)};
  }
  if (set.startsWith('en_')) {
    const lv = content.englishLevels.find(l => l.set === set);
    const say = audio.tpl(lv ? lv.tpl : 'wordEn', it);
    const opts = shuffle([it, ...sample(content[set].filter(x => x.id !== it.id), 3)]);
    return {say, label: say[1], choices: opts.map(x => ({id: x.id, node: () => face(x)})), answer: it.id,
      reward: audio.tpl('wordEn', it), rewardNode: () => [face(it), h('div', {class: 'big'}, it.en)]};
  }
  return null;
}
const REVIEWABLE = k => { const s = splitKey(k)[0]; return s === 'letters' || s === 'tone' || s.startsWith('en_') || REV_SETS.includes(s); };
const dueCount = p => store.dueItems(p).filter(REVIEWABLE).length;

// /review: mục tới ngày ôn; /review/all: bố mẹ bấm "Luyện lại" (mọi mục còn yếu); /review/x/<mục>: luyện một mục.
async function reviewPlay(mode, one) {
  const p = store.profile();
  ensureLearn(p);
  let keys = mode === 'x' && one ? [decodeURIComponent(one)] : store.dueItems(p, mode === 'all').filter(REVIEWABLE).slice(0, 8);
  let aborted = false;
  const progressEl = h('div', {class: 'progress'});
  const stage = h('div', {class: 'stage'});
  const unwatch = watchStage(stage);
  leaveGame = () => { aborted = true; unwatch(); audio.stopVoice(); };
  const buddy = dressed(p, 'buddy');
  setPhotoMode(true);
  screen('game review', h('div', {class: 'topbar'}, back('/map'), progressEl, h('span', {class: 'pill revpill'}, '🔁 Ôn bài')), stage);
  app.append(buddy);
  const anim = cls => { buddy.classList.remove('cheer', 'sad'); void buddy.offsetWidth; buddy.classList.add(cls); };
  const [{placeTone}, {runQuiz}] = await Promise.all([loadGame('spell'), loadGame('quiz')]);
  if (aborted) return;
  const qs = [];
  for (let round = 0; round < 3 && keys.length; round++) {
    for (const k of keys) { const q = reviewQ(p, k, placeTone); if (q) { q._k = k; qs.push(q); } }
    if (qs.length >= Math.min(5, keys.length * 3)) break;
  }
  if (!qs.length) {
    unwatch(); leaveGame = null; setPhotoMode(false);
    audio.sayPhrase('reviewNone');
    const ov = overlay(img('Glowing star', {style: {width: '110px'}}), h('h2', {}, 'Không có gì cần ôn!'), h('p', {class: 'note'}, 'Con làm đúng hết rồi. Học bài mới thôi!'),
      h('div', {class: 'row'}, h('button', {class: 'btn green', onclick: () => { ov.remove(); go('/map'); }}, '🗺️ ', t('map'))));
    return;
  }
  const list = shuffle(qs).slice(0, 8);
  const g = {stage, aborted: () => aborted, buddySrc: src(mascot(p.mascot).img), hideBuddy: () => buddy.remove(),
    cheer: () => anim('cheer'), sad: () => anim('sad'),
    progress(i, n) { progressEl.replaceChildren(...Array.from({length: n}, (_, k) => h('i', {class: k < i ? 'done' : k === i ? 'now' : ''}))); },
    record(q, picks, ms) {
      const set = splitKey(q._k)[0];
      const ns = set === 'letters' ? 'letters' : set === 'tone' ? 'tone' : set.startsWith('en_') ? set : null;
      const keys = [q._k];
      if (set === 'tone') { const w = content.vnwords.find(x => x.w === q.answer); if (w) keys.push('vnwords:' + w.id); }
      recordQ(skillOfSet(set), keys, ns === 'tone' ? null : ns, q, picks, ms);
    }};
  const res = await runQuiz(g, list, {intro: 'reviewIntro'});
  if (aborted || !res) return;
  unwatch(); leaveGame = null; setPhotoMode(false);
  store.recordReview(res.stars);
  const funOn = store.settings().fun;
  if (funOn) store.addTickets(1);
  const ms = checkMilestones(p);
  const left = dueCount(p);
  audio.sfx('win'); confetti();
  audio.sayPhrase('reviewDone');
  const starImgs = [0, 1, 2].map(() => img('Star'));
  const ov = overlay(
    h('h2', {}, '🔁 Ôn xong!'),
    h('div', {class: 'bigstars'}, starImgs),
    funOn ? h('div', {class: 'prize ticket'}, img('Admission tickets'), t('gotTicket', {n: 1})) : null,
    h('p', {class: 'note'}, left ? `Còn ${left} chỗ cần ôn, mai mình ôn tiếp nhé.` : 'Con đã ôn hết những chỗ hay nhầm!'),
    h('div', {class: 'row'},
      h('button', {class: 'btn ghost', onclick: () => { ov.remove(); go('/map'); }}, '🗺️ ', t('map')),
      left ? h('button', {class: 'btn blue', onclick: () => { ov.remove(); route(true); }}, '🔁 Ôn tiếp') : null));
  ov.classList.add('resultov');
  for (let k = 0; k < res.stars; k++) { await wait(380); if (!ov.isConnected) return; starImgs[k].classList.add('lit'); audio.sfx('star'); }
  if (ms.length) { await wait(1400); if (ov.isConnected) celebrate(p, ms); }
}

// ---------- Báo cáo của con (Góc bố mẹ) ----------
const pct = (r, w) => r + w ? Math.round(r / (r + w) * 100) : null;
function factGroup(key) {
  const [set, id] = splitKey(key);
  if (!['addFacts', 'subFacts'].includes(set)) return 'f100';
  const [a, b] = id.split(',').map(Number);
  return (set === 'addFacts' ? a + b : a) <= 10 ? 'f10' : 'f20';
}
function skillRows(p) {
  const l = store.learn(p), items = l.items, sk = l.skills;
  const sum = test => { let r = 0, w = 0, n = 0, m = 0; for (const k in items) if (test(k)) { r += items[k][0]; w += items[k][1]; n++; if (items[k][4]) m++; } return {r, w, n, m}; };
  const accTxt = (r, w) => pct(r, w) == null ? '' : `${pct(r, w)}% đúng ngay · ${r + w} câu`;
  const isl = id => island(id) || {img: 'Star', color: '#4fb3ff', vi: id, en: id};
  const rows = [];
  const add = (id, name, main, frac, acc, extra) => rows.push({id, img: isl(id).img, color: isl(id).color, name, main, frac, acc, extra});
  const S = id => sk[id] || [0, 0, 0];
  const L1 = sum(k => k.startsWith('letters:'));
  if (L1.n || S('letters')[0] + S('letters')[1]) add('letters', L(isl('letters')), `Nhận ra ${L1.m}/${content.letters.length} chữ cái`, L1.m / content.letters.length, accTxt(...S('letters')));
  const W = sum(k => k.startsWith('vnwords:')), T = sum(k => k.startsWith('tone:'));
  if (W.n || S('spell')[0] + S('spell')[1]) {
    const weakTone = Object.entries(items).filter(([k, v]) => k.startsWith('tone:') && v[1] > v[0] / 3 && v[1] >= 2).map(([k]) => toneName(splitKey(k)[1]));
    add('spell', L(isl('spell')), `Đọc đúng ${W.m}/${content.vnwords.length} tiếng`, W.m / content.vnwords.length, accTxt(...S('spell')),
      T.n ? `Dấu thanh: ${pct(T.r, T.w)}% đúng${weakTone.length ? ' · còn nhầm ' + weakTone.join(', ') : ''}` : null);
  }
  const R2 = sum(k => k.startsWith('twoWords:')), RS = sum(k => k.startsWith('sentences:'));
  if (R2.n || RS.n || S('read')[0] + S('read')[1]) add('read', L(isl('read')), `Đọc hiểu ${R2.m} từ, ${RS.m} câu`, null, accTxt(...S('read')));
  const groups = {f10: 'Cộng trừ trong 10', f20: 'Cộng trừ đến 20', f100: 'Cộng trừ đến 100'};
  const mathLines = Object.entries(groups).map(([g, name]) => { const s = sum(k => isFact(k) && factGroup(k) === g); return s.r + s.w ? `${name}: ${pct(s.r, s.w)}% đúng (${s.r + s.w} câu)` : null; }).filter(Boolean);
  const F = sum(isFact);
  if (F.n || S('math')[0] + S('math')[1]) add('math', L(isl('math')), mathLines[0] || `Làm đúng ${F.m} phép tính`, null, accTxt(...S('math')), mathLines.slice(1).join(' · ') || null);
  const E = sum(isEn);
  const enTotal = [...new Set(content.englishLevels.map(x => x.set))].reduce((n, s) => n + (content[s] || []).length, 0);
  if (E.n || S('english')[0] + S('english')[1]) add('english', L(isl('english')), `Thuộc ${E.m}/${enTotal} từ tiếng Anh`, E.m / enTotal, accTxt(...S('english')));
  // Các đảo còn lại: chỉ tỉ lệ đúng.
  for (const i of gameIslands()) {
    if (['letters', 'spell', 'read', 'math', 'english'].includes(i.id)) continue;
    const s = S(i.id);
    if (s[0] + s[1]) add(i.id, L(i), `${pct(s[0], s[1])}% đúng ngay`, pct(s[0], s[1]) / 100, `${s[0] + s[1]} câu · ~${Math.max(1, Math.round(s[2] / (s[0] + s[1]) / 1000))} giây/câu`);
  }
  return rows;
}
const toneName = x => x === 'ngang' ? 'không dấu' : 'dấu ' + x;
const CONF_LABEL = (ns, x) => ns === 'tone' ? toneName(x) : ns.startsWith('en_') ? ((content[ns] || []).find(e => e.id === x) || {en: x}).en : x;
function weakList(p) {
  const l = store.learn(p);
  // Gộp hai chiều (b→d và d→b là một cặp "b ↔ d").
  const pairs = new Map();
  for (const [k, n] of Object.entries(l.conf)) {
    const [ns, a, b] = k.split('|');
    const id = ns + '|' + [a, b].sort().join('|');
    const cur = pairs.get(id) || {ns, a, b, n: 0, top: 0};
    cur.n += n;
    if (n > cur.top) { cur.top = n; cur.a = a; cur.b = b; }
    pairs.set(id, cur);
  }
  const conf = [...pairs.values()].filter(x => x.n >= 2).sort((x, y) => y.n - x.n).slice(0, 6).map(({ns, a, b, n}) => {
    const key = ns === 'letters' ? 'letters:' + a : ns === 'tone' ? 'tone:' + a : ns.startsWith('en_') ? `${ns}:${a}` : null;
    return {text: `${CONF_LABEL(ns, a)} ↔ ${CONF_LABEL(ns, b)}`, n, key, conf: true};
  });
  const inConf = new Set(conf.map(x => x.key));
  const items = store.dueItems(p, true).filter(k => REVIEWABLE(k) && !inConf.has(k)).slice(0, 10).map(k => {
    const info = itemOf(k);
    return info && {text: info.label, img: info.img, n: l.items[k][1], key: k};
  }).filter(Boolean);
  return [...conf, ...items];
}
function nextGoal(p) {
  const w = masteredCount(p, k => k.startsWith('vnwords:')), e = masteredCount(p, isEn), m = masteredCount(p, isFact);
  const nw = MS_STEPS.w.find(n => n > w), ne = MS_STEPS.e.find(n => n > e), nm = MS_STEPS.m.find(n => n > m);
  const opts = [nw && [nw - w, `đọc đúng ${nw} tiếng`], nm && [nm - m, `làm đúng ${nm} phép tính`], ne && [ne - e, `thuộc ${ne} từ tiếng Anh`]].filter(Boolean).sort((a, b) => a[0] - b[0]);
  return opts[0] ? `Còn ${opts[0][0]} nữa là con ${opts[0][1]}.` : null;
}
const WD = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
function report(kidId) {
  const p = store.profiles().find(x => x.id === kidId);
  if (!p) return go('/parent');
  const l = store.learn(p);
  const days = [];
  for (let k = 6; k >= 0; k--) {
    const d = new Date(Date.now() - k * 864e5), key = store.dayKey(d), dd = l.days[key] || [0, 0, 0, 0, 0];
    days.push({wd: k === 0 ? 'Nay' : WD[d.getDay()], date: d.getDate(), min: Math.round(((p.usage || {})[key] || 0) / 60), les: dd[0], stars: dd[1], newM: dd[4]});
  }
  const td = days[6], wk = days.reduce((a, d) => ({min: a.min + d.min, les: a.les + d.les, stars: a.stars + d.stars, newM: a.newM + d.newM, on: a.on + (d.min || d.les ? 1 : 0)}), {min: 0, les: 0, stars: 0, newM: 0, on: 0});
  const maxMin = Math.max(10, ...days.map(d => d.min));
  const rows = skillRows(p), weak = weakList(p);
  const ms = [...l.ms].reverse().sort((a, b) => (l.msAt[b] || '').localeCompare(l.msAt[a] || ''));
  const goal = nextGoal(p);
  const tile = (ic, n, label) => h('div', {class: 'rp-tile'}, h('span', {class: 'ic'}, ic), h('b', {}, n), h('span', {}, label));
  const summary = wk.on
    ? `Tuần này ${p.name} học ${wk.on}/7 ngày, ${wk.min} phút, ${wk.les} bài${wk.newM ? `, thạo thêm ${wk.newM} mục mới` : ''}.`
    : `${p.name} chưa học tuần này.`;
  screen('parent report',
    h('div', {class: 'topbar'}, back('/parent'), h('h1', {}, '📊 Báo cáo của ', p.name), h('span', {class: 'spacer'})),
    h('div', {class: 'card section rp-hero'},
      h('div', {class: 'rp-who'}, dressed(p, 'rp-ava'), h('div', {},
        h('div', {class: 'rp-sum'}, summary),
        h('div', {class: 'rp-sub'}, `${L(tierOf(p.tier))} · ⭐ ${p.stars} sao · 🔥 ${(p.streak || {}).count || 0} ngày liên tiếp`),
        goal ? h('div', {class: 'rp-goal'}, '🎯 ', goal) : null)),
      h('div', {class: 'rp-tiles'},
        h('div', {class: 'rp-grp'}, h('div', {class: 'rp-gt'}, 'Hôm nay'), tile('⏱️', td.min, 'phút'), tile('📚', td.les, 'bài'), tile('⭐', td.stars, 'sao')),
        h('div', {class: 'rp-grp'}, h('div', {class: 'rp-gt'}, '7 ngày qua'), tile('⏱️', wk.min, 'phút'), tile('📚', wk.les, 'bài'), tile('⭐', wk.stars, 'sao')))),
    h('div', {class: 'card section'},
      h('h3', {}, '📅 7 ngày qua'),
      h('div', {class: 'rp-chart'}, days.map(d => h('div', {class: `rp-col ${d === td ? 'today' : ''}`},
        h('span', {class: 'v'}, d.min ? d.min + '′' : ''),
        h('div', {class: 'bar'}, h('i', {style: {height: (d.min / maxMin * 100) + '%'}})),
        h('span', {class: 'wd'}, d.wd), h('span', {class: 'les'}, d.les ? d.les + ' bài' : '·')))),
      h('p', {class: 'note'}, 'Cột: số phút học mỗi ngày. Dưới cột: số bài đã làm.')),
    h('div', {class: 'card section'},
      h('h3', {}, '🧠 Con đã học được gì'),
      rows.length ? h('div', {class: 'rp-skills'}, rows.map(r => h('div', {class: 'rp-skill', style: {'--c': r.color}},
        img(r.img), h('div', {class: 'rp-sk'},
          h('div', {class: 'rp-sk-top'}, h('b', {}, r.name), r.acc ? h('span', {class: 'acc'}, r.acc) : null),
          h('div', {class: 'rp-main'}, r.main),
          r.frac != null ? h('div', {class: 'rp-bar'}, h('i', {style: {width: Math.max(2, Math.min(100, r.frac * 100)) + '%'}})) : null,
          r.extra ? h('div', {class: 'rp-extra'}, r.extra) : null))))
        : h('p', {class: 'note'}, 'Chưa có số liệu. Cho bé chơi vài bài, báo cáo sẽ hiện ở đây.'),
      h('p', {class: 'note'}, `"Đúng ngay" = chọn đúng ở lần chạm đầu. Số liệu theo dõi từ ${fmtDate(l.since || store.today())}.`)),
    h('div', {class: 'card section'},
      h('h3', {}, '🔎 Con hay nhầm'),
      weak.length ? [
        h('div', {class: 'rp-weak'}, weak.map(x => h('button', {class: `rp-chip ${x.conf ? 'conf' : ''} ${x.key ? '' : 'nokey'}`, title: 'Luyện riêng mục này', onclick: () => {
          if (!x.key) return;
          audio.sfx('tap');
          store.setActive(p.id); go('/review/x/' + encodeURIComponent(x.key));
        }}, x.img ? img(x.img) : null, h('b', {}, x.text), h('span', {}, `sai ${x.n} lần`)))),
        h('div', {class: 'row', style: {justifyContent: 'flex-start'}},
          h('button', {class: 'btn green rp-practice', onclick: () => { audio.sfx('tap'); store.setActive(p.id); go('/review/all'); }}, '▶ Luyện lại cho ', p.name)),
        h('p', {class: 'note'}, 'Bấm "Luyện lại" rồi đưa máy cho bé: bé làm một bài ôn ngắn đúng những chỗ này. Các chỗ sai cũng tự hỏi lại sau 1, 3, 7 ngày (nút 🔁 trên bản đồ).')]
        : h('p', {class: 'note'}, 'Chưa thấy chỗ nào con nhầm nhiều lần. Tuyệt!')),
    h('div', {class: 'card section'},
      h('h3', {}, '🏅 Mốc tiến bộ & bằng khen'),
      ms.length ? h('div', {class: 'rp-ms'}, ms.map(id => h('button', {class: 'rp-msi', onclick: () => certificate(p, id, true)},
        img(msInfo(id).img), h('span', {}, h('b', {}, msInfo(id).text), h('em', {}, fmtDate(l.msAt[id]))), h('span', {class: 'go'}, '🏅'))))
        : h('p', {class: 'note'}, 'Chưa có mốc nào. Mốc đầu tiên: đọc đúng 10 tiếng, nhận ra 10 chữ cái hoặc làm đúng 20 phép tính.'))
  );
}

// ---------- Điều hướng ----------
function route(force) {
  setPhotoMode(false);
  if (leaveGame) { leaveGame(); leaveGame = null; }
  document.querySelectorAll('.overlay, .buddy').forEach(x => x.remove());
  audio.stopVoice();
  const parts = (location.hash.replace(/^#\/?/, '') || '').split('/');
  const [name, a, b] = parts;
  if (!started) return start();
  try { sessionStorage.setItem('bvh.route', RESUME.includes(name) && !((name === 'fun' || name === 'rpg') && a) ? location.hash : ''); } catch (e) { /* bỏ qua */ }
  const needKid = !['', 'kids', 'new', 'parent', 'report'].includes(name);
  if (needKid && !store.profile()) return go(store.profiles().length ? '/kids' : '/new');
  if (needKid && name !== 'rest' && store.overLimit()) return go('/rest');
  switch (name) {
    case 'kids': return store.profiles().length ? kids() : go('/new');
    case 'new': return newKid();
    case 'map': return map();
    case 'island': return islandScreen(a);
    case 'play': return play(a, b, parts[3]);
    case 'lop1': return classScreen();
    case 'album': return album();
    case 'buddies': return buddies();
    case 'parent': return parent();
    case 'report': return report(a);
    case 'review': return reviewPlay(a, b);
    case 'duel': return duelScreen();
    case 'room': audio.sayPhrase('roomIntro'); return room();
    case 'pet': return petRoom();
    case 'fun': return b == null && a ? funPlay(a) : funZone();
    case 'rpg': return store.settings().fun ? (a != null && b != null ? rpgPlay(a, b) : rpgTown()) : go('/map');
    case 'rest': return store.overLimit() ? rest() : go('/map');
    default: return start();
  }
}

// Đếm thời gian chơi (chỉ khi app đang mở và có bé đang chơi).
setInterval(() => {
  const name = location.hash.replace(/^#\/?/, '').split('/')[0];
  if (!started || document.hidden || !store.profile() || ['', 'kids', 'new', 'parent', 'report', 'rest'].includes(name)) return;
  store.addUsage(15);
  if (store.overLimit() && name !== 'play') go('/rest');
}, 15000);

async function boot() {
  document.documentElement.lang = lang();
  iconize(app);
  const v = '?v=' + window.BVH_VERSION;
  // Vẽ màn Bắt đầu ngay, dữ liệu tải song song.
  if ((location.hash && location.hash !== '#/') || location.search) history.replaceState(null, '', location.pathname);
  start();
  ready = Promise.all([fetch('data/content.json' + v).then(r => r.json()), fetch('data/app.json' + v).then(r => r.json()), audio.init(),
    fetch('data/photos.json' + v).then(r => r.ok ? r.json() : {}).catch(() => ({}))])
    .then(r => { fetch('data/voice.json' + v).then(x => x.json()).then(x => { voiceData = x; revIdx = null; }).catch(() => {}); return r; })
    .then(([c, d, , ph]) => { content = c; data = d; photos = ph; setPhotos(ph); });
  // Đến đây app.js đã chạy được: tắt cứu hộ của index.html. Lỗi tải dữ liệu do nút Bắt đầu xử lý.
  window.BVH_OK = true;
  try { await ready; } catch (e) { return; }
  window.addEventListener('hashchange', () => route());
  // Đồng bộ mã gia đình (nếu bố mẹ đã bật): có dữ liệu mới từ máy khác thì vẽ lại màn danh sách, không động vào màn đang chơi.
  sync.init(() => {
    const n = location.hash.replace(/^#\/?/, '').split('/')[0];
    if (started && ['kids', 'map', 'parent', 'lop1'].includes(n)) route(true);
  });
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('sw.js?v=' + window.BVH_VERSION).catch(() => {});
    // Có bản mới thì lần mở app sau tự dùng bản mới (service worker lấy trang từ mạng). Không tự tải lại trang
    // khi bé đang chơi; chỉ tải lại một lần nếu bé chưa bấm Bắt đầu và bản đang chạy là bản cũ.
    navigator.serviceWorker.addEventListener('message', e => {
      if (!(e.data && e.data.type === 'update' && e.data.version !== window.BVH_VERSION) || started) return;
      let last = 0;
      try { last = Number(sessionStorage.getItem('bvh.reloaded')) || 0; } catch (err) { /* bỏ qua */ }
      if (Date.now() - last < 60000) return;
      try { sessionStorage.setItem('bvh.reloaded', String(Date.now())); } catch (err) { /* bỏ qua */ }
      location.replace(location.pathname);
    });
    // Sau khi màn đầu đã lên, nhờ service worker tải dần hình và giọng đọc để chơi offline.
    navigator.serviceWorker.ready.then(reg => setTimeout(() => reg.active && reg.active.postMessage({type: 'warm'}), 8000));
  }
}

boot();
