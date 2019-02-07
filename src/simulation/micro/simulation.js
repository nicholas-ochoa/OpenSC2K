export default class simulation {
  constructor (options) {
    this.scene = options.scene;
    this.common = this.scene.sys.game.common;
    this.cell = options.cell;
    this.data = this.cell.data;

    this.sprites = [];

    this.tick = 0; // current tick
    this.tickFrequency = 10; // how often to update

    this.x = options.cell.x;
    this.y = options.cell.y;
    this.z = options.cell.z;
  }

  create () {

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

  addSprite (sprite) {
    this.sprites.push(sprite);
  }
}