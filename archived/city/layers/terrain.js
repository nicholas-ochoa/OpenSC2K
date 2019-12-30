import * as CONST from '../../constants';
import layer from './layer';

export default class terrain extends layer {
  constructor (options) {
    options.type = CONST.T_TERRAIN;
    super(options);
    this.showUnderwater = false;
  }


  onHide (type) {
    if (type == CONST.T_HEIGHTMAP) this.show(false);

    if (type == CONST.T_WATER) {
      this.showUnderwater = true;
      this.show();
    }
  }


  onShow (type) {
    if (type == CONST.T_HEIGHTMAP) this.hide(false);

    if (type == CONST.T_WATER) {
      this.showUnderwater = false;
      this.show();
    }
  }
}