import tile from './tiles';

class road extends tile {
  constructor (options) {
    super(options);

    this.type = 'road';
    this.depth = 4;
  }

  checkTile () {
    if (!super.checkTile())
      return false;

    if (![29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,63,64,65,66,67,68,69,70,81,82,83,84,85,86,87,88,89].includes(this.tileId))
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

    if (this.tile.tunnel)
      this.depth -= 10;

    super.create();

    if (this.flipTile)
      this.sprite.setFlipX(true);
  }
}

export default road;