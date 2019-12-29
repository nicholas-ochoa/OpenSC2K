export default class actor {
  constructor (options) {
    this.scene = options.scene;
    this.common = this.scene.sys.game.common;

    this.sprite = undefined;
    this.cell = undefined;

    this.depth = 10000;

    this.tick = 0; // current tick
    this.tickFrequency = 10; // how often to update

    this.x = 0;
    this.y = 0;
    this.z = 0;
  }

  spawn () {
    return;
  }

  update () {
    
  }

  sleep () {

  }

  wake () {

  }

  hide () {

  }

  show () {
    
  }

  destroy () {
    this.sprites = [];
  }

  calculatePosition () {
    this.offset = 0;
    this.x = this.cell.position.bottom.x - (this.tile.width / 2) << 0;
    this.y = this.cell.position.bottom.y - (this.tile.height) - this.offset << 0;
  }

  getTile (tileId) {
    if (!this.common.tiles[tileId])
      return false;

    tileId = this.common.tiles[tileId].rotate[this.scene.city.cameraRotation];

    return this.common.tiles[tileId];
  }

  create () {
    this.calculatePosition();

    if (this.tile.frames > 1)
      this.sprite = this.scene.add.sprite(this.x, this.y, this.common.tilemap).play(this.tile.image);
    else
      this.sprite = this.scene.add.sprite(this.x, this.y, this.common.tilemap, this.tile.textures[0]);

    //console.log(this.sprite);

    this.sprite.cell = this.cell;
    this.sprite.type = this.type;

    this.sprite.setScale(this.common.scale);
    this.sprite.setOrigin(0, 0);
    this.sprite.setDepth(this.cell.depth + this.depth + (this.tile.depthAdjustment || 0));
  }

  addSprite (sprite) {
    this.sprites.push(sprite);
  }
}