import * as CONST from '../../constants';
import layer from './layer';

export default class power extends layer {
  constructor (options) {
    options.type = CONST.T_POWER;
    super(options);
  }
}