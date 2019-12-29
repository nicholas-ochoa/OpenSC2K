import fs from 'fs';
import path from 'path';
import yaml from 'js-yaml';

const data: any = {};
const configDir: string = path.join(process.cwd(), 'config');

function load() {
  const fileList = fs.readdirSync(configDir);

  for (const fileName of fileList) {
    let yamlData: any;
    const filePath: string = path.join(configDir, fileName);

    try {
      yamlData = yaml.load(fs.readFileSync(filePath, 'utf-8'));
    } catch (err) {
      const msg: string = `${err.name}: ${err.reason} in "${filePath}" at line ${err.mark.line} column ${err.mark.column}`;
      throw new Error(msg);
    }

    for (const prop in yamlData) {
      data[prop] = yamlData[prop];
    }
  }
}

export default { load, data };

export { load, data };
