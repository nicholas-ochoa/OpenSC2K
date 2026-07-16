import Phaser from 'phaser';
import * as CONST from '../constants';

export default class viewport {
  constructor(options) {
    this.scene        = options.scene;
    this.camera       = this.scene.cameras.main;
    this.camera.name  = CONST.CAMERA_NAME;

    this.objectsRendered = 0;

    this.viewportPaddingMultiplier = 1.5;

    this.worldPoint = {
      x: 0,
      y: 0
    };

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

    this.controls = new Phaser.Cameras.Controls.SmoothedKeyControl(controlConfig);
    this.camera.zoom = 1;
  }


  onPointerMove (pointer) {
    let { x, y } = this.camera.getWorldPoint(pointer.x, pointer.y);

    this.worldPoint.x = x;
    this.worldPoint.y = y;
  }


  update (delta) {
    this.controls.update(delta);

    if (this.controls._speedX !== 0 || this.controls._speedY !== 0 || this.controls._zoom !== 0)
      this.cullObjects();
  }

  centerOnCity () {
    const developedCells = this.scene.city.map.list.filter((cell) =>
      cell.tiles.list.some((tile) =>
        ![CONST.T_TERRAIN, CONST.T_WATER, CONST.T_EDGE].includes(tile.type)
      )
    );

    const cells = developedCells.length > 0
      ? developedCells
      : this.scene.city.map.list;

    const center = cells.reduce((point, cell) => {
      point.x += cell.position.center.x;
      point.y += cell.position.center.y;

      return point;
    }, { x: 0, y: 0 });

    center.x /= cells.length;
    center.y /= cells.length;

    this.camera.centerOn(center.x, center.y);
  }

  cullObjects () {
    let cells = this.scene.city.map.cells;
    let view = new Phaser.Geom.Rectangle(
      this.camera.scrollX,
      this.camera.scrollY,
      this.camera.width / this.camera.zoom,
      this.camera.height / this.camera.zoom
    );
    let cx = view.centerX;
    let cy = view.centerY;

    Phaser.Geom.Rectangle.Scale(view, this.viewportPaddingMultiplier);
    Phaser.Geom.Rectangle.CenterOn(view, cx, cy);

    for (let x = 0; x < CONST.MAP_SIZE; x++)
      for (let y = 0; y < CONST.MAP_SIZE; y++)
        if (Phaser.Geom.Rectangle.Contains(view, cells[x][y].position.center.x, cells[x][y].position.center.y))
          cells[x][y].show();
        else
          cells[x][y].hide();


    this.objectsRendered = 0;

    this.scene.children.list.forEach((gameObject) => {
      if (gameObject.visible) this.objectsRendered++;
    });
  }
}
