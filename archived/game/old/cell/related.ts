export default class related {
  #cell;
  #map;
  #tile;
  #key = false;
  #related = [];

  constructor (options) {
    this.#cell = options.cell;
    this.#map  = options.cell.scene.city.map;
    this.#tile = options.cell.tiles?.top?.tile;
    this.#key  = options.cell.position.corners.key;

    this.update();
    
    return this.#related;
  }


  update () {
    this.#related = [];

    if (!this.#key) return;

    let x = this.#cell.x;
    let y = this.#cell.y;

    // create a reference to self
    this.#related.push(this.#cell);

    if (this.#tile?.size == 2) {
      this.#related.push(this.#map.cells[x][y-1]);
      this.#related.push(this.#map.cells[x-1][y]);
      this.#related.push(this.#map.cells[x-1][y-1]);
    }

    if (this.#tile?.size == 3){
      this.#related.push(this.#map.cells[x][y-1]);
      this.#related.push(this.#map.cells[x-1][y]);
      this.#related.push(this.#map.cells[x-1][y-1]);
      this.#related.push(this.#map.cells[x][y-2]);
      this.#related.push(this.#map.cells[x-2][y]);
      this.#related.push(this.#map.cells[x-2][y-1]);
      this.#related.push(this.#map.cells[x-1][y-2]);
      this.#related.push(this.#map.cells[x-2][y-2]);
    }

    if (this.#tile?.size == 4){
      this.#related.push(this.#map.cells[x][y-1]);
      this.#related.push(this.#map.cells[x-1][y]);
      this.#related.push(this.#map.cells[x-1][y-1]);

      this.#related.push(this.#map.cells[x][y-2]);
      this.#related.push(this.#map.cells[x-2][y]);
      this.#related.push(this.#map.cells[x-2][y-1]);
      this.#related.push(this.#map.cells[x-1][y-2]);
      this.#related.push(this.#map.cells[x-2][y-2]);

      this.#related.push(this.#map.cells[x][y-3]);
      this.#related.push(this.#map.cells[x-3][y]);
      this.#related.push(this.#map.cells[x-3][y-1]);
      this.#related.push(this.#map.cells[x-3][y-2]);
      this.#related.push(this.#map.cells[x-1][y-3]);
      this.#related.push(this.#map.cells[x-2][y-3]);
      this.#related.push(this.#map.cells[x-3][y-3]);
    }

    this.#related.forEach((cell) => {
      cell.related = this.#related;
      cell.parent = this.#cell;
    });

    this.#cell.parent = null;
    this.#cell.related = this.#related;
  }
}