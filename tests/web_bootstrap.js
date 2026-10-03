// Exercise the exported shell's startup logic without downloading the engine.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const shell = fs.readFileSync('tools/web_shell.html', 'utf8');
const script = shell.match(/<script>\s*([\s\S]*?)<\/script>/)[1]
  .replace('$GODOT_CONFIG', JSON.stringify({
    serviceWorker: 'index.service.worker.js', ensureCrossOriginIsolationHeaders: true,
    executable: 'index', fileSizes: {'index.pck': 10, 'index.wasm': 20},
  }))
  .replace('$GODOT_THREADS_ENABLED', 'true');

function eventTarget(extra = {}) {
  const listeners = new Map();
  return Object.assign(extra, {
    addEventListener(name, callback) { listeners.set(name, callback); },
    removeEventListener(name) { listeners.delete(name); },
    emit(name) { return listeners.get(name)?.(); },
  });
}

function run({ isolated = false, registration, failure, stored = 0, unsupported = false,
  scriptError, startFailure, fetchFailure = false, fetchPending = false } = {}) {
  const notices = [];
  const elements = Object.fromEntries(['status', 'status-progress', 'status-notice', 'status-details', 'status-error-log', 'status-retry'].map(id => [id, eventTarget({
    style: {}, remove() { this.removed = true; }, appendChild(node) { notices.push(node.text || ''); },
    removeAttribute() {},
  })]));
  const timers = new Map();
  const storage = new Map(stored ? [['aoe-isolation-reload:index.service.worker.js', String(stored)]] : []);
  const result = { reloads: 0, starts: 0, notices, elements, timers, storage, updates: 0, deletedCaches: [], requests: [] };
  if (registration && !registration.update) registration.update = async () => { result.updates++; };
  class Engine {
    static getMissingFeatures({ threads }) {
      return unsupported ? ['WebGL2'] : threads && !isolated ? ['Cross-Origin Isolation'] : [];
    }
    installServiceWorker() { return failure ? Promise.reject(failure) : Promise.resolve(registration); }
    startGame(options) {
      result.starts++;
      result.engineOptions = options;
      if (scriptError) options.onPrintError(scriptError);
      return startFailure ? Promise.reject(startFailure) : Promise.resolve();
    }
  }
  vm.runInNewContext(script, {
    Engine, Error, AbortController, navigator: { serviceWorker: {} }, console: { error() {} },
    document: { getElementById: id => elements[id], createTextNode: text => ({ text }), createElement: () => ({}) },
    sessionStorage: { getItem: key => storage.get(key), setItem: (key, value) => storage.set(key, value), removeItem: key => storage.delete(key) },
    window: {
      location: { reload() { result.reloads++; } },
      caches: {
        async keys() { return ['Age of Empire Li-sw-cache-old', 'another-app']; },
        async delete(key) { result.deletedCaches.push(key); return true; },
      },
    },
    fetch: async (file, options) => {
      result.requests.push({file, options});
      if (fetchPending) return new Promise(() => {});
      return {ok: !fetchFailure, status: fetchFailure ? 503 : 200, async arrayBuffer() { return new ArrayBuffer(0); }};
    },
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
  assert.match(failed.elements['status-error-log'].textContent, /Registration denied/);
  assert.equal(failed.elements.status.style.visibility, 'visible');
  assert.equal(failed.reloads, 0);

  const stalled = run({ registration: eventTarget({ installing: eventTarget({ state: 'installing' }) }) });
  await flush();
  [...stalled.timers.values()].forEach(callback => callback());
  await flush();
  assert.match(stalled.elements['status-error-log'].textContent, /超时/);
  assert.equal(stalled.reloads, 0);

  const loop = run({ registration, stored: Date.now() });
  await flush();
  assert.equal(loop.reloads, 0);
  assert.match(loop.elements['status-error-log'].textContent, /未启用多线程/);

  const unsupported = run({ unsupported: true });
  await flush();
  assert.equal(unsupported.reloads, 0);
  assert.match(unsupported.elements['status-error-log'].textContent, /WebGL2/);

  const ready = run({ isolated: true, stored: Date.now() });
  await flush();
  assert.equal(ready.starts, 1);
  assert.equal(ready.elements.status.style.visibility, 'hidden');
  assert.equal(ready.storage.size, 0);

  // Godot can print a parse error and still resolve startGame successfully.
  const broken = run({isolated: true, registration, scriptError: 'SCRIPT ERROR: Parse Error: Could not find type "RtsNavigation"'});
  await flush();
  assert.equal(broken.elements.status.style.visibility, 'visible');
  assert.equal(broken.elements['status-retry'].style.display, 'block');
  assert.match(broken.elements['status-error-log'].textContent, /RtsNavigation/);
  assert.equal(broken.reloads, 0, 'errors must not trigger an automatic reload loop');
  broken.engineOptions.onPrintError('   at: GDScript::reload (res://scripts/game.gd:127)');
  assert.match(broken.elements['status-error-log'].textContent, /game.gd:127/);

  // Errors printed after startup must also reveal the recovery panel.
  ready.engineOptions.onPrintError('ERROR: Failed to load script "res://scripts/game.gd"');
  assert.equal(ready.elements.status.style.visibility, 'visible');

  // A new worker must finish installing even while an old one is active.
  const newWorker = eventTarget({state: 'installing', postMessage(message) {
    assert.equal(message, 'claim');
    this.state = 'activated';
    replacement.waiting = null;
    replacement.active = this;
    this.emit('statechange');
  }});
  const replacement = eventTarget({active: eventTarget({state: 'activated'}), async update() {
    replacement.installing = newWorker;
  }});
  const retry = run({isolated: true, registration: replacement, startFailure: new Error('Download failed')});
  await flush();
  const attempt = retry.elements['status-retry'].emit('click');
  await flush();
  assert.equal(retry.elements['status-retry'].disabled, true);
  assert.equal(retry.requests.length, 0, 'do not refresh assets through the old worker');
  assert.equal(retry.reloads, 0);
  await retry.elements['status-retry'].emit('click');
  replacement.installing = null;
  replacement.waiting = newWorker;
  newWorker.state = 'installed';
  newWorker.emit('statechange');
  await attempt;
  assert.equal(retry.reloads, 1);
  assert.deepEqual(retry.deletedCaches, ['Age of Empire Li-sw-cache-old']);
  assert.deepEqual(retry.requests.map(r => r.file), ['index.html', 'index.js', 'index.pck', 'index.wasm']);
  assert(retry.requests.every(r => r.options.cache === 'reload'));
  assert.equal(retry.timers.size, 0);

  const unavailable = run({isolated: true, registration, startFailure: new Error('Download failed'), fetchFailure: true});
  await flush();
  await unavailable.elements['status-retry'].emit('click');
  assert.equal(unavailable.reloads, 0);
  assert.equal(unavailable.elements['status-retry'].disabled, false);
  assert.match(unavailable.elements['status-error-log'].textContent, /HTTP 503/);

  const slow = run({isolated: true, registration, startFailure: new Error('Download failed'), fetchPending: true});
  await flush();
  const slowAttempt = slow.elements['status-retry'].emit('click');
  await flush();
  [...slow.timers.values()].forEach(callback => callback());
  await slowAttempt;
  assert.equal(slow.reloads, 0);
  assert.equal(slow.elements['status-retry'].disabled, false);
  assert(slow.requests.every(r => r.options.signal.aborted));
  assert.match(slow.elements['status-error-log'].textContent, /更新超时/);
  console.log('WEB_BOOTSTRAP_OK');
})().catch(error => { console.error(error); process.exitCode = 1; });
