export interface Point3D {
  x: number;
  y: number;
  z: number;
}

export default class Location {
  #x: number;
  #y: number;
  #z: number;

  constructor(point: Point3D) {
    this.#x = point.x;
    this.#y = point.y;
    this.#z = point.z;
  }

  set(point: Point3D) {
    this.#x = point.x;
    this.#y = point.y;
    this.#z = point.z;
  }

  get(): Point3D {
    return {
      x: this.#x,
      y: this.#y,
      z: this.#z,
    };
  }

  set x(x: number) {
    this.#x = x;
  }

  get x(): number {
    return this.#x;
  }

  set y(y: number) {
    this.#y = y;
  }

  get y(): number {
    return this.#y;
  }

  set z(z: number) {
    this.#z = z;
  }

  get z(): number {
    return this.#z;
  }
}
