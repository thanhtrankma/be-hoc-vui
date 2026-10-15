// Âm thanh: giọng đọc (mp3 tạo sẵn lúc build), hiệu ứng và nhạc nền tổng hợp bằng Web Audio.
// iPad chỉ cho phát tiếng sau lần chạm đầu tiên, nên màn Bắt đầu gọi unlock().
import {settings} from './store.js?v=4c51d34a6e';
import {lang} from './i18n.js?v=4c51d34a6e';

let ctx, master, voiceBus, sfxBus, musicBus;
let index = {}, voice = {phrases: {}, templates: {}};
const buffers = new Map();
let current = null, seq = 0;

export async function init() {
  const [a, v] = await Promise.all([fetch('data/audio.json?v=' + window.BVH_VERSION).then(r => r.json()), fetch('data/voice.json?v=' + window.BVH_VERSION).then(r => r.json())]);
  index = a; voice = v;
}

export function unlock() {
  // iPhone/iPad gạt nút im lặng thì Web Audio bị tắt tiếng; 'playback' cho app phát như nhạc/video (Safari 17+).
  try { if (navigator.audioSession && navigator.audioSession.type !== 'playback') navigator.audioSession.type = 'playback'; } catch (e) { /* máy cũ */ }
  if (!ctx) {
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return;
    ctx = new AC();
    master = ctx.createGain(); master.connect(ctx.destination);
    voiceBus = ctx.createGain(); voiceBus.connect(master);
    sfxBus = ctx.createGain(); sfxBus.gain.value = .5; sfxBus.connect(master);
    musicBus = ctx.createGain(); musicBus.gain.value = 0; musicBus.connect(master);
    // Chạy một buffer rỗng để iOS mở khoá loa.
    const b = ctx.createBuffer(1, 1, 22050), s = ctx.createBufferSource();
    s.buffer = b; s.connect(master); s.start(0);
  }
  if (ctx.state === 'suspended') ctx.resume();
}

document.addEventListener('visibilitychange', () => {
  if (!ctx) return;
  if (document.hidden) ctx.suspend(); else ctx.resume();
});

function load(file) {
  if (!buffers.has(file)) {
    buffers.set(file, fetch('audio/' + file).then(r => r.arrayBuffer())
      .then(b => new Promise((res, rej) => {
        // Safari cũ chỉ có dạng callback; Chrome trả thêm Promise, phải bắt để không văng lỗi.
        const p = ctx.decodeAudioData(b, res, rej);
        if (p && p.catch) p.catch(rej);
      }))
      .catch(() => { buffers.delete(file); return null; }));
  }
  return buffers.get(file);
}

// ---- Câu đọc ----
export const phrase = (key, lg = lang()) => [lg, (voice.phrases[key] || {})[lg] || ''];
// fx: biến đổi một trường trước khi ghép (phải khớp FX trong tools/build.py).
const FX = {
  spellFast: s => {
    const p = s.trim().replace(/\.+$/, '').split('. ');
    return p.length === 5 ? `${p[0]} ${p[1]} ${p[2]}, ${p[3]} ${p[4]}!` : p.length === 3 ? `${p[0]} ${p[1]}, ${p[2]}!` : p.join(', ') + '!';
  },
  spellComma: s => s.trim().replace(/\.+$/, '').split('. ').join(', ') + '.'
};
export function tpl(key, obj) {
  const t = voice.templates[key];
  if (!t) return null;
  const fx = t.fx || {};
  return [t.lang, t.text.replace(/\{(\w+)\}/g, (_, k) => obj[k] == null ? '' : fx[k] && FX[fx[k]] ? FX[fx[k]](String(obj[k])) : obj[k])];
}

export function preload(items) {
  if (!ctx) return;
  for (const [lg, text] of items) { const f = index[`${lg}|${text}`]; if (f) load(f); }
}

export function stopVoice() {
  seq++;
  if (current) { try { current.stop(); } catch (e) { /* đã dừng */ } current = null; }
}

// Đọc một câu [lang, text]; trả về Promise xong khi đọc hết (hoặc bị câu khác cắt ngang).
export async function say(item) {
  if (!item || !ctx || !settings().sound) return;
  const [lg, text] = item;
  const file = index[`${lg}|${text}`];
  stopVoice();
  const my = seq;
  if (!file) { console.warn('Thiếu câu đọc:', lg, text); return; }
  const buf = await load(file);
  if (!buf || my !== seq) return;
  const src = ctx.createBufferSource();
  src.buffer = buf; src.connect(voiceBus);
  current = src;
  duck(true);
  await new Promise(res => { src.onended = res; src.start(); });
  if (current === src) { current = null; duck(false); }
}

// Độ dài (giây) của một câu đọc, để tô sáng chữ theo giọng.
export async function clipDuration(item) {
  if (!item || !ctx) return 0;
  const file = index[`${item[0]}|${item[1]}`];
  const buf = file && await load(file);
  return buf ? buf.duration : 0;
}

export const sayPhrase = key => say(phrase(key));
// Đọc lần lượt nhiều câu; dừng nếu bị câu khác cắt ngang.
export async function sayAll(items) {
  // Nhận một câu [lang, text] hoặc mảng các câu.
  for (const it of Array.isArray(items?.[0]) ? items : [items]) {
    if (!it) continue;
    const my = seq;
    await say(it);
    if (seq !== my + 1) return;  // say() tự tăng seq một lần; tăng thêm nghĩa là bị cắt.
  }
}
// Câu khen ngẫu nhiên (không lặp liền câu trước), dạng [lang, text] để ghép với lời đọc khác.
let lastPraise = '';
export function praiseItem() {
  const keys = ['praise1', 'praise2', 'praise3', 'praise4', 'praise5', 'praise6'].filter(k => k !== lastPraise);
  lastPraise = pick(keys);
  return phrase(lastPraise);
}
const pick = a => a[Math.floor(Math.random() * a.length)];
export const praise = () => sayPhrase(pick(['praise1', 'praise2', 'praise3', 'praise4', 'praise5', 'praise6']));
export const retry = () => sayPhrase(pick(['retry1', 'retry2', 'retry3']));

// ---- Hiệu ứng ----
function tone(freq, start, dur, {type = 'sine', vol = .5, to = null, bus = sfxBus} = {}) {
  const o = ctx.createOscillator(), g = ctx.createGain();
  o.type = type;
  o.frequency.setValueAtTime(freq, start);
  if (to) o.frequency.exponentialRampToValueAtTime(to, start + dur);
  g.gain.setValueAtTime(0.0001, start);
  g.gain.exponentialRampToValueAtTime(vol, start + .012);
  g.gain.exponentialRampToValueAtTime(0.0001, start + dur);
  o.connect(g); g.connect(bus);
  o.start(start); o.stop(start + dur + .02);
}

export function sfx(name) {
  if (!ctx || !settings().sound) return;
  const t = ctx.currentTime + .01;
  switch (name) {
    case 'tap': tone(520, t, .09, {to: 880, vol: .35}); break;
    case 'flip': tone(380, t, .12, {type: 'triangle', to: 1100, vol: .3}); break;
    case 'count': tone(700, t, .14, {type: 'triangle', vol: .4}); tone(1050, t + .05, .12, {vol: .2}); break;
    case 'correct': [523, 659, 784, 1047].forEach((f, i) => tone(f, t + i * .07, .22, {type: 'triangle', vol: .45})); break;
    case 'wrong': tone(300, t, .28, {to: 170, vol: .4}); tone(240, t + .12, .26, {to: 140, vol: .3}); break;
    case 'star': tone(1320, t, .25, {type: 'triangle', vol: .4}); tone(1760, t + .08, .3, {vol: .3}); break;
    case 'win': [[523, 0], [659, .12], [784, .24], [1047, .4], [784, .55], [1047, .7]].forEach(([f, d]) => tone(f, t + d, .3, {type: 'triangle', vol: .45})); break;
    case 'pop': tone(900, t, .07, {to: 300, vol: .3}); break;
    case 'laser': tone(1400, t, .09, {type: 'square', to: 500, vol: .07}); break;
    case 'boom': tone(220, t, .3, {type: 'triangle', to: 50, vol: .5}); tone(660, t, .12, {to: 1500, vol: .15}); break;
    case 'coin': tone(988, t, .08, {type: 'square', vol: .1}); tone(1319, t + .07, .18, {type: 'square', vol: .1}); break;
    case 'jump': tone(330, t, .18, {type: 'triangle', to: 880, vol: .3}); break;
    case 'hit': tone(160, t, .35, {type: 'sawtooth', to: 60, vol: .18}); break;
    case 'power': [523, 659, 784, 1047, 1319].forEach((f, i) => tone(f, t + i * .05, .15, {type: 'square', vol: .08})); break;
    case 'bark': tone(620, t, .09, {type: 'square', to: 300, vol: .14}); tone(560, t + .16, .12, {type: 'square', to: 260, vol: .14}); break;
    case 'meow': tone(520, t, .45, {type: 'triangle', to: 880, vol: .25}); tone(880, t + .25, .3, {type: 'triangle', to: 600, vol: .2}); break;
    case 'squeak': tone(1500, t, .08, {to: 2200, vol: .15}); tone(1700, t + .1, .08, {to: 2400, vol: .12}); break;
    case 'eat': [0, .14, .28].forEach(d => tone(180, t + d, .07, {type: 'square', to: 90, vol: .12})); break;
    case 'splash': for (let k = 0; k < 6; k++) tone(1200 + Math.random() * 1500, t + k * .05, .06, {vol: .08}); break;
    case 'snore': tone(110, t, .8, {type: 'sawtooth', to: 80, vol: .05}); break;
    case 'shoot': tone(700, t, .12, {type: 'triangle', to: 1600, vol: .2}); break;
  }
}

// ---- Tiếng thật (thú cưng, game): file sfx/<tên>.mp3. Trả về hàm dừng, hoặc false nếu không phát được. ----
const clipBufs = new Map();
export async function clip(name, {rate = 1, vol = 1, loop = false} = {}) {
  if (!ctx || !settings().sound) return false;
  if (!clipBufs.has(name)) {
    clipBufs.set(name, fetch(`sfx/${name}.mp3?v=${window.BVH_VERSION}`).then(r => r.ok ? r.arrayBuffer() : null)
      .then(b => b && new Promise((res, rej) => { const p = ctx.decodeAudioData(b, res, rej); if (p && p.catch) p.catch(rej); }))
      .catch(() => null));
  }
  const buf = await clipBufs.get(name);
  if (!buf) return false;
  const src = ctx.createBufferSource(), g = ctx.createGain();
  src.buffer = buf; src.playbackRate.value = rate; src.loop = loop; g.gain.value = vol;
  src.connect(g); g.connect(sfxBus); src.start();
  return () => { try { g.gain.setTargetAtTime(0, ctx.currentTime, .05); src.stop(ctx.currentTime + .2); } catch (e) { /* đã dừng */ } };
}

// ---- Đàn: 8 phím Đô Rê Mi Fa Son La Si Đô (C4–C5), tiếng mộc cầm ----
export const NOTES = [261.6, 293.7, 329.6, 349.2, 392.0, 440.0, 493.9, 523.3];
export function note(i, dur = .9) {
  if (!ctx || !settings().sound) return;
  const f = NOTES[i] || i, t = ctx.currentTime + .005;
  tone(f, t, dur, {type: 'sine', vol: .55});
  tone(f * 2, t, dur * .45, {type: 'sine', vol: .18});
  tone(f * 4.01, t, .12, {type: 'triangle', vol: .08});
}

// ---- Tiếng động cơ cho game đua xe: level 0..1 (0 = tắt) ----
let eng = null;
export function engine(level) {
  if (!ctx || !settings().sound) return;
  if (!eng && level > 0) {
    const o = ctx.createOscillator(), o2 = ctx.createOscillator(), f = ctx.createBiquadFilter(), g = ctx.createGain();
    o.type = 'sawtooth'; o2.type = 'square'; f.type = 'lowpass'; f.frequency.value = 600; g.gain.value = 0;
    o.connect(f); o2.connect(f); f.connect(g); g.connect(sfxBus);
    o.start(); o2.start();
    eng = {o, o2, g, f};
  }
  if (!eng) return;
  const t = ctx.currentTime;
  if (level <= 0) { eng.g.gain.setTargetAtTime(0, t, .05); const e = eng; eng = null; setTimeout(() => { e.o.stop(); e.o2.stop(); }, 300); return; }
  eng.o.frequency.setTargetAtTime(55 + level * 110, t, .08);
  eng.o2.frequency.setTargetAtTime(27 + level * 55, t, .08);
  eng.f.frequency.setTargetAtTime(400 + level * 900, t, .08);
  eng.g.gain.setTargetAtTime(.05 + level * .05, t, .08);
}

// ---- Nhạc nền: hộp nhạc ngũ cung, nhịp nhẹ, tự lặp ----
const SCALE = [523, 587, 659, 784, 880, 1047, 1175, 1319];
const CHORDS = [[261, 329, 392], [220, 261, 329], [174, 220, 261], [196, 246, 293]];
let musicTimer = null, step = 0, nextAt = 0, melody = [];

function makeMelody() {
  melody = [];
  let i = 2;
  for (let n = 0; n < 32; n++) {
    i = Math.max(0, Math.min(SCALE.length - 1, i + pick([-2, -1, -1, 0, 1, 1, 2])));
    melody.push(n % 8 === 7 || Math.random() < .18 ? 0 : SCALE[i]);
  }
}

function schedule() {
  const beat = .34;
  while (nextAt < ctx.currentTime + .6) {
    const n = melody[step % 32];
    if (n) tone(n, nextAt, .5, {type: 'sine', vol: .5, bus: musicBus});
    if (step % 4 === 0) {
      const ch = CHORDS[Math.floor(step / 8) % 4];
      ch.forEach(f => tone(f, nextAt, 1.3, {type: 'triangle', vol: .16, bus: musicBus}));
    }
    nextAt += beat; step++;
    if (step % 64 === 0) makeMelody();
  }
}

let ducked = false;
function musicLevel() { return settings().music ? (ducked ? .025 : .07) : 0; }
function duck(on) {
  ducked = on;
  if (musicBus) musicBus.gain.setTargetAtTime(musicLevel(), ctx.currentTime, .15);
}

export function music() {
  if (!ctx) return;
  musicBus.gain.setTargetAtTime(musicLevel(), ctx.currentTime, .3);
  if (settings().music && !musicTimer) {
    makeMelody(); step = 0; nextAt = ctx.currentTime + .1;
    musicTimer = setInterval(schedule, 150);
  } else if (!settings().music && musicTimer) {
    clearInterval(musicTimer); musicTimer = null;
  }
}
