import actors from './actors';

export default class trains extends actors {
  constructor (options) {
    super(options);

    this.type = 'train';
    this.heading = undefined;
    this.cars = 3;
  }

  spawn (cell) {
    this.cell = cell;
    this.tile = this.getTile(374);

    this.x = this.cell.x;
    this.y = this.cell.y;
    this.z = this.cell.z;

    this.create();
  }
}