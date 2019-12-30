import Phaser from 'phaser';
import * as CONST from '../../constants';

export default class tile {
  #debug = {};

  id;
  cell;
  map;
  tile;
  depth;
  rotation;
  sprite;
  type;
  x;
  y;

  props = {
    draw: false,
    flip: false,
    offsetX: 0,
    offsetY: 0,
    hitbox: null
  };


  constructor (options) {
    this.cell      = options.cell;
    this.map       = options.cell.scene.city.map;
    this.rotation  = options.cell.scene.city.rotation;
    this.id        = options.id;
    this.type      = options.type;
    this.tile      = this.get(options.id);
    this.x         = options.x || 0;
    this.y         = options.y || 0;
    this.depth     = {
      cell:       options.cell.depth,
      layer:      options.layerDepth || 0,
      tile:       options.tileDepth || 0,
      additional: options.additionalDepth || 0,
    };

    if (!this.check()) return;

    this.props.draw = true;
  }


  get (id) {
    id = this.cell?.scene?.tiles?.[id]?.rotate[this.rotation];

    if (!id) return false;

    return this.cell.scene.tiles[id];
  }


  check () {
    if (!this.cell) return false;
    if (!this.tile) return false;

    return true;
  }


  hide () {
    if (this.sprite) this.sprite.setVisible(false);
  }


  show () {
    if (this.sprite) this.sprite.setVisible(true);
  }


  refresh () {
    this.hide();
    this.show();
  }


  position () {
    this.x = this.cell.position.topLeft.x + this.props.offsetX;
    this.y = this.cell.position.topLeft.y + this.props.offsetY;
  }


  create () {
    if (!this.props.draw) return;

    this.logic();
    this.position();

    if (this.tile.baseLayer) {
      let tile = this.get(this.tile.baseLayer);
      this.cell.tiles.set(this.tile.subtype, tile.id);
      this.cell.tiles[this.tile.subtype].depthAdjustment = -2;
      this.cell.tiles[this.tile.subtype].create();
    }

    if (this.tile.frames > 1)
      this.sprite = this.cell.scene.add.sprite(this.x, this.y, CONST.TILE_ATLAS).play(this.tile.image);
    else
      this.sprite = this.cell.scene.add.sprite(this.x, this.y, CONST.TILE_ATLAS, this.tile.textures[0]);

    this.sprite.cell = this.cell;
    this.sprite.type = this.type;
    this.sprite.setScale(CONST.SCALE);
    this.sprite.setOrigin(CONST.ORIGIN_X, CONST.ORIGIN_Y);
    this.sprite.setDepth(this.depth.cell + this.depth.layer + this.depth.tile + this.depth.additional);

    this.cell.tiles.addSprite(this.sprite, this.type);
    this.cell.tiles.addTile(this);

    this.events();
    //this.debugBox();
    //this.debugHitbox();
  }

  events () {
    if (!this.sprite) return;

    this.props.hitbox = this.tile.hitbox;

    this.sprite.setInteractive(this.props.hitbox, Phaser.Geom.Polygon.Contains);
    this.sprite.on(CONST.E_POINTER_OVER, this.cell.onPointerOver, this.cell);
    this.sprite.on(CONST.E_POINTER_OUT,  this.cell.onPointerOut,  this.cell);
    this.sprite.on(CONST.E_POINTER_MOVE, this.cell.onPointerMove, this.cell);
    this.sprite.on(CONST.E_POINTER_DOWN, this.cell.onPointerDown, this.cell);
    this.sprite.on(CONST.E_POINTER_UP,   this.cell.onPointerUp,   this.cell);
  }

  logic () {
    return;
  }

  simulation () {
    return;
  }

  debugBox () {
    let bounds = this.sprite.getBounds();
    let center = this.sprite.getCenter();

    this.#debug.box = this.cell.scene.add.rectangle(bounds.x, bounds.y, bounds.width, bounds.height, 0x00ffff, 0);
    this.#debug.box.setOrigin(CONST.ORIGIN_X, CONST.ORIGIN_Y);
    this.#debug.box.setDepth(this.depth + 2);
    this.#debug.box.setStrokeStyle(1, 0x00ffff, 0.5);

    this.#debug.center = this.cell.scene.add.circle(center.x, center.y, 1, 0x00ffff, 0.75);
    this.#debug.center.setOrigin(CONST.ORIGIN_X, CONST.ORIGIN_Y);
    this.#debug.center.setDepth(this.sprite.depth + 2);
  }

  debugHitbox () {
    this.#debug.hitbox = this.cell.scene.add.polygon(this.x, this.y, this.props.hitbox.points, 0xff00ff, 0);
    this.#debug.hitbox.setDepth(this.sprite.depth + 16);
    this.#debug.hitbox.setScale(CONST.SCALE);
    this.#debug.hitbox.setOrigin(CONST.ORIGIN_X, CONST.ORIGIN_Y);
    this.#debug.hitbox.setStrokeStyle(1, 0xff00ff, 0.5);
  }
}