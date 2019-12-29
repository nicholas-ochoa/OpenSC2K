import tile from './tile';
import * as CONST from '../../constants';

export default class water extends tile {
  constructor (options) {
    options.type = CONST.T_WATER;
    options.layerDepth = CONST.DEPTH_WATER;
    super(options);
  }

  check () {
    if (!super.check()) return false;

    if (![270,271,272,273,274,275,276,277,278,279,280,281,282,283,284,285,286,287,288,289,290].includes(this.id)) return false;

    if (this.cell.water.type == CONST.TERRAIN_DRY) return false;

    return true;
  }

  position () {
    this.x = this.cell.position.topLeft.x;
    this.y = this.cell.position.topLeft.y - this.cell.position.seaLevel;
  }

  create () {
    if (this.cell.water.type == CONST.TERRAIN_WATERFALL)
      this.depthAdjustment++;

    super.create();
  }
}