import * as CONST from '../../constants';
import layer from './layer';

export default class zone extends layer {
  constructor (options) {
    options.type = CONST.T_ZONE;
    super(options);
  }
}