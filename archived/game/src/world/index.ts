import Phaser from 'phaser';
import { global } from 'src/global';
import startup from 'startup';

export default class world extends Phaser.Scene {
  private global;

  constructor() {
    super({ key: 'world' });
    this.global = global;
  }

  preload() {
    global.world = this;
    global.scene = this;
    startup.init();
  }

  create() {
    console.log('create scene!');
  }

  start() {
    console.log('scene start!');
  }

  update(time: integer, delta: number) {
    //this.viewport.update(delta);
  }

  shutdown() {
    console.log('scene destroy');
  }
}
