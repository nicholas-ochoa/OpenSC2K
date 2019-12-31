import { globals } from 'utils/globals';

export function setGlobals() {
  globals.loaded = {
    animations: false,
    config: false,
    tiles: false,
    textures: false,
  };

  globals.scenes = {};
}
