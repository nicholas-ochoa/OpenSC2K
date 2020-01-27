import fs from 'fs';
import path from 'path';
import { data } from './data';
import config from 'config';
import yaml from 'js-yaml';
import { parseBitmaps } from './parseBitmaps';
import { parseCursors } from './parseCursors';
import { parseIcons } from './parseIcons';

export async function load() {
  let yamlData: any;
  const fileList = fs.readdirSync(path.resolve(config.get('paths.resources')));

  for (const fileName of fileList) {
    const filePath: string = path.join(config.get('paths.resources'), fileName);

    try {
      yamlData = yaml.load(fs.readFileSync(filePath, 'utf-8'));
    } catch (err) {
      const msg: string = `${err.name}: ${err.reason} in "${filePath}" at line ${err.mark.line} column ${err.mark.column}`;
      throw new Error(msg);
    }

    if (yamlData.bitmaps) {
      data.bitmaps = await parseBitmaps(yamlData.bitmaps);
      continue;
    }

    if (yamlData.cursors) {
      data.cursors = await parseCursors(yamlData.cursors);
      continue;
    }

    if (yamlData.icons) {
      data.icons = await parseIcons(yamlData.icons);
      continue;
    }

    throw new Error(`Unknown resource format`);
  }
}
