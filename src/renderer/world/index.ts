import Phaser from 'phaser';
import { globals } from 'utils/globals';
import city from 'city';

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

    city.create();
  }

  update(time: integer, delta: number) {
    //this.viewport.update(delta);
  }

  shutdown() {
    console.log('scene destroy');
  }
}
