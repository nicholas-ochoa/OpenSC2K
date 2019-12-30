import fs from 'fs';
import yaml from 'js-yaml';

export function parse(file: string) {
  let yamlData: any;
  const data: any[] = [];

  try {
    yamlData = yaml.load(fs.readFileSync(file, 'utf-8'));
  } catch (err) {
    const msg: string = `${err.name}: ${err.reason} in "${file}" at line ${err.mark.line} column ${err.mark.column}`;
    throw new Error(msg);
  }

  for (const idx in yamlData.tiles) {
    data[idx] = {};

    data[idx].id = parseInt(idx);

    // default properties
    for (const prop in yamlData.all) {
      data[idx][prop] = yamlData.all[prop];
    }

    // per tile properties
    for (const prop in yamlData.tiles[idx]) {
      data[idx][prop] = yamlData.tiles[idx][prop];
    }
  }

  return data;
}
