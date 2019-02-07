export default class query {
  constructor (options) {
    this.scene = options.scene;
    this.globals = options.scene.globals;
  }

  onPointerUp (pointer) {
    //console.log('query onPointerUp', pointer);
  }

  onPointerDown (pointer, gameObject) {
    if (gameObject[0])
      console.log(gameObject[0].cell);

    //if (gameObject[0])
    //  console.log(gameObject[0].cell.depth, gameObject[0].cell.tiles.terrain.sprite.depth, gameObject[0].cell.tiles.terrain.depth, gameObject[0].cell);
  }

  onPointerMove (pointer, localX, localY) {
    //console.log('query onPointerMove', pointer, localX, localY);
  }

  onPointerOver (pointer, localX, localY) {
    //console.log('query onPointerOver', pointer, localX, localY);
  }

  onPointerOut (pointer) {
    //console.log('query onPointerOut', pointer);
  }
}