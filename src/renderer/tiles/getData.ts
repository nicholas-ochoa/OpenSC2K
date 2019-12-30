import { ipcRenderer } from 'electron';
import { data } from './data';

export async function getData() {
  let tileData: any;

  try {
    tileData = await ipcRenderer.invoke('tiles.data');
  } catch (e) {
    console.error(e);
  }

  for (const idx in tileData) {
    data[idx] = tileData[idx];
  }
}
