import { ipcRenderer } from 'electron';
import { data } from './data';
import { globals } from 'utils/globals';

export async function reload(): Promise<void> {
  let configData: any;

  try {
    configData = await ipcRenderer.invoke('config.load');
  } catch (e) {
    console.error(e);
  }

  for (const prop in configData) {
    data[prop] = configData[prop];
  }

  globals.loaded.config = true;
}
