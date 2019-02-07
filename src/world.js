import Phaser from 'phaser';
import city from './city/city';
import viewport from './world/viewport';
import events from './world/events';
import debug from './debug/debug';
import palette from './import/palette';
import artwork from './import/artwork';
import * as CONST from './constants';
import ui from './ui/gui';

export default class world extends Phaser.Scene {
  constructor () {
    super({ key: 'world' });
  }
  

  preload () {
    this.sys.game.world = this;

    // load binary game assets from original SC2K
    this.load.binary(CONST.PAL_MSTR_BMP, CONST.ASSETS_PATH + CONST.FILE_PAL_MSTR_BMP);
    this.load.binary(CONST.LARGE_DAT,    CONST.ASSETS_PATH + CONST.FILE_LARGE_DAT);

    // start import once files are loaded
    this.load.once(CONST.E_LOAD_COMPLETE, () => {
      this.palette = new palette({ scene: this });
      this.artwork = new artwork({ scene: this });
      this.tiles = this.artwork.tiles;

      // initialize city
      this.city = new city({ scene: this });
    });
  }
  

  create () {
    // load default city
    this.city.load.loadDefaultCity().then(() => {
      this.start();
    });

    //this.ui = new ui({ scene: this });
    this.viewport = new viewport({ scene: this });
    this._events = new events({ scene: this });
    this.debug = new debug({ scene: this });
  }


  start () {
    this.city.create();
  }
  

  update (time, delta) {
    this.viewport.update(delta);
    this.city.update();
  }
  

  shutdown () {
    this.scene.destroy();
  }
}