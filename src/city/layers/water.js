import * as CONST from '../../constants';
import layer from './layer';

export default class water extends layer {
  constructor (options) {
    options.type = CONST.T_WATER;
    super(options);
  }


  onHide (type) {
    if (type == CONST.T_HEIGHTMAP) this.show(false);
  }


  onShow (type) {
    if (type == CONST.T_HEIGHTMAP) this.hide(false);
  }
}