import * as CONST from '../../constants';
import layer from './layer';

export default class highway extends layer {
  constructor (options) {
    options.type = CONST.T_HIGHWAY;
    super(options);
  }
}