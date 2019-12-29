import tile from './tile';
import * as CONST from '../../constants';

export default class zone extends tile {
  constructor (options) {
    options.type = CONST.T_ZONE;
    options.layerDepth = CONST.DEPTH_ZONE;
    super(options);
  }

  check () {
    if (!super.check()) return false;

    return true;
  }

  create () {
    super.create();
    
    if (this.cell.tiles.has(CONST.T_BUILDING)) this.sprite.setVisible(false);
  }
}