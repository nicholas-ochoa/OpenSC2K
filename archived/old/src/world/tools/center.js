export default class center {
  constructor (options) {
    this.scene = options.scene;
    this.globals = options.scene.globals;
  }

  onPointerUp (pointer) {
    //console.log('center onPointerUp', pointer);
  }

  onPointerDown (pointer, gameObject) {
    pointer.camera.pan(pointer.worldX, pointer.worldY, 150, 'Quart.easeInOut', false, () => {
      this.scene.viewport.cullObjects();
    });
  }

  onPointerMove (pointer, localX, localY) {
    //console.log('center onPointerMove', pointer, localX, localY);
  }

  onPointerOver (pointer, localX, localY) {
    //console.log('center onPointerOver', pointer, localX, localY);
  }

  onPointerOut (pointer) {
    //console.log('center onPointerOut', pointer);
  }
}