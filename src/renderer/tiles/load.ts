import { ipcRenderer } from 'electron';

export function load() {
  (async () => await ipcRenderer.invoke('tiles.load'))();
}
