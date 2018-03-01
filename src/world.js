import Phaser from 'phaser';
import city from './city/city';
import worldCamera from './world/worldCamera';
import worldEvents from './world/worldEvents';
import importCity from './import/importCity';
import saveCity from './city/saveCity';
import debugInterface from './debug/debugInterface';

class world extends Phaser.Scene {
  constructor () {
    super({
      key: 'world'
    });

    this.preloadComplete = false;
    this.initialized = false;

    this.worldPoint = {
      x: 0,
      y: 0
    }
  }

  preload () {
    this.common = this.sys.game.common;
    this.backgroundColor = new Phaser.Display.Color(55, 23, 0, 1);

    if (!this.common.data) {
      let imp = new importCity({ scene: this });
      imp.loadDefaultCity();
      this.shutdown();
      return;
    }

    this.city = new city({
      scene: this
    });

    this.preloadComplete = true;
  }

  create () {
    if (!this.preloadComplete)
      return;

    this.worldCamera = new worldCamera({ scene: this });

    this.input.on('pointermove', (pointer) => {
      let p = this.worldCamera.camera.getWorldPoint(pointer.x, pointer.y);

      this.worldPoint.x = p.x;
      this.worldPoint.y = p.y;
    });

    this.worldEvents = new worldEvents({ scene: this });
    this.debugInterface = new debugInterface({ scene: this });

    this.city.load();
    this.city.create();

    this.common.world = this;
    this.initialized = true;
  }

  update (time, delta) {
    if (!this.initialized)
      return;

    this.worldCamera.update(delta);

    this.city.update();
  }

  shutdown () {
    if (!this.initialized)
      return;

    this.initialized = false;
    this.preloadComplete = false;

    if (this.debugInterface);
      this.debugInterface.shutdown();

    if (this.city)
      this.city.shutdown();

    if (this.worldEvents)
      this.worldEvents.shutdown();

    this.scene.stop();
  }

  resize () {
    this.cameras.main.setViewport(0, 0, document.documentElement.clientWidth, document.documentElement.clientHeight);
  }

  saveCity () {
    let exp = new saveCity({ scene: this });
    exp.export();
  }

  loadCity () {
    let imp = new importCity({ scene: this });
    imp.openFile();
    this.shutdown();
  }

}

export default world;