// export default class center {
//   scene: any;
//   globals: any;

//   constructor (options: any) {
//     this.scene = options.scene;
//     this.globals = options.scene.globals;
//   }

//   onPointerUp (pointer: any) {
//     //console.log('center onPointerUp', pointer);
//   }

//   onPointerDown (pointer: any, gameObject: any) {
//     pointer.camera.pan(pointer.worldX, pointer.worldY, 150, 'Quart.easeInOut', false, () => {
//       this.scene.viewport.cullObjects();
//     });
//   }

//   onPointerMove (pointer: any, localX: any, localY: any) {
//     //console.log('center onPointerMove', pointer, localX, localY);
//   }

//   onPointerOver (pointer: any, localX: any, localY: any) {
//     //console.log('center onPointerOver', pointer, localX, localY);
//   }

//   onPointerOut (pointer: any) {
//     //console.log('center onPointerOut', pointer);
//   }
// }
