import dat from 'dat.gui';

class debugInterface {
  constructor (options) {
    this.scene = options.scene;
    this.common = this.scene.sys.game.common;

    this.createInterface();
  }

  createInterface () {
    this.gui = new dat.GUI();
    this.gui.closed = true;

    let f1 = this.gui.addFolder('Performance');
    f1.add(this.scene.sys.game.loop, 'actualFps', 'FPS').listen();
    f1.open();

    let g1 = this.gui.addFolder('Cursor');
    g1.add(this.scene.input, 'x', 'X').listen();
    g1.add(this.scene.input, 'y', 'Y').listen();

    let w1 = this.gui.addFolder('Cursor World Point');
    w1.add(this.scene.worldPoint, 'x', 'X').listen();
    w1.add(this.scene.worldPoint, 'y', 'Y').listen();
    
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

    //let g5 = this.gui.addFolder('UI');
    //g5.add(this, 'pauseResumeUI', 'Pause / Resume');
    //g5.add(this, 'sleepWakeUI', 'Sleep / Wake');
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