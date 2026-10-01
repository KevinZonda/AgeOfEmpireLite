// Exercise the exported shell's startup logic without downloading the engine.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const shell = fs.readFileSync('tools/web_shell.html', 'utf8');
const script = shell.match(/<script>\s*([\s\S]*?)<\/script>/)[1]
  .replace('$GODOT_CONFIG', JSON.stringify({
    serviceWorker: 'index.service.worker.js', ensureCrossOriginIsolationHeaders: true,
  }))
  .replace('$GODOT_THREADS_ENABLED', 'true');

function eventTarget(extra = {}) {
  const listeners = new Map();
  return Object.assign(extra, {
    addEventListener(name, callback) { listeners.set(name, callback); },
    removeEventListener(name) { listeners.delete(name); },
    emit(name) { listeners.get(name)?.(); },
  });
}

function run({ isolated = false, registration, failure, stored = 0, unsupported = false } = {}) {
  const notices = [];
  const elements = Object.fromEntries(['status', 'status-progress', 'status-notice'].map(id => [id, {
    style: {}, remove() { this.removed = true; }, appendChild(node) { notices.push(node.text || ''); },
    removeAttribute() {},
  }]));
  const timers = new Map();
  const storage = new Map(stored ? [['aoe-isolation-reload:index.service.worker.js', String(stored)]] : []);
  const result = { reloads: 0, starts: 0, notices, elements, timers, storage };
  class Engine {
    static getMissingFeatures({ threads }) {
      return unsupported ? ['WebGL2'] : threads && !isolated ? ['Cross-Origin Isolation'] : [];
    }
    installServiceWorker() { return failure ? Promise.reject(failure) : Promise.resolve(registration); }
    startGame() { result.starts++; return Promise.resolve(); }
  }
  vm.runInNewContext(script, {
    Engine, Error, navigator: { serviceWorker: {} }, console: { error() {} },
    document: { getElementById: id => elements[id], createTextNode: text => ({ text }), createElement: () => ({}) },
    sessionStorage: { getItem: key => storage.get(key), setItem: (key, value) => storage.set(key, value), removeItem: key => storage.delete(key) },
    window: { location: { reload() { result.reloads++; } } },
    setTimeout: callback => { const key = {}; timers.set(key, callback); return key; },
    clearTimeout: key => timers.delete(key),
  });
  return result;
}

async function flush() { for (let i = 0; i < 10; i++) await Promise.resolve(); }

(async () => {
  // First visit: registration alone must not reload while precaching is pending.
  const worker = eventTarget({ state: 'installing', postMessage() {} });
  const registration = eventTarget({ installing: worker });
  const first = run({ registration });
  await flush();
  assert.equal(first.reloads, 0);
  assert.match(first.notices.join(''), /正在准备/);
  worker.state = 'activated';
  registration.installing = null;
  registration.active = worker;
  worker.emit('statechange');
  await flush();
  assert.equal(first.reloads, 1);
  assert.equal(first.timers.size, 0);

  // Recover a prior interrupted visit with an existing active registration.
  const existing = run({ registration });
  await flush();
  assert.equal(existing.reloads, 1);

  // A waiting installation can activate despite another open tab.
  const waiting = eventTarget({ state: 'installed', postMessage(message) {
    assert.equal(message, 'claim');
    this.state = 'activated';
    pending.waiting = null;
    pending.active = this;
    this.emit('statechange');
  } });
  const pending = eventTarget({ waiting });
  const update = run({ registration: pending });
  await flush();
  assert.equal(update.reloads, 1);

  const failed = run({ failure: new Error('Registration denied') });
  await flush();
  assert.match(failed.notices.join(''), /Registration denied/);
  assert.equal(failed.elements.status.style.visibility, 'visible');
  assert.equal(failed.reloads, 0);

  const stalled = run({ registration: eventTarget({ installing: eventTarget({ state: 'installing' }) }) });
  await flush();
  [...stalled.timers.values()].forEach(callback => callback());
  await flush();
  assert.match(stalled.notices.join(''), /超时/);
  assert.equal(stalled.reloads, 0);

  const loop = run({ registration, stored: Date.now() });
  await flush();
  assert.equal(loop.reloads, 0);
  assert.match(loop.notices.join(''), /未启用多线程/);

  const unsupported = run({ unsupported: true });
  await flush();
  assert.equal(unsupported.reloads, 0);
  assert.match(unsupported.notices.join(''), /WebGL2/);

  const ready = run({ isolated: true, stored: Date.now() });
  await flush();
  assert.equal(ready.starts, 1);
  assert.equal(ready.elements.status.removed, true);
  assert.equal(ready.storage.size, 0);
  console.log('WEB_BOOTSTRAP_OK');
})().catch(error => { console.error(error); process.exitCode = 1; });
