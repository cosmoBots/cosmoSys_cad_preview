import test from 'node:test';
import assert from 'node:assert/strict';
import {ModelControls} from '../assets/javascripts/model_controls.js';

test('only the six explicit Euler orders are accepted', () => {
  for (const order of ['XYZ', 'YXZ', 'ZXY', 'ZYX', 'YZX', 'XZY']) {
    assert.doesNotThrow(() => ModelControls.prototype.validateRotationOrder(order));
  }
  assert.throws(() => ModelControls.prototype.validateRotationOrder('invalid'));
});

test('2D scenes and models without node bindings are rejected', () => {
  assert.throws(() => new ModelControls({getRenderContext: () => ({scene: null})}, {}), /3D scene/);
  assert.throws(() => new ModelControls({getRenderContext: () => ({scene: {traverse() {}}})}, {}), /node bindings/);
});

test('invalid motion is rejected before changing the rest pose', () => {
  const controls = [{key: 'axis', node: 0, min: -90, max: 90}];
  for (const value of [NaN, Infinity, 91, -91]) {
    assert.throws(() => ModelControls.prototype.setValues.call({controls}, {axis: value}), /Invalid control value/);
  }
});
