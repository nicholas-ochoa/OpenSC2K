import { ipcRenderer } from 'electron';
import { data } from './data';
import { globals } from 'utils/globals';

export async function reload(): Promise<void> {
  let tileData: any;

  globals.loaded.tiles = false;

  for (const idx in data) {
    delete data[idx];
  }

  try {
    await ipcRenderer.invoke('tiles.load');

    tileData = await ipcRenderer.invoke('tiles.data');
  } catch (e) {
    console.error(e);
  }

  for (const idx in tileData) {
    data[idx] = tileData[idx];
  }

  delete data[0];

  globals.loaded.tiles = true;
}
