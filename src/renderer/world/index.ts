import Phaser from 'phaser';
import { globals } from 'utils/globals';
import City from 'City';

export class World extends Phaser.Scene {
  public city: City;

  constructor() {
    super({ key: 'World' });
  }

  init() {
    globals.scenes.world = this;
    globals.world = this;
  }

  create() {
    this.add.sprite(400, 400, 'tilemap').play('1254').setScale(3);

    this.city = new City();
    this.city.create();
  }

  update(time: integer, delta: number) {
    //this.viewport.update(delta);
  }

  shutdown() {
    console.log('scene destroy');
  }
}
