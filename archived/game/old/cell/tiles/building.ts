import tile from './tile';
import * as CONST from '../../constants';

export default class building extends tile {
  constructor (options) {
    options.type = CONST.T_BUILDING;
    options.layerDepth = CONST.DEPTH_BUILDING;
    super(options);
  }


  check () {
    if (!super.check()) return false;

    if (![1,2,3,4,5,6,7,8,9,10,11,12,13,112,113,114,115,116,117,118,119,120,121,
      122,123,124,125,126,127,128,129,130,131,132,133,134,135,136,137,138,139,
      140,141,142,143,144,145,146,147,148,149,150,151,152,153,154,155,156,157,
      158,159,160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,
      176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191,192,193,
      194,195,196,197,198,199,200,201,202,203,204,205,206,207,208,209,210,211,
      212,213,214,215,216,217,218,219,220,221,222,223,224,225,226,227,228,229,
      230,231,232,233,234,235,236,237,238,239,240,241,242,243,244,245,246,247,
      248,249,250,251,252,253,254,255].includes(this.id))
      return false;

    return true;
  }


  get (id) {
    let tile = super.get(id);

    //if (!this.flip(tile)) this.props.flip = true;

    return tile;
  }


  position () {
    this.x = this.cell.position.center.x + this.props.offsetX;
    this.y = this.cell.position.top.y - this.cell.position.seaLevel;
  }


  create () {
    if (!this.cell.position.corners.key || !this.props.draw) return;

    if (this.tile.size == 2) this.depth.additional = 1;
    if (this.tile.size == 3) this.depth.additional = 32;
    if (this.tile.size == 4) this.depth.additional = 32;

    super.create();

    if (this.props.flip) this.sprite.setFlipX(true);

    this.sprite.setOrigin(0.5, 1);
  }


  logic () {
    if (!this.tile.logic) return;

    if (this.tile.logic.create) this[this.tile.logic.create]();
  }


  // rotate pier sections to match orientation with the crane onshore
  pier () {
    let cellX = 0;
    let cellY = 0;
    let pierDirection;
    //let pierCrane = false;
    this.props.flip = false;

    //if (this.id == 224) pierCrane = true;

    // check tiles in each direction to determine pier orientation
    if (this.id == 223) {
      // north
      for (let x = 1; x < 5; x++) {
        cellX = this.cell.x + x;
        cellY = this.cell.y;

        if (this.map.cells[cellX][cellY].tiles.getId(CONST.T_BUILDING) == 224) {
          pierDirection = CONST.D_NORTH;
          continue;
        }
      }

      // west
      for (let y = 1; y < 5; y++) {
        cellX = this.cell.x;
        cellY = this.cell.y + y;

        if (this.map.cells[cellX][cellY].tiles.getId(CONST.T_BUILDING) == 224) {
          pierDirection = CONST.D_WEST;
          continue;
        }
      }

      // south
      for (let x = -5; x < 0; x++) {
        cellX = this.cell.x + x;
        cellY = this.cell.y;

        if (this.map.cells[cellX][cellY].tiles.getId(CONST.T_BUILDING) == 224) {
          pierDirection = CONST.D_SOUTH;
          continue;
        }
      }

      // east
      for (let y = -5; y < 0; y++) {
        cellX = this.cell.x;
        cellY = this.cell.y + y;

        if (this.map.cells[cellX][cellY].tiles.getId(CONST.T_BUILDING) == 224) {
          pierDirection = CONST.D_EAST;
          continue;
        }
      }
    }


    // rotate tile
    if ((pierDirection == CONST.D_EAST || pierDirection == CONST.D_WEST) && [1,3].includes(this.city.cameraRotation))
      this.props.flip = true;

    if ((pierDirection == CONST.D_NORTH || pierDirection == CONST.D_SOUTH) && [0,2].includes(this.city.cameraRotation))
      this.props.flip = true;
  }
}