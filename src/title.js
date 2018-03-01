import Phaser from 'phaser';

class title extends Phaser.Scene {
  constructor () {
    super({ key: 'title' });
  }

  preload () {
    this.common = this.sys.game.common;
    this.load.image('title', 'assets/images/title.png');
  }

  create () {
    this.scene.bringToTop();
    this.title = this.add.sprite(0, 0, 'title').setOrigin(0, 0);
    this.startKey = this.input.keyboard.addKey(Phaser.Input.Keyboard.KeyCodes.SPACE);

    // for easy testing
    this.sys.sleep();
    this.common.title = this;
    this.scene.start('world');
  }

  update (time, delta) {
    if(this.startKey.isDown){
      this.sys.sleep();
      this.scene.start('world');
    }
  }

}

export default title;