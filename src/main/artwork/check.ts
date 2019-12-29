import fs from 'fs';
import config from 'config';

export function check(): boolean {
  if (fs.existsSync(config.get<string>('paths.tilemap.data')) && fs.existsSync(config.get<string>('paths.tilemap.image'))) {
    return true;
  } else {
    return false;
  }
}
