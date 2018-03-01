import map from './map';
import util from '../common/utils';

class city {
  constructor (options) {
    this.scene = options.scene;
    this.common = this.scene.sys.game.common;
    this.loaded = false;

    this.name = 'Default City';
    this.rotation = 0;
    this.waterLevel = 4;
    this.width = 128;
    this.height = 128;

    this.rotationModifier();

    this.map = new map({
      scene: this.scene,
      width: this.width,
      height: this.height
    });
  }

  load () {
    if (!this.common.data) {
      this.scene.importCity.loadDefaultCity();
      return;
    }


    this.name = this.common.data.info.name;
    this.rotation = this.common.data.info.rotation;
    this.waterLevel = this.common.data.info.waterLevel;
    this.width = this.common.data.info.width;
    this.height = this.common.data.info.height;

    this.rotationModifier();

    this.map.load();
    this.loaded = true;
  }

  create () {
    if (!this.loaded) {
      this.scene.importCity.loadDefaultCity();
      return;
    }

    this.map.create();
  }

  update () {
    this.map.update();
  }

  shutdown () {
    this.loaded = false;
    this.map = undefined;
  }

  rotationModifier () {
    let modifier = 0;

    if (this.rotation == 3)
      modifier = 0;

    if (this.rotation == 2)
      modifier = 1;

    if (this.rotation == 1)
      modifier = 2;

    if (this.rotation == 0)
      modifier = 3;

    this.cityRotation = util.wrap(this.rotation + modifier, 0, 3);
    //console.log('cityRotation:', this.cityRotation, 'importedRotation:', this.rotation, 'modifier:', modifier);
  }
}

export default city;