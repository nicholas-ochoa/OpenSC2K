import tile from './tiles';

class heightmap extends tile {
  constructor (options) {
    if (!options.tileId)
      options.tileId = options.cell.water.tileId;

    super(options);

    this.type = 'heightmap';
    this.depth = this.depth - 64;
  }

  getTile () {
    if (this.cell.getProperty('waterLevel') == 'surface' && this.tileId != 284)
      this.tileId = 256;

    if (this.tileId == 284)
      this.tileId = 269;

    return super.getTile();
  }

  checkTile () {
    if (!super.checkTile())
      return false;

    return true;
  }

  calculatePosition () {
    if (!this.cell && !this.tile) throw 'Cannot set position for cell '+this.x+', '+this.y+'; references to cell and tile are not defined';

    this.x = this.cell.position.bottom.x - (this.tile.width / 2) << 0;
    this.y = this.cell.position.bottom.y - (this.tile.height) - this.offset << 0;

    this.depth = this.cell.depth || 0;
  }

  create () {
    if (!this.draw)
      return;

    this.cell.addTile(this);
    this.calculatePosition();

    this.sprite = this.scene.add.sprite(this.x, this.y, this.common.tilemap, this.tile.textures[0].replace('_0', '_V_' + this.cell.z));

    this.sprite.cell = this.cell;
    this.sprite.setScale(this.common.scale);
    this.sprite.setOrigin(0, 0);
    this.sprite.setDepth(this.depth);
    
    this.cell.addSprite(this.sprite);
  }
}

export default heightmap;