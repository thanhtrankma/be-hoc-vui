// Kiểm firestore.rules (gốc repo) trên Firestore emulator.
// Chạy ở gốc repo:
//   npm --prefix firestore-tests install
//   firebase emulators:exec --only firestore --project demo-bevuihoc 'npm --prefix firestore-tests test'
import {readFileSync} from 'node:fs';
import {after, before, beforeEach, test} from 'node:test';
import {assertFails, assertSucceeds, initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {collection, deleteDoc, doc, getDoc, getDocs, runTransaction, serverTimestamp, setDoc, Timestamp, updateDoc} from 'firebase/firestore';

const SID = 'a'.repeat(64);
const OTHER = '0123456789abcdef'.repeat(4);
let env;

before(async () => {
  const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080').split(':');
  env = await initializeTestEnvironment({
    projectId: 'demo-bevuihoc',
    firestore: {rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'), host, port: Number(port)},
  });
});
after(async () => env?.cleanup());
beforeEach(async () => env.clearFirestore());

const db = () => env.unauthenticatedContext().firestore();
const seed = (id, data) => env.withSecurityRulesDisabled(c => setDoc(doc(c.firestore(), 'syncs', id), data));

test('tạo ngăn hợp lệ (v int, blob string, at = serverTimestamp)', async () => {
  await assertSucceeds(setDoc(doc(db(), 'syncs', SID), {v: 1, blob: 'AAAA', at: serverTimestamp()}));
});

test('sid sai định dạng bị từ chối', async () => {
  for (const id of ['A'.repeat(64), 'a'.repeat(63), 'a'.repeat(65), 'g'.repeat(64), 'hello']) {
    await assertFails(setDoc(doc(db(), 'syncs', id), {v: 1, blob: 'x', at: serverTimestamp()}));
    await assertFails(getDoc(doc(db(), 'syncs', id)));
  }
});

test('dữ liệu tạo sai: thiếu/thừa khoá, sai kiểu, blob quá lớn, at không phải giờ máy chủ', async () => {
  const r = doc(db(), 'syncs', SID);
  await assertFails(setDoc(r, {v: 1, blob: 'x'}));
  await assertFails(setDoc(r, {v: 1, blob: 'x', at: serverTimestamp(), extra: true}));
  await assertFails(setDoc(r, {v: '1', blob: 'x', at: serverTimestamp()}));
  await assertFails(setDoc(r, {v: 1.5, blob: 'x', at: serverTimestamp()}));
  await assertFails(setDoc(r, {v: 1, blob: 123, at: serverTimestamp()}));
  await assertFails(setDoc(r, {v: 1, blob: 'x'.repeat(900001), at: serverTimestamp()}));
  await assertFails(setDoc(r, {v: 1, blob: 'x', at: Timestamp.fromMillis(0)}));
  await assertSucceeds(setDoc(r, {v: 1, blob: 'x'.repeat(900000), at: serverTimestamp()}));
});

test('get được khi biết sid; list bị cấm', async () => {
  await seed(SID, {v: 1, blob: 'x', at: Timestamp.now()});
  await assertSucceeds(getDoc(doc(db(), 'syncs', SID)));
  await assertSucceeds(getDoc(doc(db(), 'syncs', OTHER))); // chưa có → vẫn đọc được (trả không tồn tại)
  await assertFails(getDocs(collection(db(), 'syncs')));
});

test('cập nhật: v phải tăng đúng 1', async () => {
  await seed(SID, {v: 3, blob: 'x', at: Timestamp.now()});
  const r = doc(db(), 'syncs', SID);
  await assertFails(setDoc(r, {v: 3, blob: 'y', at: serverTimestamp()}));
  await assertFails(setDoc(r, {v: 5, blob: 'y', at: serverTimestamp()}));
  await assertFails(setDoc(r, {v: 2, blob: 'y', at: serverTimestamp()}));
  await assertFails(updateDoc(r, {blob: 'y'}));
  await assertSucceeds(setDoc(r, {v: 4, blob: 'y', at: serverTimestamp()}));
});

test('giao dịch như app: đọc v, ghi v + 1', async () => {
  await seed(SID, {v: 7, blob: 'x', at: Timestamp.now()});
  const d = db();
  const r = doc(d, 'syncs', SID);
  const v = await assertSucceeds(runTransaction(d, async tx => {
    const s = await tx.get(r);
    const nv = (s.exists() ? s.data().v : 0) + 1;
    tx.set(r, {v: nv, blob: 'z', at: serverTimestamp()});
    return nv;
  }));
  if (v !== 8) throw new Error(`v = ${v}`);
});

test('xoá ngăn khi biết sid', async () => {
  await seed(SID, {v: 1, blob: 'x', at: Timestamp.now()});
  await assertSucceeds(deleteDoc(doc(db(), 'syncs', SID)));
  await assertFails(deleteDoc(doc(db(), 'syncs', 'nope')));
});

test('bộ sưu tập khác bị cấm', async () => {
  await assertFails(setDoc(doc(db(), 'other', 'x'), {a: 1}));
  await assertFails(getDoc(doc(db(), 'other', 'x')));
  await assertFails(setDoc(doc(db(), 'syncs', SID, 'sub', 'x'), {a: 1}));
});
