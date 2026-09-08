const { before, after, beforeEach, test } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc, getDoc, serverTimestamp, Timestamp } = require('firebase/firestore');
let env;
const id = 'request-0001';
const base = () => ({ schemaVersion: 2, requestId: id, type: 'computerUse', url: null, taskSummary: 'Write hello', target: 'com.apple.TextEdit', createdAt: Timestamp.now(), expiresAt: Timestamp.fromMillis(Date.now() + 60000), reportingDeadline: Timestamp.fromMillis(Date.now() + 300000), status: 'pending', claimedByDeviceId: null, claimedAt: null, startedAt: null, finishedAt: null, steps: [], result: null, failureCode: null });
const ref = (uid = 'alice', provider = 'google.com', owner = uid) => doc(env.authenticatedContext(uid, { firebase: { sign_in_provider: provider } }).firestore(), `users/${owner}/commands/${id}`);
async function seed(overrides = {}) { await env.withSecurityRulesDisabled(ctx => setDoc(doc(ctx.firestore(), `users/alice/commands/${id}`), { ...base(), ...overrides })); }
before(async () => { env = await initializeTestEnvironment({ projectId: 'demo-caocap', firestore: { rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8') } }); });
after(async () => env?.cleanup());
beforeEach(async () => { await env.clearFirestore(); await seed(); });
test('anonymous and cross-account reads and client creation are denied', async () => {
  await assertFails(getDoc(ref('alice', 'anonymous')));
  await assertFails(getDoc(ref('bob', 'google.com', 'alice')));
  await assertFails(setDoc(doc(env.authenticatedContext('alice').firestore(), 'users/alice/commands/new-request'), base()));
  await assertSucceeds(getDoc(ref()));
});
test('claim freezes request and claimant fields and rejects unknown fields', async () => {
  const claim = { status: 'claimed', claimedAt: serverTimestamp(), claimedByDeviceId: 'mac-1' };
  await assertFails(updateDoc(ref(), { ...claim, surprise: true }));
  await assertFails(updateDoc(ref(), { ...claim, taskSummary: 'different' }));
  await assertSucceeds(updateDoc(ref(), claim));
  await assertFails(updateDoc(ref(), { claimedByDeviceId: 'mac-2' }));
  await assertFails(updateDoc(ref(), { status: 'completed', finishedAt: serverTimestamp() }));
  await assertSucceeds(updateDoc(ref(), { status: 'running', startedAt: serverTimestamp() }));
});
test('expired commands cannot be claimed; unexpired commands cannot expire', async () => {
  await assertFails(updateDoc(ref(), { status: 'expired', finishedAt: serverTimestamp() }));
  await seed({ expiresAt: Timestamp.fromMillis(Date.now() - 1000) });
  await assertFails(updateDoc(ref(), { status: 'claimed', claimedAt: serverTimestamp(), claimedByDeviceId: 'mac-1' }));
  await assertSucceeds(updateDoc(ref(), { status: 'expired', finishedAt: serverTimestamp() }));
});
test('progress and result are bounded and terminal states cannot be replayed', async () => {
  await seed({ status: 'running', claimedByDeviceId: 'mac-1', claimedAt: Timestamp.now(), startedAt: Timestamp.now() });
  await assertFails(updateDoc(ref(), { steps: [{ index: 2, summary: 'wrong' }] }));
  await assertFails(updateDoc(ref(), { steps: Array.from({ length: 21 }, (_, i) => ({ index: i + 1, summary: 'step' })) }));
  await assertSucceeds(updateDoc(ref(), { steps: [{ index: 1, summary: 'Typed document' }] }));
  for (let i = 2; i <= 20; i++) await assertSucceeds(updateDoc(ref(), { steps: Array.from({ length: i }, (_, index) => ({ index: index + 1, summary: index === 0 ? 'Typed document' : 'step' })) }));
  const completed = { status: 'completed', finishedAt: serverTimestamp(), result: { fileName: 'CAOCAP-test.txt', previewText: 'Hello', previewTruncated: false } };
  for (const result of [{ ...completed.result, fileName: '/private/test.txt' }, { ...completed.result, previewText: '' }, { ...completed.result, previewText: 'x'.repeat(8001) }, { ...completed.result, path: '/tmp' }]) await assertFails(updateDoc(ref(), { ...completed, result }));
  await assertSucceeds(updateDoc(ref(), completed));
  await assertFails(updateDoc(ref(), { status: 'running' }));
});
