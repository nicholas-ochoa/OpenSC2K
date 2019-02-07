import calculatePathBetweenCells from '../../utils/calculatePathBetweenCells';
import * as CONST from '../../constants';

export default class roads {
  scene;
  direction;
  active = false;
  start  = { x: 0, y: 0 };
  end    = { x: 0, y: 0 };
  cells  = [];

  tile = {
    'ns': 29,
    'ew': 30,
  };


  constructor (options) {
    this.scene = options.scene;
  }

  // y = 0   north
  // y = 127 south
  // x = 0   west
  // x = 127 east

  calculateDirection () {
    let sx = this.start.x;
    let sy = this.start.y;

    let ex = this.end.x;
    let ey = this.end.y;
    
    if (sx == ex && sy != ey) this.direction = 'ns';

    if (sx != ex && sy == ey) this.direction = 'ew';
  }


  onPointerDown (pointer, gameObject) {
    this.active = true;
    this.cells = [];

    if (gameObject[0])
      this.start = { x: gameObject[0].cell.x, y: gameObject[0].cell.y };
  }


  onPointerUp () {
    this.active = false;

    this.cells.forEach((cell) => {
      cell.clearHighlight();
    });

    this.calculateDirection();

    if (this.cells.length > 0)
      this.cells.forEach((cell) => {
        cell.tiles.set(CONST.T_ROAD, this.tile[this.direction]);
        cell.tiles[CONST.T_ROAD].create();
      });
  }


  onPointerMove () {
    return;
  }


  onPointerOver (pointer, gameObject) {
    if (!this.active) return;

    if (gameObject[0])
      this.end = { x: gameObject[0].cell.x, y: gameObject[0].cell.y };

    let list = calculatePathBetweenCells(this.start, this.end);
    
    for (let i = 0; i < list.length; i++)
      this.cells.push(this.scene.city.map.cells?.[list[i].x]?.[list[i].y]);

    this.cells.forEach((cell) => {
      cell.highlight();
    });
  }


  onPointerOut () {
    if (!this.active) return;

    this.cells.forEach((cell) => {
      cell.clearHighlight();
    });

    this.cells = [];
    return;
  }
}