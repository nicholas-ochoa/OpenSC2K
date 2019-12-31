import { ipcRenderer } from 'electron';
import { data } from './data';
import { globals } from 'utils/globals';

export async function load(): Promise<void> {
  let configData: any;

  globals.loaded.config = false;

  for (const prop in data) {
    delete data[prop];
  }

  try {
    configData = await ipcRenderer.invoke('config.data');
  } catch (e) {
    console.error(e);
  }

  for (const prop in configData) {
    data[prop] = configData[prop];
  }

  globals.loaded.config = true;
}
