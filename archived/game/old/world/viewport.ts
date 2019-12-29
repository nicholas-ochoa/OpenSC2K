// import Phaser from 'phaser';
// import * as CONST from '../constants';

// export default class viewport {
//   scene: any;
//   camera: any;
//   objectsRendered: any;
//   viewportPaddingMultiplier: any;
//   worldPoint: any;

//   constructor(options: any) {
//     this.scene = options.scene;
//     this.camera = this.scene.cameras.main;
//     this.camera.name = CONST.CAMERA_NAME;
//     this.worldView = this.camera.worldView;

//     this.objectsRendered = 0;

//     this.viewportPaddingMultiplier = 1.5;

//     this.worldPoint = {
//       x: 0,
//       y: 0,
//     };

//     const keys = this.scene.input.keyboard.addKeys({
//       'up': Phaser.Input.Keyboard.KeyCodes.W,
//       'down': Phaser.Input.Keyboard.KeyCodes.S,
//       'left': Phaser.Input.Keyboard.KeyCodes.A,
//       'right': Phaser.Input.Keyboard.KeyCodes.D,
//       'zoomIn': Phaser.Input.Keyboard.KeyCodes.Q,
//       'zoomOut': Phaser.Input.Keyboard.KeyCodes.E,
//     });

//     const controlConfig = {
//       camera: this.camera,
//       up: keys.up,
//       down: keys.down,
//       left: keys.left,
//       right: keys.right,
//       zoomIn: keys.zoomIn,
//       zoomOut: keys.zoomOut,
//       acceleration: 0.04,
//       drag: 0.0005,
//       maxSpeed: 1
//     };

//     this.controls = new Phaser.Cameras.Controls.SmoothedKeyControl(controlConfig);

//     this.camera.scrollX = -1531;
//     this.camera.scrollY = 140;
//     this.camera.zoom = 1;
//   }

//   onPointerMove (pointer: any) {
//     const { x, y } = this.camera.getWorldPoint(pointer.x, pointer.y);

//     this.worldPoint.x = x;
//     this.worldPoint.y = y;
//   }

//   update (delta: number) {
//     this.controls.update(delta);

//     if (this.controls._speedX !== 0 || this.controls._speedY !== 0 || this.controls._zoom !== 0)
//       this.cullObjects();
//   }

//   cullObjects () {
//     const cells = this.scene.city.map.cells;
//     const view  = Phaser.Geom.Rectangle.Clone(this.worldView);
//     const cx = view.centerX;
//     const cy = view.centerY;

//     Phaser.Geom.Rectangle.Scale(view, this.viewportPaddingMultiplier);
//     Phaser.Geom.Rectangle.CenterOn(view, cx, cy);

//     for (const x = 0; x < CONST.MAP_SIZE; x++)
//       for (const y = 0; y < CONST.MAP_SIZE; y++)
//         if (Phaser.Geom.Rectangle.Contains(view, cells[x][y].position.center.x, cells[x][y].position.center.y))
//           cells[x][y].show();
//         else
//           cells[x][y].hide();


//     this.objectsRendered = 0;

//     this.scene.children.list.forEach((gameObject) => {
//       if (gameObject.visible) this.objectsRendered++;
//     });
//   }
// }
