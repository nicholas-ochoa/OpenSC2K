import * as CONST from '../../constants';
import layer from './layer';

export default class edge extends layer {
  constructor (options) {
    options.type = CONST.T_EDGE;
    super(options);
  }


  hide (type) {
    this.visible = false;

    this.list.forEach((tile) => {
      tile.hide(type);
    });

    this.events.emit(CONST.E_MAP_LAYER_HIDE, this.type);
  }


  show (type) {
    this.visible = true;

    this.list.forEach((tile) => {
      tile.show(type);
    });

    this.events.emit(CONST.E_MAP_LAYER_SHOW, this.type);
  }


  onHide (type) {
    if (type == CONST.T_WATER)     this.hide(CONST.TERRAIN_WATER);
    if (type == CONST.T_TERRAIN)   this.hide(CONST.TERRAIN_BEDROCK);
    if (type == CONST.T_HEIGHTMAP) this.show(false);
  }


  onShow (type) {
    if (type == CONST.T_WATER)     this.show(CONST.TERRAIN_WATER);
    if (type == CONST.T_TERRAIN)   this.show(CONST.TERRAIN_BEDROCK);
    if (type == CONST.T_HEIGHTMAP) this.hide(false);
  }
}