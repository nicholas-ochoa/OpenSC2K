import tile from './tiles';

class building extends tile {
  constructor (options) {
    super(options);

    this.type = 'building';
    this.depth = this.depth - 0;
  }

  checkTile () {
    if (!super.checkTile())
      return false;

    if (![1,2,3,4,5,6,7,8,9,10,11,12,13,112,113,114,115,116,117,118,119,120,121,
          122,123,124,125,126,127,128,129,130,131,132,133,134,135,136,137,138,139,
          140,141,142,143,144,145,146,147,148,149,150,151,152,153,154,155,156,157,
          158,159,160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,
          176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191,192,193,
          194,195,196,197,198,199,200,201,202,203,204,205,206,207,208,209,210,211,
          212,213,214,215,216,217,218,219,220,221,222,223,224,225,226,227,228,229,
          230,231,232,233,234,235,236,237,238,239,240,241,242,243,244,245,246,247,
          248,249,250,251,252,253,254,255].includes(this.tileId))
      return false;

    if (!this.cell.properties.cornersBottomLeft)
      return false;

    return true;
  }

  create () {
    if (!this.draw)
      return;

    if (this.tile.size > 1)
      this.depth--;

    super.create();

    if (this.flipTile)
      this.sprite.setFlipX(true);
  }

  tileLogic () {
    if (!this.tile.logic)
      return;

    if (this.tile.logic.create)
      this[this.tile.logic.create]();
  }

  // rotate pier sections to match orientation with the crane onshore
  pier () {
    let cellX = 0;
    let cellY = 0;

    if (this.tileId == 224)
      this.cell.properties.special.pierCrane = true;

    // check tiles in each direction to determine pier orientation
    if (this.tileId == 223) {
      // north
      for (let x = 1; x < 5; x++) {
        cellX = this.cell.x + x;
        cellY = this.cell.y;

        if (this.map.cells[cellX][cellY].getBuildingTileId() == 224) {
          this.cell.properties.special.pierDirection = 'n';
          continue;
        }
      }

      // west
      for (let y = 1; y < 5; y++) {
        cellX = this.cell.x;
        cellY = this.cell.y + y;

        if (this.map.cells[cellX][cellY].getBuildingTileId() == 224) {
          this.cell.properties.special.pierDirection = 'w';
          continue;
        }
      }

      // south
      for (let x = -5; x < 0; x++) {
        cellX = this.cell.x + x;
        cellY = this.cell.y;

        if (this.map.cells[cellX][cellY].getBuildingTileId() == 224) {
          this.cell.properties.special.pierDirection = 's';
          continue;
        }
      }

      // east
      for (let y = -5; y < 0; y++) {
        cellX = this.cell.x;
        cellY = this.cell.y + y;

        if (this.map.cells[cellX][cellY].getBuildingTileId() == 224) {
          this.cell.properties.special.pierDirection = 'e';
          continue;
        }
      }
    }


    // rotate tile
    if ((this.cell.properties.special.pierDirection == 'e' || this.cell.properties.special.pierDirection == 'w') && [1,3].includes(this.city.cityRotation))
      this.flipTile = true;

    if ((this.cell.properties.special.pierDirection == 'n' || this.cell.properties.special.pierDirection == 's') && [0,2].includes(this.city.cityRotation))
      this.flipTile = true;

  }
}

export default building;