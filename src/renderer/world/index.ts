import Phaser from 'phaser';
import { globalAny } from 'utils/globalAny';
import artwork from 'artwork';

export default class world extends Phaser.Scene {
  constructor() {
    super({ key: 'world' });
  }

  async preload() {
    globalAny.world = this;
    globalAny.scene = this;

    await artwork.load();
  }

  create() {
    console.log('create scene!');

    const atlasTexture = this.textures.get('tilemap');
    const frames = atlasTexture.getFrameNames();

    for (let i = 0; i < frames.length; i++) {
      const x = Phaser.Math.Between(0, 800);
      const y = Phaser.Math.Between(0, 600);

      this.add.image(x, y, 'tilemap', frames[i]);
    }
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
