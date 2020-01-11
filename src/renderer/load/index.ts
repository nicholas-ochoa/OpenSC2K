import Phaser from 'phaser';
import config from 'config';
import { globals } from 'utils/globals';
import { animations } from './animations';

export class Load extends Phaser.Scene {
  constructor() {
    super({ key: 'Load' });
  }

  init() {
    globals.scenes.load = this;
  }

  preload() {
    const tilemapImage: string = config.get('paths.tilemap.image');
    const tilemapData: string = config.get('paths.tilemap.data');

    this.load.atlas('tilemap', tilemapImage, tilemapData);
    globals.loaded.textures = true;

    this.load.once('postprocess', async () => {
      animations();
    });
  }

  update(time: integer, delta: number) {
    if (globals.loaded.tiles && globals.loaded.textures && globals.loaded.animations) {
      this.scene.start('World');
    }
  }
}
