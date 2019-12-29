import tile from './tile';
import * as CONST from '../../constants';

export default class highway extends tile {
  onramp = false;

  constructor (options) {
    options.type = CONST.T_HIGHWAY;
    options.layerDepth = CONST.DEPTH_HIGHWAY;
    super(options);
  }


  check () {
    if (!super.check()) return false;

    if (![73,74,75,76,77,78,79,80,93,94,95,96,97,98,99,100,101,102,103,104,105,106,107].includes(this.id)) return false;

    return true;
  }


  get (id) {
    let tile = super.get(id);

    if (this.cell.position.rotate && tile?.flip)
      this.props.flip = true;

    if (this.props.flip && tile?.flipMode == CONST.ALTERNATE_TILE)
      tile = super.get(tile.rotate[this.rotation]);

    if (tile.highwayOnramp && tile.id < 400)
      this.onramp = true;

    return tile;
  }


  position () {
    this.x = this.cell.position.topLeft.x + this.props.offsetX;
    this.y = this.cell.position.topLeft.y - this.cell.position.seaLevel;

    if (this.tile.size == 2) {
      this.x -= (CONST.TILE_WIDTH / 2);
      this.depth.additional = -1;
    }
  }


  create () {
    if ((!this.cell.position.corners.key && ![93,94,95,96].includes(this.id)) || !this.props.draw) return;

    if (this.cell.position.underwater)
      this.props.offsetY -= this.cell.position.seaLevel;
    
    super.create();

    if (this.props.flip) this.sprite.setFlipX(true);
  }


  simulation () {
    let tile;
    let animationKey;

    if (!this.cell.microSims || !this.cell.microSims.simulators || !this.cell.microSims.simulators.highwayTraffic) return;

    let density = this.cell.microSims.simulators.highwayTraffic.getTrafficDensity();
    if (!density) return;
    
    let trafficTile = this.tile.traffic[density];
    if (!trafficTile) return;

    if (typeof trafficTile === 'number')
      tile = this.getTile(trafficTile);
    else
      tile = this.getTile(trafficTile[0]);

    if (!tile) return;

    // position at the bottom right x/y of the tile
    // when the size of the tiles differ
    let offsetX = this.tile.width - tile.width;
    let offsetY = this.tile.height - tile.height;
    
    // set traffic direction
    if (this.cell.microSims.simulators.highwayTraffic.calculateTrafficDirection())
      animationKey = tile.image;
    else
      animationKey = tile.image+'_R';

    this.highwayTraffic = this.scene.add.sprite(this.x + offsetX, this.y + offsetY, CONST.TILE_ATLAS).play(animationKey);
    this.highwayTraffic.cell = this.cell;
    this.highwayTraffic.setScale(CONST.SCALE);
    this.highwayTraffic.setOrigin(CONST.ORIGIN_X, CONST.ORIGIN_Y);
    this.highwayTraffic.setDepth(this.sprite.depth + 1);

    if (this.tile.traffic.flip) this.highwayTraffic.setFlipX(true);
    if (this.props.flip)        this.highwayTraffic.setFlipX(true);

    this.cell.addSprite(this.highwayTraffic, CONST.T_HIGHWAY_TRAFFIC);
    this.cell.microSims.simulators.highwayTraffic.addSprite(this.highwayTraffic);
  }
}