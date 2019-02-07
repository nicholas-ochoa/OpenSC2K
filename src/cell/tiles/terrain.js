import tile from './tile';
import * as CONST from '../../constants';

export default class terrain extends tile {
  constructor (options) {
    options.type = CONST.T_TERRAIN;
    options.layerDepth = CONST.DEPTH_TERRAIN;
    super(options);
  }


  check () {
    if (!super.check()) return false;

    if (![256,257,258,259,260,261,262,263,264,265,266,267,268,269].includes(this.id)) return false;

    return true;
  }


  show () {
    if (this.sprite?.visible) return;

    if (this.cell.water.type == CONST.TERRAIN_DRY || this.map.layers[this.type].showUnderwater)
      this.sprite.setVisible(true);
  }


  create () {
    //if (this.cell.tiles.hasBuilding() && !this.cell.building.tile.requiresTerrain)
    //  return false;

    super.create();

    if (this.sprite && this.cell.water.type != CONST.TERRAIN_DRY)
      this.sprite.setVisible(false);
  }
}