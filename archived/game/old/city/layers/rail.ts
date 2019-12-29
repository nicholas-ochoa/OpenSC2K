import * as CONST from '../../constants';
import layer from './layer';

export default class rail extends layer {
  constructor (options) {
    options.type = CONST.T_RAIL;
    super(options);
  }
}