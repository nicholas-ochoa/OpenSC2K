import * as CONST from '../../constants';

export default class layer {
  constructor (options) {
    this.scene   = options.scene;
    this.type    = options.type;
    this.map     = options.scene.city.map;
    this.events  = options.scene.events;
    this.visible = options.visible || true;
    this.list    = [];

    this.map.list.forEach((cell) => {
      if (!cell || !cell.tiles)
        return;

      if (cell.tiles[this.type])
        this.list.push(cell.tiles[this.type]);
    });

    this.events.on(CONST.E_MAP_LAYER_HIDE, this.onHide, this);
    this.events.on(CONST.E_MAP_LAYER_SHOW, this.onShow, this);
  }

  toggle () {
    if (this.visible)
      this.hide();
    else
      this.show();
  }

  hide (emitEvents = true) {
    this.visible = false;

    this.list.forEach((tile) => {
      tile.hide();
    });

    if (emitEvents) this.events.emit(CONST.E_MAP_LAYER_HIDE, this.type);
  }

  show (emitEvents = true) {
    this.visible = true;

    this.list.forEach((tile) => {
      tile.show();
    });

    if (emitEvents) this.events.emit(CONST.E_MAP_LAYER_SHOW, this.type);
  }

  refresh () {
    this.hide();
    this.show();
  }

  onHide (type) {
    return;
  }

  onShow (type) {
    return;
  }
}