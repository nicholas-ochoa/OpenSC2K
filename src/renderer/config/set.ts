import { ipcRenderer } from 'electron';
import { load } from './load';

export async function set(path: string, value: any): Promise<void> {
  try {
    await ipcRenderer.invoke('config.set', path, value);
    await load();
  } catch (e) {
    console.error(e);
  }
}
