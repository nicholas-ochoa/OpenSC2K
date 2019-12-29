import { ipcRenderer } from 'electron';

export async function get(path: string): string {
  return await ipcRenderer.invoke('config.get', 'paths.tilemap.image');
}
