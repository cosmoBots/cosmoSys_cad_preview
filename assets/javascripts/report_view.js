// Persistence belongs to the integration, not to the generic CAD viewer.
async function initialize(element, viewer) {
  const tools = document.getElementById('cad-report-tools');
  if (!tools || tools.dataset.initialized || !viewer.exportView) return;
  tools.dataset.initialized = 'true';
  element.prepend(tools);
  const labels = JSON.parse(tools.dataset.labels);
  const status = document.createElement('span');
  status.setAttribute('role', 'status');
  const restore = document.createElement('button');
  restore.type = 'button';
  restore.textContent = labels.restore;
  restore.disabled = true;
  const projection = document.createElement('select');
  projection.setAttribute('aria-label', labels.projection);
  for (const value of ['perspective', 'orthographic']) {
    projection.add(new Option(labels[value], value));
  }
  projection.addEventListener('change', () => viewer.setProjection(projection.value));
  if (viewer.setProjection) tools.append(projection, ' ');
  tools.append(restore, ' ', status);
  let record;

  function feedback(message, kind) {
    status.textContent = message;
    tools.dataset.feedback = kind;
  }

  function apply() {
    if (!record?.state) return;
    const container = element.querySelector('.cad-preview-canvas');
    container.style.blockSize = 'auto';
    container.style.minBlockSize = '0';
    container.style.aspectRatio = String(record.state.aspect);
    viewer.measurement?.clear();
    viewer.restoreView(record.state);
    projection.value = record.state.projection;
    const material = element.querySelector('[data-cad-material-mode]');
    const lighting = element.querySelector('[data-cad-lighting]');
    if (material) material.value = record.state.material;
    if (lighting) lighting.value = record.state.lighting;
  }
  restore.addEventListener('click', () => {
    try {
      apply();
      restore.textContent = `✓ ${labels.restoredShort}`;
      feedback(labels.restored, 'success');
    } catch {
      feedback(labels.error, 'error');
    }
  });

  const save = document.createElement('button');
  save.type = 'button';
  save.textContent = labels.save;
  save.disabled = true;
  if (tools.dataset.editable === 'true') tools.insertBefore(save, restore);
  save.addEventListener('click', async () => {
    save.disabled = true;
    restore.disabled = true;
    projection.disabled = true;
    save.textContent = labels.saving;
    tools.setAttribute('aria-busy', 'true');
    feedback(labels.saving, 'busy');
    try {
      const state = viewer.exportView();
      const image = viewer.captureImage();
      const response = await fetch(tools.dataset.url, {
        method: 'PUT', credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content },
        body: JSON.stringify({ state, cad_report_image: image, revision: record?.revision || null })
      });
      if (!response.ok) throw new Error(response.status === 409 ? labels.conflict : labels.error);
      record = await response.json();
      save.textContent = `✓ ${labels.savedShort}`;
      feedback(labels.saved, 'success');
    } catch (error) {
      save.textContent = labels.save;
      feedback(error.message === 'CAD_CAPTURE_EMPTY' ? labels.empty : (error.message || labels.error), 'error');
    } finally {
      save.disabled = false;
      restore.disabled = !record?.state;
      projection.disabled = false;
      tools.setAttribute('aria-busy', 'false');
    }
  });

  try {
    const response = await fetch(tools.dataset.url, { credentials: 'same-origin', cache: 'no-store' });
    if (!response.ok) throw new Error(labels.error);
    record = await response.json();
    restore.disabled = !record.state;
    status.textContent = record.state ? '' : labels.missing;
    apply();
    save.disabled = false;
    tools.dataset.ready = 'true';
  } catch (error) {
    feedback(labels.error, 'error');
  }
}

document.addEventListener('cad-preview:ready', (event) => initialize(event.target, event.detail.viewer));
document.querySelectorAll('[data-cad-preview]').forEach((element) => {
  if (element.cadViewer) initialize(element, element.cadViewer);
});
