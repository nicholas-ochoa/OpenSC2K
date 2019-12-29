import * as CONST from '../../constants';
import layer from './layer';

export default class building extends layer {
  constructor (options) {
    options.type = CONST.T_BUILDING;
    super(options);
  }
}