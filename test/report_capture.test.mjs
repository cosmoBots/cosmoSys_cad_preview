import test from 'node:test';
import assert from 'node:assert/strict';
import { alphaBounds, captureReportImage } from '../assets/javascripts/report_capture.js';

test('crop ignores transparent RGB and retains opaque white surfaces', () => {
  const pixels = new Uint8ClampedArray(6 * 4 * 4).fill(255);
  for (let i = 3; i < pixels.length; i += 4) pixels[i] = 0;
  pixels[(1 * 6 + 2) * 4 + 3] = 255;
  pixels[(2 * 6 + 3) * 4 + 3] = 255;
  assert.deepEqual(alphaBounds(pixels, 6, 4), { x: 2, y: 1, width: 2, height: 2 });
});

test('crop includes faint antialiased edges', () => {
  const pixels = new Uint8ClampedArray(5 * 3 * 4);
  pixels[(0 * 5 + 1) * 4 + 3] = 1;
  pixels[(2 * 5 + 4) * 4 + 3] = 255;
  assert.deepEqual(alphaBounds(pixels, 5, 3), { x: 1, y: 0, width: 4, height: 3 });
});

test('empty captures are distinguished from an opaque canvas', () => {
  assert.equal(alphaBounds(new Uint8ClampedArray(2 * 2 * 4), 2, 2), null);
  assert.deepEqual(alphaBounds(new Uint8ClampedArray(2 * 2 * 4).fill(255), 2, 2),
    { x: 0, y: 0, width: 2, height: 2 });
});

for (const drawing of [false, true]) {
  test(`capture restores ${drawing ? 'drawing' : '3D'} appearance after an error`, () => {
    const background = {};
    const scene = drawing ? null : { background };
    let alpha = 1;
    let renders = 0;
    const surface = {
      canvas: {}, scene,
      renderer: { getClearAlpha: () => alpha, setClearAlpha: value => { alpha = value; } },
      render: () => { renders++; }
    };
    const originalDocument = globalThis.document;
    globalThis.document = { createElement: () => { throw new Error('capture failed'); } };
    try {
      assert.throws(() => captureReportImage({ getRenderContext: () => surface }), /capture failed/);
      assert.equal(alpha, 1);
      if (scene) assert.equal(scene.background, background);
      assert.equal(renders, 2);
    } finally {
      if (originalDocument === undefined) delete globalThis.document;
      else globalThis.document = originalDocument;
    }
  });
}
