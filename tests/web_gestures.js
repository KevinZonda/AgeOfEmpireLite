const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const listeners = new Map();
const canvas = {
	width: 1600, height: 1000,
	getBoundingClientRect: () => ({ left: 10, top: 20, width: 800, height: 500 }),
	addEventListener(name, callback, options) {
		assert.equal(options.capture, true);
		assert.equal(options.passive, false);
		listeners.set(name, callback);
	},
	removeEventListener(name, callback, capture) {
		assert.equal(capture, true);
		assert.equal(listeners.get(name), callback);
		listeners.delete(name);
	},
};
const context = { window: {}, document: { getElementById: () => canvas } };
vm.runInNewContext(fs.readFileSync('scripts/player/web_gestures.js', 'utf8'), context);
const gestures = [];
const handle = context.window.AoeWebGestures.install((...args) => gestures.push(args));
function wheel(values) {
	const event = {
		deltaMode: 0, deltaX: 0, deltaY: 0, ctrlKey: false,
		clientX: 210, clientY: 120, prevented: false, stopped: false,
		preventDefault() { this.prevented = true; },
		stopImmediatePropagation() { this.stopped = true; },
		...values,
	};
	listeners.get('wheel')(event);
	return event;
}

// Vertical, horizontal, diagonal and fast trackpad swipes pan without zooming.
for (const delta of [[0, 7.5], [8, 0], [-2, -4], [0, 100]]) {
	const [deltaX, deltaY] = delta;
	const event = wheel({ deltaX, deltaY, wheelDeltaY: -3 * deltaY });
	assert.equal(event.stopped, true);
	assert.equal(event.prevented, true);
	assert.deepEqual(gestures.pop(), ['pan', deltaX * 2, deltaY * 2, 400, 200]);
}

// Physical mouse notches pass through to Godot, never invoking the gesture path.
for (const values of [{deltaMode: 1, deltaY: 3}, {deltaY: 100}, {deltaY: -120}, {deltaY: 53, wheelDeltaY: -120}]) {
	const event = wheel(values);
	assert.equal(event.stopped, false);
	assert.equal(event.prevented, false);
	assert.equal(gestures.length, 0);
}

// Browser pinch is ctrl+wheel even when the physical Ctrl key isn't held.
wheel({ deltaY: -2, ctrlKey: true });
assert.deepEqual(gestures.pop(), ['magnify', Math.exp(0.02), 0, 400, 200]);
assert.equal(wheel({}).stopped, false);
handle.dispose();
assert.equal(listeners.size, 0);
console.log('WEB_GESTURES_JS_OK');
