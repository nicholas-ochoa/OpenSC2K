import Phaser from 'phaser';
import location from './location';
import corners from './corners';
import * as CONST from '../constants';

export default class position {
  #depth = 0;
  #depthAdjustment = 0;
  #rotate = false;
  #location;
  #cell;
  #offset;
  #seaLevel;
  #corners;

  constructor (options) {
    this.#cell     = options.cell;
    this.#location = new location(options.data.x, options.data.y, options.data.z);
    this.#rotate   = options.data.rotate;
    this.#corners  = new corners({ cell: this.#cell, corners: options.data.corners });

    this.updateOffset();
  }

  get depth () {
    return (this.#location.x + this.#location.y) * 64;
  }

  set depth (depth) {
    this.#depthAdjustment = depth;
  }

  get rotate () {
    return this.#rotate;
  }

  set rotate (rotate) {
    this.#rotate = rotate;
  }

  get corners () {
    return this.#corners;
  }

  set corners (corners) {
    this.#corners = new corners(corners);
  }

  get underwater () {
    if (this.z < this.#cell.scene.city.waterLevel && [CONST.TERRAIN_SUBMERGED, CONST.TERRAIN_SHORE].includes(this.#cell.water.type))
      return true;
    else
      return false;
  }

  get seaLevel () {
    let offset = (this.#cell.scene.city.waterLevel - this.z) * CONST.LAYER_OFFSET;

    if (offset < 0)
      offset = 0;

    return offset;
  }

  get offset () {
    return this.#offset;
  }

  updateOffset () {
    this.#offset = new location(
      (this.x - this.y) * (CONST.TILE_WIDTH / 2),
      (this.y + this.x) * (CONST.TILE_HEIGHT / 2),
      (CONST.LAYER_OFFSET * this.z) + CONST.LAYER_OFFSET
    );
  }

  get location () {
    return this.#location;
  }

  set x (x) {
    this.#location.x = x;
    this.updateOffset();
  }

  set y (y) {
    this.#location.y = y;
    this.updateOffset();
  }

  set z (z) {
    this.#location.z = z;
    this.updateOffset();
  }

  get x ()  {
    return this.#location.x;
  }

  get y ()  {
    return this.#location.y;
  }

  get z ()  {
    return this.#location.z;
  }

  get top () {
    return new Phaser.Math.Vector2(
      this.#offset.x + (CONST.TILE_WIDTH / 2),
      this.#offset.y - this.#offset.z - CONST.TILE_HEIGHT
    );
  }

  get topLeft () {
    return new Phaser.Math.Vector2(
      this.#offset.x,
      this.#offset.y - this.#offset.z - CONST.TILE_HEIGHT
    );
  }

  get topRight () {
    return new Phaser.Math.Vector2(
      this.#offset.x + CONST.TILE_WIDTH,
      this.#offset.y - this.#offset.z - CONST.TILE_HEIGHT
    );
  }


  get center () {
    return new Phaser.Math.Vector2(
      this.#offset.x + (CONST.TILE_WIDTH / 2),
      (this.#offset.y - this.#offset.z) - (CONST.TILE_WIDTH / 2)
    );
  }

  get centerLeft () {
    return new Phaser.Math.Vector2(
      this.#offset.x,
      (this.#offset.y - this.#offset.z) - (CONST.TILE_WIDTH / 2)
    );
  }

  get centerRight () {
    return new Phaser.Math.Vector2(
      this.#offset.x + CONST.TILE_WIDTH,
      (this.#offset.y - this.#offset.z) - (CONST.TILE_WIDTH / 2)
    );
  }


  get bottom () {
    return new Phaser.Math.Vector2(
      this.#offset.x + (CONST.TILE_WIDTH / 2),
      this.#offset.y - this.#offset.z
    );
  }

  get bottomLeft () {
    return new Phaser.Math.Vector2(
      this.#offset.x,
      this.#offset.y - this.#offset.z
    );
  }

  get bottomRight () {
    return new Phaser.Math.Vector2(
      this.#offset.x + CONST.TILE_WIDTH,
      this.#offset.y - this.#offset.z
    );
  }

}