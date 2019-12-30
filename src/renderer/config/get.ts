import { ipcRenderer } from 'electron';

export async function get(path: string): Promise<string> {
  const value: string = await ipcRenderer.invoke('config.get', 'paths.tilemap.image');

  return value;
}
