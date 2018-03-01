import Phaser from 'phaser';
import worldCamera from './worldCamera';

class worldEvents {
  constructor(options) {
    this.scene = options.scene;
    this.sceneEvents = this.scene.events;
    this.events = this.scene.sys.game.events;
    this.common = this.scene.sys.game.common;

    this.initialize();
  }

  initialize () {
    window.onresize = (event) => {
      this.events.emit('resize');
    }

    this.events.on('resize', this.resize, this);
    this.sceneEvents.once('shutdown', this.shutdown, this)
  }

  resize () {
    this.scene.sys.game.config.width = document.documentElement.clientWidth;
    this.scene.sys.game.config.height = document.documentElement.clientHeight;
    this.scene.sys.game.canvas.style.width = document.documentElement.clientWidth + 'px';
    this.scene.sys.game.canvas.style.height = document.documentElement.clientHeight + 'px';
    this.scene.sys.game.renderer.resize(document.documentElement.clientWidth, document.documentElement.clientHeight);
    this.scene.sys.game.input.updateBounds();
    this.common.world.resize();
    this.common.ui.resize();
  }

  shutdown () {
    this.events.off('resize', this.resize, this);
  }
}

export default worldEvents;