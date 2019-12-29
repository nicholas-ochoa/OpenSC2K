import tiles from './tiles';
import * as CONST from '../constants';
import position from './position';
import surrounding from './surrounding';
import related from './related';

export default class cell {
  #data;
  #debug = {};

  surrounding;
  city;
  scene;
  position;
  water;
  tiles;
  related;
  parent;
  index;

  constructor (options) {
    this.#data       = options.data;
    this.scene       = options.scene;
    this.city        = options.scene.city;
    this.water       = options.data.water;
    this.index       = options.index;
    this.position    = new position({ cell: this, data: this.#data });
    this.tiles       = new tiles({ cell: this, list: options.data.tiles._list });
    this.surrounding = new surrounding({ cell: this });
    
    return this;
  }


  create () {
    this.tiles.create();
    this.related = new related({ cell: this });
  }


  onPointerUp () {

  }


  onPointerDown () {
    console.log(this);
  }


  onPointerMove () {
    this.scene.city.map.selectedCell.x = this.x;
    this.scene.city.map.selectedCell.y = this.y;
  }


  onPointerOver () {
    this.scene.city.map.selectedCell.x = this.x;
    this.scene.city.map.selectedCell.y = this.y;

    this.tiles.sprites.forEach((sprite) => {
      if (sprite.visible) sprite.setTint(0xaa0000);
    });

    this.related.forEach((cell) => {
      cell.tiles.sprites.forEach((sprite) => {
        if (sprite.visible) sprite.setTint(0xaa0000);
      });
    });

    if (this.tiles.heightmap) {
      if (this.tiles.heightmap.polygon.top){
        this.tiles.heightmap.polygon.top.fillAlpha = 0.5;
      }
      if (this.tiles.heightmap.polygon.slope){
        this.tiles.heightmap.polygon.slope.fillAlpha = 0.5;
      }
    }
  }


  onPointerOut () {
    this.tiles.sprites.forEach((sprite) => {
      if (sprite.visible) sprite.clearTint();
    });

    this.related.forEach((cell) => {
      cell.tiles.sprites.forEach((sprite) => {
        if (sprite.visible) sprite.clearTint();
      });
    });

    if (this.tiles.heightmap) {
      if (this.tiles.heightmap.polygon.top){
        this.tiles.heightmap.polygon.top.fillAlpha = 1;
      }
      if (this.tiles.heightmap.polygon.slope){
        this.tiles.heightmap.polygon.slope.fillAlpha = 1;
      }
    }
  }


  highlight (color = 0x00aa00) {
    this.tiles.sprites.forEach((sprite) => {
      if (sprite.visible) sprite.setTint(color);
    });
  }


  clearHighlight () {
    this.tiles.sprites.forEach((sprite) => {
      if (sprite.visible) sprite.clearTint();
    });
  }


  get depth () {
    return this.position.depth;
  }


  set depth (depth) {
    this.position.depth = depth;
  }


  get x () {
    return this.position.x;
  }


  set x (x) {
    this.position.x = x;
  }


  get y () {
    return this.position.y;
  }


  set y (y) {
    this.position.y = y;
  }


  get z () {
    return this.position.z;
  }


  set z (z) {
    this.position.z = z;
  }


  hide () {
    this.tiles.hide();
  }


  show () {
    this.tiles.show();
  }


  //
  // draw a 1px box bounding box around the calculated cell position
  //
  debugBox () {
    let bounds = {
      x: this.position.topLeft.x,
      y: this.position.topLeft.y,
      w: this.position.right.x - this.position.left.x,
      h: this.position.top.y - this.position.bottom.y,
    };

    this.#debug.box = this.scene.add.rectangle(bounds.x, bounds.y, bounds.w, bounds.h, 0x00ff00, 0.10);
    this.#debug.box.setOrigin(CONST.ORIGIN_X, CONST.ORIGIN_Y);
    this.#debug.box.setDepth(this.depth + 1024);
    this.#debug.box.setStrokeStyle(1, 0x00ff00, 0.60);

    //this.debugPoint();
  }


  debugPoint () {
    //top left
    this.#debug.topLeft = this.scene.add.circle(this.position.topLeft.x, this.position.topLeft.y, 3, 0xffffff, 1);
    this.#debug.topLeft.setOrigin(CONST.ORIGIN_X, CONST.ORIGIN_Y);
    this.#debug.topLeft.setDepth(this.depth + 1024);

    // top middle
    this.#debug.topMiddle = this.scene.add.circle(this.position.center.x, this.position.top.y, 3, 0xffff00, 1);
    this.#debug.topMiddle.setOrigin(CONST.ORIGIN_X, CONST.ORIGIN_Y);
    this.#debug.topMiddle.setDepth(this.depth + 1024);

    // top right
    this.#debug.topRight = this.scene.add.circle(this.position.topRight.x, this.position.topRight.y, 3, 0xff00ff, 1);
    this.#debug.topRight.setOrigin(CONST.ORIGIN_X, CONST.ORIGIN_Y);
    this.#debug.topRight.setDepth(this.depth + 1024);


    // center left
    this.#debug.centerLeft = this.scene.add.circle(this.position.left.x, this.position.center.y, 3, 0x00ffff, 1);
    this.#debug.centerLeft.setOrigin(CONST.ORIGIN_X, CONST.ORIGIN_Y);
    this.#debug.centerLeft.setDepth(this.depth + 1024);

    // center middle
    this.#debug.centerMiddle = this.scene.add.circle(this.position.center.x, this.position.center.y, 3, 0x0000ff, 1);
    this.#debug.centerMiddle.setOrigin(CONST.ORIGIN_X, CONST.ORIGIN_Y);
    this.#debug.centerMiddle.setDepth(this.depth + 1024);

    // center right
    this.#debug.centerRight = this.scene.add.circle(this.position.right.x, this.position.center.y, 3, 0x00ff00, 1);
    this.#debug.centerRight.setOrigin(CONST.ORIGIN_X, CONST.ORIGIN_Y);
    this.#debug.centerRight.setDepth(this.depth + 1024);


    // bottom left
    this.#debug.bottomLeft = this.scene.add.circle(this.position.bottomLeft.x, this.position.bottomLeft.y, 3, 0xff0000, 1);
    this.#debug.bottomLeft.setOrigin(CONST.ORIGIN_X, CONST.ORIGIN_Y);
    this.#debug.bottomLeft.setDepth(this.depth + 1024);

    // bottom middle
    this.#debug.bottomMiddle = this.scene.add.circle(this.position.center.x, this.position.bottom.y, 3, 0x666666, 1);
    this.#debug.bottomMiddle.setOrigin(CONST.ORIGIN_X, CONST.ORIGIN_Y);
    this.#debug.bottomMiddle.setDepth(this.depth + 1024);

    // bottom right
    this.#debug.bottomRight = this.scene.add.circle(this.position.bottomRight.x, this.position.bottomRight.y, 3, 0x000000, 1);
    this.#debug.bottomRight.setOrigin(CONST.ORIGIN_X, CONST.ORIGIN_Y);
    this.#debug.bottomRight.setDepth(this.depth + 1024);
  }


  //
  // draw a text label with the cell location above all other objects
  //
  debugLabels () {
    this.#debug.label = this.scene.add.text(this.position.center.x, this.position.center.y, this.x+','+this.y+','+this.z, { fontFamily: 'Verdana', fontSize: 8, color: '#ffffff' });
    this.#debug.label.setDepth(this.depth + 128);
    this.#debug.label.setOrigin(0.5, 0.5);
  }
}