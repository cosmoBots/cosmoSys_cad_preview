// Generic rigid-node controls. No architecture, database or MQTT knowledge.
// Convention: reset to rest, local XYZ offsets, then world XYZ offsets;
// parents before children. Values never accumulate between slider events.
export class ModelControls {
  constructor(viewer, configuration) {
    this.viewer = viewer;
    this.scene = viewer.getRenderContext().scene;
    if (!this.scene) throw new Error('A 3D scene is required');
    this.nodes = new Map();
    this.scene.traverse(object => {
      const index = object.userData?.cosmosys_cad_node_index;
      if (Number.isInteger(index)) {
        if (this.nodes.has(index)) throw new Error(`Duplicate CAD node ${index}`);
        this.nodes.set(index, object);
      }
    });
    if (!this.nodes.size) throw new Error('The model has no node bindings');
    this.configuration = configuration;
    this.controls = configuration.controls || [];
    this.controls.forEach(control => {
      if (!this.nodes.has(control.node)) throw new Error(`Missing controlled node ${control.node}`);
    });
    let root = this.nodes.values().next().value;
    while (root.parent && root.parent !== this.scene) root = root.parent;
    this.root = root;
    this.transform(root, configuration.transform || {});
    Object.entries(configuration.node_transforms || {}).forEach(([index, transform]) => {
      const node = this.nodes.get(Number(index));
      if (node) this.transform(node, transform);
    });
    this.rest = new Map([...this.nodes].map(([index, node]) => [index,
      {position: node.position.clone(), rotation: node.rotation.clone()}]));
    const visible = new Set(configuration.visible_nodes || [...this.nodes.keys()]);
    this.root.traverse(object => {
      if (!object.isMesh && !object.isLine && !object.isPoints) return;
      let owner = object;
      while (owner && !Number.isInteger(owner.userData?.cosmosys_cad_node_index)) owner = owner.parent;
      // Hiding a mesh must not hide visible child nodes of that same mesh.
      if (!owner || !visible.has(owner.userData.cosmosys_cad_node_index)) object.layers.disableAll();
    });
    this.setValues({});
  }

  transform(node, transform) {
    if (transform.translation) node.position.fromArray(transform.translation);
    if (transform.rotation_degrees) node.rotation.set(...transform.rotation_degrees.map(value => value * Math.PI / 180));
  }

  setValues(values) {
    const byNode = new Map();
    for (const control of this.controls) {
      const value = Number(values[control.key] ?? control.default ?? 0);
      if (!Number.isFinite(value) || value < control.min || value > control.max) throw new Error(`Invalid control value: ${control.key}`);
      const list = byNode.get(control.node) || [];
      list.push({...control, value});
      byNode.set(control.node, list);
    }
    for (const [index, node] of this.nodes) {
      node.position.copy(this.rest.get(index).position);
      node.rotation.copy(this.rest.get(index).rotation);
    }
    this.scene.updateMatrixWorld(true);
    for (const [index, node] of this.nodes) {
      const controls = byNode.get(index) || [];
      for (const control of controls.filter(value => value.space === 'local')) {
        if (control.motion === 'rotation') node.rotation[control.axis] += control.value * Math.PI / 180;
        else node.position[control.axis] += control.value;
      }
      this.scene.updateMatrixWorld(true);
      const world = controls.filter(value => value.space === 'global');
      if (world.length) {
        const position = node.getWorldPosition(node.position.clone());
        const rotation = node.rotation.clone().setFromQuaternion(node.getWorldQuaternion(node.quaternion.clone()));
        for (const control of world) {
          if (control.motion === 'rotation') rotation[control.axis] += control.value * Math.PI / 180;
          else position[control.axis] += control.value;
        }
        node.position.copy(node.parent ? node.parent.worldToLocal(position) : position);
        const quaternion = node.quaternion.clone().setFromEuler(rotation);
        if (node.parent) quaternion.premultiply(node.parent.getWorldQuaternion(node.quaternion.clone()).invert());
        node.quaternion.copy(quaternion);
        this.scene.updateMatrixWorld(true);
      }
    }
    this.viewer.render();
  }

  fitVisible() {
    let bounds;
    this.root.traverse(object => {
      if (!object.isMesh || !object.visible || !object.layers.test(this.viewer.camera.layers) || !object.geometry) return;
      object.geometry.computeBoundingBox();
      const box = object.geometry.boundingBox.clone().applyMatrix4(object.matrixWorld);
      bounds ? bounds.union(box) : bounds = box;
    });
    if (!bounds || bounds.isEmpty()) return;
    const center = bounds.getCenter(this.root.position.clone());
    const radius = Math.max(bounds.getSize(this.root.position.clone()).length() / 2, 0.001);
    const camera = this.viewer.camera;
    const distance = radius / Math.sin((camera.fov || 45) * Math.PI / 360) / Math.min(camera.aspect || 1, 1);
    const direction = camera.position.clone().sub(this.viewer.controls.target).normalize();
    camera.position.copy(center).addScaledVector(direction.lengthSq() ? direction : direction.set(1, 1, 1).normalize(), distance);
    camera.near = distance / 1000; camera.far = distance * 1000;
    camera.updateProjectionMatrix();
    this.viewer.controls.target.copy(center);
    this.viewer.controls.update();
    this.viewer.render();
  }
}
