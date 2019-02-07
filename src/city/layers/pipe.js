import * as CONST from '../../constants';
import layer from './layer';

export default class pipe extends layer {
  constructor (options) {
    options.type = CONST.T_PIPE;
    super(options);
  }
}