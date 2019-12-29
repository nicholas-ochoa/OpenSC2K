import Phaser from 'phaser';

export default class ui extends Phaser.Scene {
  constructor () {
    super({
      key: 'ui',
      active: true
    });

    this.debug = false;
    this.debugOffset = -250;
    this.boundsBuffer = 300;
    
    this.viewport = {
      displayBounds: {},
      displayBoundsBuffer: {},
      worldBounds: {},
      worldBoundsBuffer: {}
    };

    this.preloadComplete = false;
    this.initialized = false;
  }

  preload () {
    this.common = this.sys.game.common;
    this.preloadComplete = true;
  }

  create () {
    if (!this.preloadComplete)
      return;

    this.common.ui = this;
    this.initialized = true;
  }


  updateBounds () {
    if (!this.common || !this.common.world || !this.common.world.worldCamera)
      return;

    let camera = this.common.world.worldCamera.camera;

    this.viewport.width = document.documentElement.clientWidth;
    this.viewport.height = document.documentElement.clientHeight;

    this.viewport.displayBounds.topLeft           = new Phaser.Geom.Point(0 + this.debugOffset,                     0 + this.debugOffset);
    this.viewport.displayBounds.bottomLeft        = new Phaser.Geom.Point(0 + this.debugOffset,                     this.viewport.height - this.debugOffset);
    this.viewport.displayBounds.topRight          = new Phaser.Geom.Point(this.viewport.width - this.debugOffset,   0 + this.debugOffset);
    this.viewport.displayBounds.bottomRight       = new Phaser.Geom.Point(this.viewport.width - this.debugOffset,   this.viewport.height - this.debugOffset);
    this.viewport.displayBounds.width             = this.viewport.displayBounds.bottomRight.x - this.viewport.displayBounds.topLeft.x;
    this.viewport.displayBounds.height            = this.viewport.displayBounds.bottomLeft.y - this.viewport.displayBounds.topLeft.y;
    this.viewport.displayBounds.rect              = new Phaser.Geom.Rectangle(this.viewport.displayBounds.topLeft.x, this.viewport.displayBounds.topLeft.y, this.viewport.displayBounds.width, this.viewport.displayBounds.height);

    this.viewport.displayBoundsBuffer.topLeft     = new Phaser.Geom.Point(this.viewport.displayBounds.topLeft.x + this.boundsBuffer,      this.viewport.displayBounds.topLeft.y + this.boundsBuffer);
    this.viewport.displayBoundsBuffer.bottomLeft  = new Phaser.Geom.Point(this.viewport.displayBounds.bottomLeft.x + this.boundsBuffer,   this.viewport.displayBounds.bottomLeft.y - this.boundsBuffer);
    this.viewport.displayBoundsBuffer.topRight    = new Phaser.Geom.Point(this.viewport.displayBounds.topRight.x - this.boundsBuffer,     this.viewport.displayBounds.topRight.y + this.boundsBuffer);
    this.viewport.displayBoundsBuffer.bottomRight = new Phaser.Geom.Point(this.viewport.displayBounds.bottomRight.x - this.boundsBuffer,  this.viewport.displayBounds.bottomRight.y - this.boundsBuffer);
    this.viewport.displayBoundsBuffer.width       = this.viewport.displayBoundsBuffer.bottomRight.x - this.viewport.displayBoundsBuffer.topLeft.x;
    this.viewport.displayBoundsBuffer.height      = this.viewport.displayBoundsBuffer.bottomLeft.y - this.viewport.displayBoundsBuffer.topLeft.y;
    this.viewport.displayBoundsBuffer.rect        = new Phaser.Geom.Rectangle(this.viewport.displayBoundsBuffer.topLeft.x, this.viewport.displayBoundsBuffer.topLeft.y, this.viewport.displayBoundsBuffer.width, this.viewport.displayBoundsBuffer.height);

    this.viewport.worldBounds.topLeft     = camera.getWorldPoint(this.viewport.displayBounds.topLeft.x,      this.viewport.displayBounds.topLeft.y);
    this.viewport.worldBounds.bottomLeft  = camera.getWorldPoint(this.viewport.displayBounds.bottomLeft.x,   this.viewport.displayBounds.bottomLeft.y);
    this.viewport.worldBounds.topRight    = camera.getWorldPoint(this.viewport.displayBounds.topRight.x,     this.viewport.displayBounds.topRight.y);
    this.viewport.worldBounds.bottomRight = camera.getWorldPoint(this.viewport.displayBounds.bottomRight.x,  this.viewport.displayBounds.bottomRight.y);
    this.viewport.worldBounds.width       = this.viewport.worldBounds.bottomRight.x - this.viewport.worldBounds.topLeft.x;
    this.viewport.worldBounds.height      = this.viewport.worldBounds.bottomLeft.y - this.viewport.worldBounds.topLeft.y;
    this.viewport.worldBounds.rect        = new Phaser.Geom.Rectangle(this.viewport.worldBounds.topLeft.x, this.viewport.worldBounds.topLeft.y, this.viewport.worldBounds.width, this.viewport.worldBounds.height);

    this.viewport.worldBoundsBuffer.topLeft     = camera.getWorldPoint(this.viewport.displayBoundsBuffer.topLeft.x,      this.viewport.displayBoundsBuffer.topLeft.y);
    this.viewport.worldBoundsBuffer.bottomLeft  = camera.getWorldPoint(this.viewport.displayBoundsBuffer.bottomLeft.x,   this.viewport.displayBoundsBuffer.bottomLeft.y);
    this.viewport.worldBoundsBuffer.topRight    = camera.getWorldPoint(this.viewport.displayBoundsBuffer.topRight.x,     this.viewport.displayBoundsBuffer.topRight.y);
    this.viewport.worldBoundsBuffer.bottomRight = camera.getWorldPoint(this.viewport.displayBoundsBuffer.bottomRight.x,  this.viewport.displayBoundsBuffer.bottomRight.y);
    this.viewport.worldBoundsBuffer.width       = this.viewport.worldBoundsBuffer.bottomRight.x - this.viewport.worldBoundsBuffer.topLeft.x;
    this.viewport.worldBoundsBuffer.height      = this.viewport.worldBoundsBuffer.bottomLeft.y - this.viewport.worldBoundsBuffer.topLeft.y;
    this.viewport.worldBoundsBuffer.rect        = new Phaser.Geom.Rectangle(this.viewport.worldBoundsBuffer.topLeft.x, this.viewport.worldBoundsBuffer.topLeft.y, this.viewport.worldBoundsBuffer.width, this.viewport.worldBoundsBuffer.height);

    if (!this.displayArea && !this.displayAreaBuffer && this.debug) {
      this.displayArea = this.add.graphics();
      this.displayArea.fillStyle(0xAA0000, .25);
      this.displayArea.lineStyle(2, 0xAA0000, 1);
      this.displayArea.fillRectShape(this.viewport.displayBounds.rect);
      this.displayArea.strokeRectShape(this.viewport.displayBounds.rect);
      this.displayArea.setDepth(999999999);

      this.displayAreaBuffer = this.add.graphics();
      this.displayAreaBuffer.fillStyle(0xAAAA00, .25);
      this.displayAreaBuffer.lineStyle(2, 0xAAAA00, 1);
      this.displayAreaBuffer.fillRectShape(this.viewport.displayBoundsBuffer.rect);
      this.displayAreaBuffer.strokeRectShape(this.viewport.displayBoundsBuffer.rect);
      this.displayAreaBuffer.setDepth(999999999);
      //this.displayAreaBuffer.setVisible(false);
      
    }

    this.common.viewport = this.viewport;
  }

  // update (time, delta) {
  //   this.updateBounds();
  // }

  resize () {
    this.cameras.main.setViewport(0, 0, document.documentElement.clientWidth, document.documentElement.clientHeight);

    if (this.displayArea && this.displayAreaBuffer && this.debug) {
      this.displayArea.clear();
      this.displayAreaBuffer.clear();

      this.displayArea = undefined;
      this.displayAreaBuffer = undefined;
    }
  }

  shutdown () {
    if (!this.initialized)
      return;

    this.initialized = false;
    this.preloadComplete = false;

    this.scene.stop();
  }

}