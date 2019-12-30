import cell from '../cell/cell';
import * as CONST from '../constants';
import * as layers from './layers/';

export default class map {
  #scene;

  grid = [];
  cells = [];
  list = [];
  selectedCell = { x: 0, y: 0 };
  sprites = { all: [] };
  layers = [];

  constructor (options) {
    this.#scene        = options.scene;
  }


  create () {
    for (let i = 0; i < this.#scene.importedData.cells.length; i++) {
      let c = new cell({
        scene: this.#scene,
        data: this.#scene.importedData.cells[i],
        index: i
      });

      if (!this.cells[c.x])      this.cells[c.x]      = [];
      if (!this.cells[c.x][c.y]) this.cells[c.x][c.y] = [];

      this.cells[c.x][c.y] = c;
      this.list.push(this.cells[c.x][c.y]);
    }

    // create map cells
    for (let x = 0; x < CONST.MAP_SIZE; x++)
      for (let y = 0; y < CONST.MAP_SIZE; y++)
        this.cells[x][y].create();

    // create layers
    this.layers.terrain   = new layers.terrain({ scene: this.#scene });
    this.layers.water     = new layers.water({ scene: this.#scene });
    this.layers.edge      = new layers.edge({ scene: this.#scene });
    this.layers.heightmap = new layers.heightmap({ scene: this.#scene });
    this.layers.zone      = new layers.zone({ scene: this.#scene });
    this.layers.building  = new layers.building({ scene: this.#scene });
    this.layers.road      = new layers.road({ scene: this.#scene });
    this.layers.rail      = new layers.rail({ scene: this.#scene });
    this.layers.power     = new layers.power({ scene: this.#scene });
    this.layers.highway   = new layers.highway({ scene: this.#scene });
    this.layers.subway    = new layers.subway({ scene: this.#scene });
    this.layers.pipe      = new layers.pipe({ scene: this.#scene });

    // do an initial object cull after rendering map
    this.#scene.viewport.cullObjects();
  }


  rotateCW () {
    let cells = this.cells;
    let tempCells = [];

    for (let x = 0; x < CONST.MAP_SIZE; x++) {
      for (let y = 0; y < CONST.MAP_SIZE; y++) {
        if (!tempCells[x])    tempCells[x]    = [];
        if (!tempCells[x][y]) tempCells[x][y] = [];

        let newX = y;
        let newY = CONST.MAP_SIZE - x - 1;

        tempCells[newX][newY] = cells[x][y];
      }
    }

    this.cells = tempCells;
  }


  rotateCCW () {
    let cells = this.cells;
    let tempCells = [];

    for (let x = 0; x < CONST.MAP_SIZE; x++) {
      for (let y = 0; y < CONST.MAP_SIZE; y++) {
        if (!tempCells[x])    tempCells[x]    = [];
        if (!tempCells[x][y]) tempCells[x][y] = [];

        let newX = CONST.MAP_SIZE - y - 1;
        let newY = x;

        tempCells[newX][newY] = cells[x][y];
      }
    }

    this.cells = tempCells;
  }


  update () {

  }


  shutdown () {
    if (this.list.length > 0)
      this.list.forEach((cell) => {
        cell.shutdown();
      });

    if (this.sprites.all.length > 0)
      this.sprites.all.forEach((sprite) => {
        sprite.destroy();
      });
  }


  addSprite (sprite, type) {
    if (!this.sprites[type])
      this.sprites[type] = [];

    this.sprites[type].push(sprite);
    this.sprites.all.push(sprite);
  }
}