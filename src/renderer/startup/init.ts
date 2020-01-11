import Phaser from 'phaser';
import { Load } from 'Load';
import { World } from 'World';
import { globals } from 'utils/globals';
import { setGlobals } from './setGlobals';
import config from 'config';
import tiles from 'tiles';

export async function init() {
  const phaserConfig: any = {
    gameTitle: 'OpenSC2K',
    gameURL: 'https://github.com/rage8885/OpenSC2K',
    gameVersion: '1.0',
    renderType: Phaser.WEBGL,
    parent: 'content',
    expandParent: true,
    autoRound: true,
    pixelArt: true,
    //batchSize: 32767,
    //inputGamepad: false,
    sbanner: false,
    audio: {
      noAudio: true,
    },
    width: window.innerWidth,
    height: window.innerHeight,
    scaleMode: Phaser.Scale.ScaleModes.RESIZE,
    scene: [Load, World],
  };

  setGlobals();

  await tiles.load();
  await config.load();

  globals.game = new Phaser.Game(phaserConfig);
}
