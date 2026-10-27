// cosmoBots integration code: editorial capture policy is not part of the viewer.
// Alpha bounds, not color-key removal: white surfaces remain opaque.
export function alphaBounds(pixels, width, height) {
  let left = width, top = height, right = -1, bottom = -1;
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      if (!pixels[(y * width + x) * 4 + 3]) continue;
      left = Math.min(left, x); top = Math.min(top, y);
      right = Math.max(right, x); bottom = Math.max(bottom, y);
    }
  }
  return right < left ? null : { x: left, y: top, width: right - left + 1, height: bottom - top + 1 };
}

export function captureCroppedPng(source) {
  const copy = document.createElement('canvas');
  copy.width = source.width;
  copy.height = source.height;
  const context = copy.getContext('2d', { willReadFrequently: true });
  context.drawImage(source, 0, 0);
  const bounds = alphaBounds(context.getImageData(0, 0, copy.width, copy.height).data, copy.width, copy.height);
  if (!bounds) throw new Error('CAD_CAPTURE_EMPTY');
  const scale = Math.min(1, 1600 / Math.max(bounds.width, bounds.height));
  const output = document.createElement('canvas');
  output.width = Math.max(1, Math.round(bounds.width * scale));
  output.height = Math.max(1, Math.round(bounds.height * scale));
  output.getContext('2d').drawImage(copy, bounds.x, bounds.y, bounds.width, bounds.height,
                                 0, 0, output.width, output.height);
  return output.toDataURL('image/png');
}

export function captureReportImage(viewer) {
  const { canvas, renderer, scene, render } = viewer.getRenderContext();
  const background = scene?.background;
  const alpha = renderer.getClearAlpha();
  try {
    if (scene) scene.background = null;
    renderer.setClearAlpha(0);
    render();
    return captureCroppedPng(canvas);
  } finally {
    if (scene) scene.background = background;
    renderer.setClearAlpha(alpha);
    render();
  }
}
