import * as CONST from '../../constants';
import layer from './layer';

export default class subway extends layer {
  constructor (options) {
    options.type = CONST.T_SUBWAY;
    super(options);
  }
}