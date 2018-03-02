import tile from './tiles';

class power extends tile {
  constructor (options) {
    super(options);

    this.type = 'power';
    this.depth = 5;
  }

  checkTile () {
    if (!super.checkTile())
      return false;

    if (![14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,92].includes(this.tileId))
      return false;

    return true;
  }

  getTile () {
    super.getTile();

    this.tileId = this.common.tiles[this.tileId].rotate[this.scene.city.cityRotation];

    if (!this.common.tiles[this.tileId])
      return false;

    this.tile = this.common.tiles[this.tileId];

    if (this.flip())
      this.flipTile = true;

    if (this.flipTile && this.tile.flipMode == 'alternateTile') {
      this.tileId = this.common.tiles[this.tileId].rotate[this.scene.city.cityRotation];

      if (!this.common.tiles[this.tileId])
          return false;

      this.tile = this.common.tiles[this.tileId];
    }

    return true;
  }

  create () {
    if (!this.draw)
      return;

    if (this.cell.z < this.scene.city.waterLevel)
      this.offset = (0 - (this.scene.city.waterLevel - this.cell.z) * this.common.layerOffset);

    if (this.cell.terrain.tileId == 269)
      this.offset += this.common.layerOffset;

    super.create();

    if (this.flip())
      this.sprite.setFlipX(true);
  }
}

export default power;