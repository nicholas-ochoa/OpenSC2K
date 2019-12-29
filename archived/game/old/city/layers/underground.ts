import * as CONST from '../../constants';
import layer from './layer';

export default class underground extends layer {
  constructor (options) {
    options.type = CONST.T_UNDERGROUND;
    super(options);
  }
}