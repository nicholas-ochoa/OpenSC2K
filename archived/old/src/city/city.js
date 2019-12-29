import map from './map';
import load from './load';
//import save from './save';
//import simulator from '../simulator/simulator';
import * as CONST from '../constants';

export default class city {
  constructor (options) {
    this.scene = options.scene;
    this.load = new load({ scene: this.scene });
    //this.save = new save({ scene: this.scene });
    this.corner;
    this.map = new map({ scene: this.scene });
  }

  create () {
    this.name       = this.scene.importedData.info.name       || 'Default City';
    this.rotation   = this.scene.importedData.info.rotation   || 0;
    this.waterLevel = this.scene.importedData.info.waterLevel || 4;

    if (this.rotation == 0) this.corner = CONST.CORNER_BOTTOM;
    if (this.rotation == 1) this.corner = CONST.CORNER_LEFT;
    if (this.rotation == 2) this.corner = CONST.CORNER_TOP;
    if (this.rotation == 3) this.corner = CONST.CORNER_RIGHT;

    this.map.create();
    //this.simulator = new simulator({ scene: this.scene });

    this.initialized = true;
  }

  update () {
    if (!this.initialized) return;

    this.map.update();
  }

  shutdown () {
    this.initialized = false;

    if (this.map) this.map.shutdown();
  }
}