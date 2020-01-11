export interface Point2D {
  x: number;
  y: number;
}

export default class Point {
  #x: number;
  #y: number;

  constructor(point: Point2D) {
    this.#x = point.x;
    this.#y = point.y;
  }

  set(point: Point2D) {
    this.#x = point.x;
    this.#y = point.y;
  }

  get(): Point2D {
    return {
      x: this.#x,
      y: this.#y,
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
}
