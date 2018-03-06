import Phaser from 'phaser';
import palette from './import/palette';
import parseImageDat from './import/parseImageDat';

class assets extends Phaser.Scene {
  constructor () {
    super({ key: 'assets' });
  }


  preload () {
    this.common = this.sys.game.common;

    let path = './assets/import/';

    this.load.binary('LARGE.DAT', path + 'LARGE.DAT');
    this.load.binary('SMALLMED.DAT', path + 'SMALLMED.DAT');
    this.load.binary('SPECIAL.DAT', path + 'SPECIAL.DAT');
    this.load.binary('PAL_MSTR.BMP', path + 'PAL_MSTR.BMP');
    this.load.binary('TITLESCR.BMP', path + 'TITLESCR.BMP');
  }


  create () {
    this.common.import = this;

    this.files = {
      LARGE_DAT: this.cache.binary.get('LARGE.DAT'),
      SMALLMED_DAT: this.cache.binary.get('SMALLMED.DAT'),
      SPECIAL_DAT: this.cache.binary.get('SPECIAL.DAT'),
      PAL_MSTR_BMP: this.cache.binary.get('PAL_MSTR.BMP'),
      TITLESCR_BMP: this.cache.binary.get('TITLESCR.BMP'),
    }

    this.palette = new palette({
      scene: this,
      data: this.files.PAL_MSTR_BMP
    });

    this.largedat = new parseImageDat({
      scene: this,
      data: this.files.LARGE_DAT
    });

    this.smallmeddat = new parseImageDat({
      scene: this,
      data: this.files.SMALLMED_DAT
    });

    this.specialdat = new parseImageDat({
      scene: this,
      data: this.files.SPECIAL_DAT
    });
  }
}

export default assets;