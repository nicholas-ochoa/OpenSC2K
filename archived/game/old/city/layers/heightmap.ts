import * as CONST from '../../constants';
import layer from './layer';

export default class heightmap extends layer {
  constructor (options) {
    options.type = CONST.T_HEIGHTMAP;
    super(options);
    this.visible = false;
  }
}