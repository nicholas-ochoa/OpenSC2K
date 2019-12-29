import Phaser from 'phaser';
import world from './world';

const config = {
  gameTitle: 'OpenSC2K',
  gameURL: 'https://github.com/rage8885/OpenSC2K',
  type: Phaser.WEBGL,
  resolution: 1,
  autoRound: true,
  disableContextMenu: false,
  banner: true,
  audio: {
    noAudio: true,
  },
  render: {
    antialias: false,
    pixelArt: true,
    batchSize: 32767
  },
  scale: {
    mode: Phaser.Scale.ScaleModes.RESIZE,
    parent: 'content',
    width: window.innerWidth,
    height: window.innerHeight,
  },
  scene: [
    world
  ]
};

const wa: any = window;
wa.game = new Phaser.Game(config);
