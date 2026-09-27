import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const [inputPath] = process.argv.slice(2);
assert.ok(inputPath, 'usage: node test-host-compatibility.mjs PLUGIN_PATH');
const pluginPath = fs.realpathSync(inputPath);
const root = path.resolve(path.dirname(pluginPath), '../..');
const mod = await import(pathToFileURL(pluginPath).href);
const entry = await import(pathToFileURL(path.join(root, 'index.js')).href);
assert.equal(entry.MaxiPlugin, mod.MaxiPlugin);
assert.equal(entry.default, mod.default);
assert.equal(JSON.parse(fs.readFileSync(path.join(root, 'package.json'))).main, 'index.js');
assert.equal(mod.default.id, 'maxi');
assert.equal(mod.default.server, mod.MaxiPlugin);
assert.equal(typeof mod.default.setup, 'function');

const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'maxi-opencode-'));
try {
  const plain = path.join(temp, 'plain');
  const maxi = path.join(temp, 'maxi');
  const relativeMaxi = path.relative(process.cwd(), maxi);
  fs.mkdirSync(plain);
  fs.mkdirSync(path.join(maxi, 'docs', 'maxi'), { recursive: true });
  const marker = '<EXTREMELY_IMPORTANT>\nYou have maxi.';
  const count = (event) => event.messages.flatMap((m) => m.parts ?? m.content ?? [])
    .filter((p) => p.type === 'text' && p.text?.startsWith(marker)).length;
  const event = (flavor, id, messages) => ({
    sessionID: id,
    messages: messages ?? [flavor === 'v1'
      ? { info: { role: 'user', sessionID: id }, parts: [{ type: 'text', text: 'Continue' }] }
      : { role: 'user', content: [{ type: 'text', text: 'Continue' }] }],
  });

  let sessionById = new Map();
  const client = { session: { get: async ({ path: { id } }) => ({ data: sessionById.get(id) }) } };
  const v1 = await mod.MaxiPlugin({ client, directory: maxi });
  const invokeV1 = (e) => v1['experimental.chat.messages.transform']({}, e);
  for (const [id, info, expected] of [
    ['root', { directory: maxi }, 1],
    ['child', { directory: maxi, parentID: 'root' }, 0],
    ['fork', { directory: maxi }, 1],
  ]) {
    sessionById.set(id, { id, ...info });
    const e = event('v1', id);
    await invokeV1(e);
    assert.equal(count(e), expected, `V1 ${id}`);
    await invokeV1(e);
    assert.equal(count(e), expected, `V1 ${id} repeated`);
    const fresh = event('v1', id);
    await invokeV1(fresh);
    assert.equal(count(fresh), expected, `V1 ${id} fresh`);
  }
  const plainV1 = await mod.MaxiPlugin({ client, directory: plain });
  const plainEvent = event('v1', 'plain');
  sessionById.set('plain', { id: 'plain', directory: plain });
  await plainV1['experimental.chat.messages.transform']({}, plainEvent);
  assert.equal(count(plainEvent), 0);
  const afterPlainV1 = event('v1', 'after-plain');
  sessionById.set('after-plain', { id: 'after-plain', directory: maxi });
  await invokeV1(afterPlainV1);
  assert.equal(count(afterPlainV1), 1);
  const relativeV1 = event('v1', 'relative-v1');
  sessionById.set('relative-v1', { id: 'relative-v1', directory: relativeMaxi });
  await invokeV1(relativeV1);
  assert.equal(count(relativeV1), 0, 'V1 rejects a relative session directory');
  const fallbackV1 = event('v1', 'fallback-v1');
  sessionById.set('fallback-v1', { id: 'fallback-v1' });
  await invokeV1(fallbackV1);
  assert.equal(count(fallbackV1), 1, 'V1 uses an absolute plugin directory fallback');
  const missingV1 = event('v1', 'missing-v1');
  sessionById.set('missing-v1', { id: 'missing-v1' });
  const relativePlugin = await mod.MaxiPlugin({ client, directory: relativeMaxi });
  await relativePlugin['experimental.chat.messages.transform']({}, missingV1);
  assert.equal(count(missingV1), 0, 'V1 rejects a relative plugin directory fallback');
  let v1Attempts = 0;
  const retryV1 = await mod.MaxiPlugin({ directory: maxi, client: { session: {
    get: async () => { if (++v1Attempts === 1) throw new Error('temporary lookup failure');
      return { data: { id: 'v1-retry', directory: maxi } }; },
  } } });
  const unknownV1 = event('v1', 'v1-retry');
  await retryV1['experimental.chat.messages.transform']({}, unknownV1);
  assert.equal(count(unknownV1), 0, 'V1 waits for a verified session identity');
  const recoveredV1 = event('v1', 'v1-retry');
  await retryV1['experimental.chat.messages.transform']({}, recoveredV1);
  assert.equal(count(recoveredV1), 1, 'V1 retries after a transient lookup failure');
  assert.equal(v1Attempts, 2);
  await mod.default.setup({}); // V1 calls setup with no V2 domains.

  const expectedIds = fs.readdirSync(path.join(root, 'skills'), { withFileTypes: true })
    .filter((d) => d.isDirectory() && fs.existsSync(path.join(root, 'skills', d.name, 'SKILL.md')))
    .map((d) => d.name).sort();
  assert.equal(expectedIds.length, 34);
  const registered = [];
  let invokeV2;
  const sessionGet = async ({ sessionID }) => sessionById.get(sessionID);
  const context = (add) => ({
    location: { directory: maxi },
    skill: { transform: async (fn) => fn({ list: () => [], add, update() {}, remove() {} }) },
    session: {
      get: sessionGet,
      hook: async (name, callback) => { if (name === 'context') invokeV2 = callback; },
    },
  });
  await mod.default.setup(context((skill) => registered.push(skill)));
  assert.equal(typeof invokeV2, 'function');
  assert.equal(registered.length, 34);
  assert.deepEqual(registered.map((s) => s.id).sort(), expectedIds);
  assert.ok(registered.every((s) => typeof s.path === 'string' && path.isAbsolute(s.path)
    && fs.existsSync(s.path) && !('location' in s) && typeof s.content === 'string'
    && !s.content.startsWith('---')));
  assert.ok(registered.every((s) => s.name && (!s.description || typeof s.description === 'string')));
  for (const [id, info, expected] of [
    ['v2-root', { location: { directory: maxi } }, 1],
    ['v2-child', { location: { directory: maxi }, parentID: 'v2-root' }, 0],
    ['v2-fork', { location: { directory: maxi }, fork: { sessionID: 'v2-root' } }, 1],
    ['v2-plain', { location: { directory: plain } }, 0],
  ]) {
    sessionById.set(id, { id, ...info });
    const e = event('v2', id);
    await invokeV2(e);
    assert.equal(count(e), expected, `V2 ${id}`);
    await invokeV2(e);
    assert.equal(count(e), expected, `V2 ${id} repeated`);
    const fresh = event('v2', id);
    await invokeV2(fresh);
    assert.equal(count(fresh), expected, `V2 ${id} fresh`);
  }
  sessionById.set('v2-later-maxi', { id: 'v2-later-maxi', location: { directory: maxi } });
  const later = event('v2', 'v2-later-maxi');
  await invokeV2(later);
  assert.equal(count(later), 1, 'plain project cache must not suppress later Maxi project');
  for (const [id, info] of [
    ['v2-missing', {}],
    ['v2-relative', { location: { directory: relativeMaxi } }],
  ]) {
    sessionById.set(id, { id, ...info });
    const unknown = event('v2', id);
    await invokeV2(unknown);
    assert.equal(count(unknown), 0, `V2 rejects ${id} project identity`);
  }
  sessionById.set('v2-moved', { id: 'v2-moved', location: { directory: plain } });
  const beforeMove = event('v2', 'v2-moved');
  await invokeV2(beforeMove);
  assert.equal(count(beforeMove), 0);
  sessionById.set('v2-moved', { id: 'v2-moved', location: { directory: maxi } });
  const afterMove = event('v2', 'v2-moved');
  await invokeV2(afterMove);
  assert.equal(count(afterMove), 1, 'a moved session uses its current location');
  const compacted = event('v2', 'v2-later-maxi', [{ role: 'assistant', content: [{ type: 'compaction', encrypted: 'opaque' }] }]);
  const checkpoint = structuredClone(compacted.messages[0]);
  await invokeV2(compacted);
  assert.equal(count(compacted), 1);
  assert.deepEqual(compacted.messages[0], checkpoint);
  const childCompacted = event('v2', 'v2-child', [{ role: 'assistant', content: [{ type: 'compaction', encrypted: 'opaque' }] }]);
  await invokeV2(childCompacted);
  assert.equal(count(childCompacted), 0);
  assert.equal(childCompacted.messages.length, 1);

  sessionById.set('retry', { id: 'retry', location: { directory: maxi }, parentID: 'v2-root' });
  let attempts = 0;
  await mod.default.setup({ ...context((skill) => registered.push(skill)), session: {
    get: async () => { if (++attempts === 1) throw new Error('temporary lookup failure'); return sessionById.get('retry'); },
    hook: async (_name, callback) => { invokeV2 = callback; },
  } });
  const unavailable = event('v2', 'retry');
  await invokeV2(unavailable);
  assert.equal(count(unavailable), 0, 'V2 must not guess a project on lookup failure');
  const recovered = event('v2', 'retry');
  await invokeV2(recovered);
  assert.equal(count(recovered), 0);
  assert.equal(attempts, 2, 'transient failure must be retried');

  const rejected = expectedIds[10];
  const survivors = [];
  const originalError = console.error;
  try {
    console.error = () => {};
    await mod.default.setup(context((skill) => {
      if (skill.id === rejected) throw new Error('host rejected one Skill.Info');
      survivors.push(skill.id);
    }));
  } finally {
    console.error = originalError;
  }
  assert.equal(survivors.length, 33);
  assert.ok(!survivors.includes(rejected));
  const survivedEvent = event('v2', 'v2-root');
  await invokeV2(survivedEvent);
  assert.equal(count(survivedEvent), 1);
  console.log('OpenCode V1/V2 host compatibility: PASS');
} finally {
  fs.rmSync(temp, { recursive: true, force: true });
}
