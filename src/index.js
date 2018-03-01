import Phaser from 'phaser';
import load from './load';
import title from './title';
import world from './world';
import ui from './ui/ui';
import styles from './styles/global.css';

var config = {
  type: Phaser.WEBGL,
  parent: 'content',
  width: window.innerWidth,
  height: window.innerHeight,
  scaleMode: 0,
  pixelArt: true,
  backgroundColor: new Phaser.Display.Color(0, 0, 0, 1),
  scene: [
    load,
    title,
    world,
    ui
  ]
};

var game = new Phaser.Game(config);

window.game = game;