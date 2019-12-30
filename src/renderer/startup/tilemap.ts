import { global, world } from 'utils/global';
//import tiles from 'tiles';

export function tilemap() {
  global.data.tilemap = {};
  global.data.tilemap.image = world.load.binary('tilemap_png', '/tilemap/tilemap.png');

  //console.log(tiles.data);
}
