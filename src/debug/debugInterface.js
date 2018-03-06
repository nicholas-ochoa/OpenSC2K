import dat from 'dat.gui';

class debugInterface {
  constructor (options) {
    this.scene = options.scene;
    this.common = this.scene.sys.game.common;
    this.toggleLayer = this.toggleLayerInit();
    this.createInterface();
  }

  createInterface () {
    this.gui = new dat.GUI();
    this.gui.closed = false;

    let f1 = this.gui.addFolder('Performance');
    f1.add(this.scene.sys.game.loop, 'actualFps', 'FPS').listen();
    f1.open();

    let g1 = this.gui.addFolder('Cursor');
    g1.add(this.scene.input, 'x', 'X').listen();
    g1.add(this.scene.input, 'y', 'Y').listen();

    let w1 = this.gui.addFolder('Cursor World Point');
    w1.add(this.scene.worldPoint, 'x', 'X').listen();
    w1.add(this.scene.worldPoint, 'y', 'Y').listen();

    let w2 = this.gui.addFolder('Highlighted Cell');
    w2.add(this.scene.city.map.selectedCell, 'x', 'X').listen();
    w2.add(this.scene.city.map.selectedCell, 'y', 'Y').listen();
    
    let g2 = this.gui.addFolder('Camera');
    g2.add(this.scene.cameras.main, 'scrollX', 'X').listen();
    g2.add(this.scene.cameras.main, 'scrollY', 'Y').listen();
    g2.add(this.scene.cameras.main, 'zoom', 'Zoom', 0.1, 2).step(0.1).listen();

    let g3 = this.gui.addFolder('City');
    g3.add(this, 'loadCity', 'Open City');
    g3.add(this, 'saveCity', 'Save City');

    let g4 = this.gui.addFolder('World');
    g4.add(this, 'pauseResumeWorld', 'Pause / Resume');
    g4.add(this, 'sleepWakeWorld', 'Sleep / Wake');

    let l1 = this.gui.addFolder('Layer Visibility');
    l1.add(this.toggleLayer, 'terrain', 'Terrain');
    l1.add(this.toggleLayer, 'heightmap', 'Height Map');
    l1.add(this.toggleLayer, 'water', 'Water');
    l1.add(this.toggleLayer, 'road', 'Road');
    l1.add(this.toggleLayer, 'power', 'Power');
    l1.add(this.toggleLayer, 'building', 'Building');
    l1.add(this.toggleLayer, 'zone', 'Zone');
    l1.add(this.toggleLayer, 'rail', 'Rail');
    l1.add(this.toggleLayer, 'highway', 'Highway');
    //l1.add(this.toggleLayer, 'subway', 'Subway');
    //l1.add(this.toggleLayer, 'pipes', 'Pipes');
    l1.open();
  }

  toggleLayerInit () {
    return {
      terrain: () => {
        this.common.world.city.map.toggleLayerVisibility('terrain');
      },
      heightmap: () => {
        this.common.world.city.map.toggleLayerVisibility('heightmap');
      },
      water: () => {
        this.common.world.city.map.toggleLayerVisibility('water');
      },
      road: () => {
        this.common.world.city.map.toggleLayerVisibility('road');
      },
      power: () => {
        this.common.world.city.map.toggleLayerVisibility('power');
      },
      building: () => {
        this.common.world.city.map.toggleLayerVisibility('building');
      },
      zone: () => {
        this.common.world.city.map.toggleLayerVisibility('zone');
      },
      rail: () => {
        this.common.world.city.map.toggleLayerVisibility('rail');
      },
      highway: () => {
        this.common.world.city.map.toggleLayerVisibility('highway');
      },
      subway: () => {
        this.common.world.city.map.toggleLayerVisibility('subway');
      },
      pipes: () => {
        this.common.world.city.map.toggleLayerVisibility('pipes');
      },
    }
  }


  shutdown () {
    if (this.gui);
      this.gui.destroy();
  }

  loadCity () {
    this.scene.loadCity();
  }

  saveCity () {
    this.scene.saveCity();
  }


  pauseResumeWorld () {
    if (this.common.world.scene.isActive())
      this.common.world.scene.pause();
    else
      this.common.world.scene.resume();
  }

  sleepWakeWorld () {
    if (this.common.world.scene.isSleeping())
      this.common.world.scene.wake();
    else
      this.common.world.scene.sleep();
  }


  pauseResumeUI () {
    if (this.common.ui.scene.isActive())
      this.common.ui.scene.pause();
    else
      this.common.ui.scene.resume();
  }

  sleepWakeUI () {
    if (this.common.ui.scene.isSleeping())
      this.common.ui.scene.wake();
    else
      this.common.ui.scene.sleep();
  }
}

export default debugInterface;