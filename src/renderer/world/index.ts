import Phaser from 'phaser';
import { globals } from 'utils/globals';

export class world extends Phaser.Scene {
  constructor() {
    super({ key: 'world' });
  }

  init() {
    globals.scenes.world = this;
    globals.world = this;
  }

  create() {
    this.add.sprite(400, 400, 'tilemap').play('1254').setScale(3);

    this.start();
  }

  start() {
    console.log('world scene start!');
  }

  update(time: integer, delta: number) {
    //this.viewport.update(delta);
  }

  shutdown() {
    console.log('scene destroy');
  }
}
