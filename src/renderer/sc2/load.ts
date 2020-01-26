import config from 'config';
import { data } from './data';
import { parse } from './parse';
import { dialogs } from 'ui';
import { extractResources } from './extractResources';

export async function load(fileName?: string): Promise<void> {
  data.info = {};
  data.cells = [];
  data.segments = {};

  console.time('load');

  const filePath: string = fileName ?? config.get('paths.cities') + '/DEFAULT.SC2';

  try {
    parse(filePath);
  } catch (err) {
    console.error(err);
    await dialogs.errorMessage(`Error loading file`, `File "${filePath}" does not exist or is not accessible.`);
    return;
  }

  console.log(data);
  console.timeEnd('load');

  console.time('load exe');
  await extractResources('assets/binaries/SIMCITY.EXE');
  console.timeEnd('load exe');
}
