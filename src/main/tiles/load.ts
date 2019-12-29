import fs from 'fs';
import path from 'path';
import { getData } from './getData';
import { data } from './data';
import config from 'config';

export function load() {
  const fileList = fs.readdirSync(path.resolve(config.get<string>('paths.tiles')));
  const yamlFiles: string[] = [];

  for (const fileName of fileList) {
    const filePath: string = path.join(config.get<string>('paths.tiles'), fileName);

    if (fs.statSync(filePath).isDirectory()) {
      const subFileList = fs.readdirSync(filePath);

      for (const subFileName of subFileList) {
        const subFilePath: string = path.join(filePath, subFileName);
        yamlFiles.push(subFilePath);
      }
    } else {
      yamlFiles.push(filePath);
    }
  }

  for (const yaml of yamlFiles) {
    const parsed = getData(yaml);

    for (const idx in parsed) {
      data[idx] = parsed[idx];
    }
  }
}
