const { before, beforeEach, after, test } = require('node:test');
const assert = require('node:assert/strict');
const { initializeApp, deleteApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { createCommand } = require('../lib/commandProtocol');
const { executeComputerUseStep } = require('../lib/computerUse');
let app, db;
const png = Buffer.alloc(24); png.write('89504e470d0a1a0a', 'hex'); png.writeUInt32BE(1, 16); png.writeUInt32BE(1, 20);
const input = (runId, stepIndex = 0) => ({ runId, stepIndex, taskSummary: 'Write hello', screenshotBase64: png.toString('base64') });
const response = (name = 'wait', args = {}) => new Response(JSON.stringify({ id: 'response-1', output: [{ type: 'function_call', name, arguments: JSON.stringify(args), call_id: 'call-1' }] }));
before(() => { assert.ok(process.env.FIRESTORE_EMULATOR_HOST, 'Integration tests require the Firestore emulator'); app = initializeApp({ projectId: 'demo-caocap' }); db = getFirestore(); });
after(() => deleteApp(app));
beforeEach(async () => {
  await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/demo-caocap/databases/(default)/documents`, { method: 'DELETE' });
  await db.doc('serviceControls/computerUse').set({ enabled: true });
});
test('duplicate command requests reserve once and conflicting inputs never change expiry', async () => {
  const results = await Promise.all(Array.from({ length: 8 }, () => createCommand('alice', 'request-0001', 'computerUse', null, 'Write hello')));
  assert.equal(results.filter(r => !r.alreadyExisted).length, 1);
  const before = (await db.doc('users/alice/commands/request-0001').get()).data();
  await assert.rejects(createCommand('alice', 'request-0001', 'computerUse', null, 'Write goodbye'), { code: 'already-exists' });
  assert.equal((await db.doc('commandUsage/alice').get()).data().count, 1);
  assert.equal((await db.doc('users/alice/commands/request-0001').get()).data().expiresAt.toMillis(), before.expiresAt.toMillis());
});
test('command quota races admit six new commands', async () => {
  const results = await Promise.allSettled(Array.from({ length: 10 }, (_, i) => createCommand('alice', `request-${i.toString().padStart(4, '0')}`, 'openYouTube', 'https://www.youtube.com', null)));
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 6);
});
test('daily quota is reserved before concurrent upstream calls', async () => {
  await db.doc('serviceControls/computerUse').set({ enabled: true, globalDailyLimit: 1 });
  let calls = 0;
  const transport = async () => { calls++; return response(); };
  const outcomes = await Promise.allSettled([executeComputerUseStep('alice', input('run-00001'), 'test', transport), executeComputerUseStep('bob', input('run-00002'), 'test', transport)]);
  assert.equal(outcomes.filter(r => r.status === 'fulfilled').length, 1);
  assert.equal(calls, 1);
});
test('continuations are server-owned, sequential, and cached retries spend once', async () => {
  let calls = 0;
  const transport = async (_, options) => {
    calls++; const body = JSON.parse(options.body);
    assert.equal(body.parallel_tool_calls, false);
    assert.equal(body.previous_response_id, calls === 1 ? undefined : 'response-1');
    return response();
  };
  await executeComputerUseStep('alice', { ...input('run-00001'), previousResponseId: 'foreign' }, 'test', transport);
  await executeComputerUseStep('alice', input('run-00001'), 'test', transport);
  assert.equal(calls, 1);
  await assert.rejects(executeComputerUseStep('bob', input('run-00001', 1), 'test', transport), { code: 'failed-precondition' });
  await executeComputerUseStep('alice', input('run-00001', 1), 'test', transport);
  assert.equal(calls, 2);
  await assert.rejects(executeComputerUseStep('alice', { ...input('run-00001', 2), taskSummary: 'changed' }, 'test', transport), { code: 'already-exists' });
});
test('kill switch, remote ownership, unsupported actions and step cap fail closed', async () => {
  await assert.rejects(executeComputerUseStep('alice', { ...input('run-00001'), commandId: 'request-0001' }, 'test', async () => response()), { code: 'permission-denied' });
  await assert.rejects(executeComputerUseStep('alice', input('run-00002'), 'test', async () => response('click', { x: 0, y: 0 })), error => error.details.failureCode === 'invalidModelAction');
  await assert.rejects(executeComputerUseStep('alice', input('run-00003', 20), 'test'), error => error.details.failureCode === 'stepLimitExceeded');
  await db.doc('serviceControls/computerUse').set({ enabled: false });
  await assert.rejects(executeComputerUseStep('alice', input('run-00004'), 'test'), error => error.details.failureCode === 'serviceUnavailable');
  await assert.rejects(createCommand('alice', 'request-0001', 'computerUse', null, 'Write hello'), { code: 'unavailable' });
});
