const { test } = require('node:test');
const assert = require('node:assert/strict');
const { Timestamp } = require('firebase-admin/firestore');
const { validID, validSummary, commandDocument, validateAction } = require('../lib/commandProtocol');

test('normalization preserves UTF-16 boundary and rejects empty or oversized input', () => {
  assert.equal(validSummary('  write hello  '), 'write hello');
  assert.equal(validSummary('😀'.repeat(250)).length, 500);
  for (const input of ['', '  ', null, '😀'.repeat(251)]) assert.throws(() => validSummary(input));
  assert.throws(() => validID('../another/path'));
  assert.match(validID(undefined, true), /^[a-f0-9-]{36}$/);
});
test('fixture has server-relative deadlines and explicit inapplicable fields', () => {
  const fixture = require('../../../docs/fixtures/command-v2.json');
  const document = commandDocument(fixture.requestId, 'computerUse', null, fixture.taskSummary, Timestamp.fromMillis(1000));
  assert.equal(document.expiresAt.toMillis(), 61000);
  assert.equal(document.reportingDeadline.toMillis(), 301000);
  assert.equal(document.url, null);
  assert.equal(document.result, null);
  assert.equal(document.target, 'com.apple.TextEdit');
});
test('actions cannot switch apps, open dialogs, inject fields or default coordinates', () => {
  assert.deepEqual(validateAction('keypress', { keys: ['cmd', 's'] }), { type: 'keypress', keys: ['cmd', 's'] });
  for (const [name, args] of [['click', { x: 10, y: 10 }], ['type', {}], ['type', { text: 'ok', x: 1 }], ['keypress', { keys: ['cmd', 'o'] }], ['keypress', { keys: [] }], ['wait', { seconds: 5 }]]) {
    assert.throws(() => validateAction(name, args), error => error.details.failureCode === 'invalidModelAction');
  }
});
