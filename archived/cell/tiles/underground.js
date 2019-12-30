import tile from './tile';
import * as CONST from '../../constants';

export default class underground extends tile {
  constructor (options) {
    options.type = CONST.T_UNDERGROUND;
    options.layerDepth = CONST.DEPTH_UNDERGROUND;
    super(options);
  }

  check () {
    if (!super.check()) return false;

    if (![305,306,307,308,309,310,311,312,313,314,315,316,317,318].includes(this.id)) return false;

    return true;
  }

  position () {
    this.x = this.cell.position.topLeft.x - (this.tile.width / 2) << 0;
    this.y = this.cell.position.topLeft.y - (this.tile.height) - this.offset << 0;
    this.depth = this.cell.depth || 0;
  }
  
  create () {
    super.create();

    if (this.sprite) this.sprite.setVisible(false); // hidden by default
  }
}