import tile from './tiles';

class highway extends tile {
  constructor (options) {
    super(options);

    this.type = 'highway';
    this.depth = +2;
  }

  checkTile () {
    if (!super.checkTile())
      return false;

    if (![73,74,75,76,77,78,79,80,93,94,95,96,97,98,99,100,101,102,103,104,105,106,107].includes(this.tileId))
      return false;

    return true;
  }

  getTile () {
    super.getTile();

    if (this.flip())
      this.flipTile = true;

    if (this.flipTile && this.tile.flipMode == 'alternateTile') {
      this.tileId = this.common.tiles[this.tileId].rotate[this.scene.city.cameraRotation];
      this.tile = this.common.tiles[this.tileId];
    }

    return true;
  }

  create () {
    if ((!this.checkKeyTile() && ![93,94,95,96].includes(this.tileId)) || !this.draw || !this.checkTile())
      return;

    if (this.tile.size == 2) this.depth--;
    
    if (this.cell.z < this.scene.city.waterLevel)
      this.offset = (0 - (this.scene.city.waterLevel - this.cell.z) * this.common.layerOffset);

    super.create();

    if (this.flipTile)
      this.sprite.setFlipX(true);
  }
}

export default highway;