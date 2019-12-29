export default class corners {
  #cell;
  #key;
  #top    = false;
  #right  = false;
  #bottom = false;
  #left   = false;
  #none   = false;

  constructor (options) {
    this.#cell   = options.cell;
    this.#key    = options.cell.scene.city.corner;
    this.#top    = options.corners.top    || false;
    this.#right  = options.corners.right  || false;
    this.#bottom = options.corners.bottom || false;
    this.#left   = options.corners.left   || false;
    this.#none   = options.corners.none   || false;
  }

  get key () {
    return this[this.#key];
  }

  get top () {
    return this.#top;
  }

  set top (top) {
    this.#top = top;
  }

  get right () {
    return this.#right;
  }

  set right (right) {
    this.#right = right;
  }

  get bottom () {
    return this.#bottom;
  }

  set bottom (bottom) {
    this.#bottom = bottom;
  }

  get left () {
    return this.#left;
  }

  set left (left) {
    this.#left = left;
  }

  get none () {
    return this.#none;
  }

  set none (none) {
    this.#none = none;
  }
}