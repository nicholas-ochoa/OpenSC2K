export default class surrounding {
  #map;
  #x;
  #y;

  constructor (options) {
    this.#map  = options.cell.scene.city.map;
    this.#x    = options.cell.x;
    this.#y    = options.cell.y;
  }

  get n () {
    return this.#map.cells?.[this.#x]?.[this.#y - 1];
  }

  get s () {
    return this.#map.cells?.[this.#x]?.[this.#y + 1];
  }

  get e () {
    return this.#map.cells?.[this.#x + 1]?.[this.#y];
  }

  get w () {
    return this.#map.cells?.[this.#x - 1]?.[this.#y];
  }

  get c () {
    return this.#map.cells?.[this.#x]?.[this.#y];
  }

  get ne () {
    return this.#map.cells?.[this.#x + 1]?.[this.#y - 1];
  }

  get nw () {
    return this.#map.cells?.[this.#x - 1]?.[this.#y - 1];
  }

  get se () {
    return this.#map.cells?.[this.#x + 1]?.[this.#y + 1];
  }

  get sw () {
    return this.#map.cells?.[this.#x - 1]?.[this.#y + 1];
  }
}