// Godot Web turns every DOM wheel into mouse-wheel buttons, losing pinch intent.
// Translate continuous trackpad motion before that listener sees it.
(function () {
	function isDiscreteWheel(event) {
		if (event.deltaMode !== 0) return true;
		if (event.deltaX !== 0) return false;
		const legacy = event.wheelDeltaY;
		if (Number.isFinite(legacy) && legacy !== 0) {
			// Chromium trackpads report wheelDeltaY = -3 * deltaY, including
			// fast swipes. Physical wheel notches commonly report multiples of 120.
			return Math.abs(legacy % 120) < 0.001 && Math.abs(legacy + 3 * event.deltaY) > 0.001;
		}
		// Browsers do not expose a device type; retain common pixel-mode notches.
		const magnitude = Math.abs(event.deltaY);
		return magnitude >= 100 && (magnitude % 100 === 0 || magnitude % 120 === 0);
	}

	window.AoeWebGestures = {
		install(callback) {
			const canvas = document.getElementById('canvas');
			const onWheel = (event) => {
				if (!event.ctrlKey && isDiscreteWheel(event)) return;
				if (event.deltaX === 0 && event.deltaY === 0) return;
				const rect = canvas.getBoundingClientRect();
				if (rect.width === 0 || rect.height === 0) return;
				const scaleX = canvas.width / rect.width;
				const scaleY = canvas.height / rect.height;
				const x = (event.clientX - rect.left) * scaleX;
				const y = (event.clientY - rect.top) * scaleY;
				event.preventDefault();
				event.stopImmediatePropagation();
				if (event.ctrlKey) {
					callback('magnify', Math.exp(-event.deltaY * 0.01), 0, x, y);
				} else {
					callback('pan', event.deltaX * scaleX, event.deltaY * scaleY, x, y);
				}
			};
			canvas.addEventListener('wheel', onWheel, { capture: true, passive: false });
			return { dispose() { canvas.removeEventListener('wheel', onWheel, true); } };
		},
	};
}());
