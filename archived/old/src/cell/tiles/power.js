import tile from './tile';
import * as CONST from '../../constants';

export default class power extends tile {
  constructor (options) {
    options.type = CONST.T_POWER;
    options.layerDepth = CONST.DEPTH_POWER;
    super(options);
  }

  check () {
    if (!super.check()) return false;

    if (![14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,67,68,92].includes(this.id)) return false;

    return true;
  }

  get (id) {
    let tile = super.get(id);

    if (this.cell.position.rotate && tile?.flip)
      this.props.flip = true;

    if (this.props.flip && tile?.flipMode == CONST.ALTERNATE_TILE)
      tile = super.get(tile.rotate[this.rotation]);

    return tile;
  }

  create () {
    if (!this.props.draw || !this.check()) return;

    if (this.cell.position.underwater)
      this.props.offsetY -= this.cell.position.seaLevel;

    if (this.cell.tiles.has(CONST.T_TERRAIN) && this.cell.tiles.getId(CONST.T_TERRAIN) == 269)
      this.props.offsetY -= CONST.LAYER_OFFSET;

    super.create();

    if (this.props.flip)
      this.sprite.setFlipX(true);
  }
}