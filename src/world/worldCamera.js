import Phaser from 'phaser';

class worldCamera {
  constructor(options) {
    this.scene = options.scene;
    this.common = this.scene.sys.game.common;
    this.camera = this.scene.cameras.main;
    this.camera.name = 'worldCamera';

    let keys = this.scene.input.keyboard.addKeys({
      'up': Phaser.Input.Keyboard.KeyCodes.W,
      'down': Phaser.Input.Keyboard.KeyCodes.S,
      'left': Phaser.Input.Keyboard.KeyCodes.A,
      'right': Phaser.Input.Keyboard.KeyCodes.D,
      'zoomIn': Phaser.Input.Keyboard.KeyCodes.Q,
      'zoomOut': Phaser.Input.Keyboard.KeyCodes.E,
    });

    let controlConfig = {
      camera: this.camera,
      up: keys.up,
      down: keys.down,
      left: keys.left,
      right: keys.right,
      zoomIn: keys.zoomIn,
      zoomOut: keys.zoomOut,
      acceleration: 0.04,
      drag: 0.0005,
      maxSpeed: 1
    };

    this.controls = new Phaser.Cameras.Controls.Smoothed(controlConfig);

    this.scene.input.keyboard.on('keydown_Z', (event) => {
      this.camera.rotation += 0.05;
    });

    this.scene.input.keyboard.on('keydown_X', (event) => {
      this.camera.rotation -= 0.05;
    });

    this.camera.backgroundColor = this.scene.backgroundColor;
    this.camera.scrollX = 1980;
    this.camera.scrollY = -358;
    this.camera.zoom = 1.2;
  }

  update (delta) {
    this.controls.update(delta);
  }

  resize () {
    this.camera.setViewport(0, 0, document.documentElement.clientWidth, document.documentElement.clientHeight);
  }
}

export default worldCamera;