import * as tile from './tiles/';
import * as CONST from '../constants';

export default class tiles {
  #cell;
  
  constructor (options) {
    this.#cell = options.cell;
    this.list = options.list;
    this.tiles = [];
    this.sprites = [];

    // initialize tiles
    for (let i = 0; i < this.list.length; i++) {
      if (this.list[i].id == 0) continue;

      if (this.list[i].type == CONST.T_SUBWAY)      continue;
      if (this.list[i].type == CONST.T_PIPE)        continue;
      if (this.list[i].type == CONST.T_UNDERGROUND) continue;
      //if (this.list[i].type == CONST.T_EDGE)        continue;
      if (this.list[i].type == CONST.T_HEIGHTMAP)   continue;
      //if (this.list[i].type == CONST.T_TERRAIN)     continue;
      //if (this.list[i].type == CONST.T_WATER)       continue;
      //if (this.list[i].type == CONST.T_ROAD)        continue;
      //if (this.list[i].type == CONST.T_RAIL)        continue;
      //if (this.list[i].type == CONST.T_POWER)       continue;
      //if (this.list[i].type == CONST.T_HIGHWAY)     continue;
      //if (this.list[i].type == CONST.T_ZONE)        continue;
      //if (this.list[i].type == CONST.T_BUILDING)    continue;

      this[this.list[i].type] = null;
      this.set(this.list[i].type, this.list[i].id);
    }
  }


  getId (type) {
    return this.get(type, true);
  }

  
  get (type, id = false) {
    if (!this[type])
      if (!id)
        return;
      else
        return 0;

    if (this[type])
      if (id)
        return this[type].id;
      else
        return this[type];
  }


  addSprite (sprite, type) {
    this.sprites.push(sprite);
    this.#cell.scene.city.map.addSprite(sprite, type);
  }


  topSprite () {
    this.sprites.sort((a, b) => {
      return a._depth - b._depth;
    });

    return this.sprites[this.sprites.length - 1];
  }


  addTile (tile) {
    this.tiles.push(tile);
  }


  get top () {
    return this.topTile();
  }


  topTile () {
    this.tiles.sort((a, b) => {
      if (a.sprite && !a.sprite.visible) return -1;
      if (b.sprite && !b.sprite.visible) return 1;

      return a.depth - b.depth;
    });

    return this.tiles[this.tiles.length - 1];
  }


  hide () {
    for (let i = 0; i < this.list.length; i++)
      if (this[this.list[i].type])
        this[this.list[i].type].hide();
  }


  show () {
    for (let i = 0; i < this.list.length; i++)
      if (this[this.list[i].type])
        this[this.list[i].type].show();
  }


  has (type) {
    if (this[type] && this[type].props.draw) return true;

    return false;
  }


  set (type, id) {
    if (id == 0) return;
    
    if (this?.[type]?.sprite) this[type].sprite.destroy();

    for (let i = 0; i < this.list.length; i++)
      if (this.list[i].type == type)
        this.list[i].id = id;

    this[type] = new tile[type]({ cell: this.#cell, id: id });
  }


  create () {
    for (let i = 0; i < this.list.length; i++)
      if (this[this.list[i].type])
        this[this.list[i].type].create();
  }

}