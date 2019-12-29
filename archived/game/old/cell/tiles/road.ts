import tile from './tile';
import * as CONST from '../../constants';

export default class road extends tile {
  constructor (options) {
    options.type = CONST.T_ROAD;
    options.layerDepth = CONST.DEPTH_ROAD;
    super(options);
    this.traffic = null;
  }

  check () {
    if (!super.check()) return false;

    if (![29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,63,64,65,66,69,70,81,82,83,84,85,86,87,88,89].includes(this.id)) return false;

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

    if (this.tile.depthAdjustment)
      this.depth.additional = this.tile.depthAdjustment;

    super.create();

    if (this.props.flip)
      this.sprite.setFlipX(true);
  }

  simulation () {
    if (!this.cell.microSims || !this.cell.microSims.simulators || !this.cell.microSims.simulators.traffic)
      return;

    let density = this.cell.microSims.simulators.traffic.getTrafficDensity();

    if (!density)
      return;

    let tile = this.get(this.tile.traffic[density]);

    // position at the bottom right x/y of the tile
    // when the size of the tiles differ
    let offsetX = this.tile.width - tile.width;
    let offsetY = this.tile.height - tile.height;

    this.traffic = this.scene.add.sprite(this.x + offsetX, this.y + offsetY, CONST.TILE_ATLAS).play(tile.image);
    this.traffic.cell = this.cell;
    this.traffic.setScale(CONST.SCALE);
    this.traffic.setOrigin(CONST.ORIGIN_X, CONST.ORIGIN_Y);
    this.traffic.setDepth(this.cell.depth + this.depth + 1);

    if (this.props.flip) this.traffic.setFlipX(true);

    this.cell.addSprite(this.traffic, CONST.T_ROAD_TRAFFIC);
    this.cell.microSims.simulators.traffic.addSprite(this.traffic);
  }
}