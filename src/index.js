import Phaser from 'phaser';
import { Buffer } from 'buffer';
import world from './world';
import $ from 'jquery';
import jQuery from 'jquery';
import './styles/global.css';

globalThis.Buffer = Buffer;

const config = {
  gameTitle: 'OpenSC2K',
  gameURL: 'https://github.com/nicholas-ochoa/OpenSC2K',
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
    mode: Phaser.Scale.RESIZE,
    parent: 'content',
    width: window.innerWidth,
    height: window.innerHeight,
  },
  scene: [
    world
  ]
};

window.$ = $;
window.jQuery = jQuery;
window.game = new Phaser.Game(config);
