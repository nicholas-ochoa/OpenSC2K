import Cell from 'Cell';
import Point from './Point';
import Location, { Point3D } from './Location';
import { TILE_WIDTH, TILE_HEIGHT, LAYER_OFFSET } from 'common/constants/tiles';
import Corners from './Corners';

export default class {
  #data;
  #cell: Cell;
  #location: Location;
  #depth: number = 0;
  #depthAdjustment: number = 0;
  #offset: Point3D;
  #seaLevel: number;

  public rotate: boolean = false;
  public corners: Corners;

  constructor(options) {
    this.#cell = options.cell;
    this.#data = options.data;

    this.#location = new Location({ x: options.data.x, y: options.data.y, z: options.data.segments.ALTM.altitude });
    //this.rotate = options.data.rotate;
    this.corners = new Corners({ ...this.#data.segments.XZON });

    this.update();
  }

  get depth(): number {
    return this.#location.x + this.#location.y * 64;
  }

  set depth(depth: number) {
    this.#depthAdjustment = depth;
  }

  get underwater(): boolean {
    if (this.z < this.#cell.city.waterLevel) {
      return true;
    } else {
      return false;
    }
  }

  update() {
    this.#offset = {
      x: (this.x - this.y) * (TILE_WIDTH / 2),
      y: (this.y + this.x) * (TILE_HEIGHT / 2),
      z: (LAYER_OFFSET * this.z) + LAYER_OFFSET,
    };
  }

  set location(location: Location) {
    this.#location = location;
  }

  get location(): Location {
    return this.#location;
  }

  set x(x: number) {
    this.#location.x = x;
    this.update();
  }

  get x(): number {
    return this.#location.x;
  }

  set y(y: number) {
    this.#location.y = y;
    this.update();
  }

  get y(): number {
    return this.#location.y;
  }

  set z(z: number) {
    this.#location.z = z;
    this.update();
  }

  get z(): number {
    return this.#location.z;
  }

  get top(): Point {
    return new Point({
      x: this.#offset.x + (TILE_WIDTH / 2),
      y: this.#offset.y - this.#offset.z - TILE_HEIGHT
    });
  }

  get topLeft(): Point {
    return new Point({
      x: this.#offset.x,
      y: this.#offset.y - this.#offset.z - TILE_HEIGHT
    });
  }

  get topRight(): Point {
    return new Point({
      x: this.#offset.x + TILE_WIDTH,
      y: this.#offset.y - this.#offset.z - TILE_HEIGHT
    });
  }

  get center(): Point {
    return new Point({
      x: this.#offset.x + (TILE_WIDTH / 2),
      y: (this.#offset.y - this.#offset.z) - (TILE_WIDTH / 2)
    });
  }

  get centerLeft(): Point {
    return new Point({
      x: this.#offset.x,
      y: (this.#offset.y - this.#offset.z) - (TILE_WIDTH / 2)
    });
  }

  get centerRight(): Point {
    return new Point({
      x: this.#offset.x + TILE_WIDTH,
      y: (this.#offset.y - this.#offset.z) - (TILE_WIDTH / 2)
    });
  }

  get bottom(): Point {
    return new Point({
      x: this.#offset.x + (TILE_WIDTH / 2),
      y: this.#offset.y - this.#offset.z
    });
  }

  get bottomLeft(): Point {
    return new Point({
      x: this.#offset.x,
      y: this.#offset.y - this.#offset.z
    });
  }

  get bottomRight(): Point {
    return new Point({
      x: this.#offset.x + TILE_WIDTH,
      y: this.#offset.y - this.#offset.z
    });
  }
}
