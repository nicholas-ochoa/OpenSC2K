import { ipcRenderer } from 'electron';
import { open } from './open';

export async function register() {
  ipcRenderer.on('menu.file.openCity', async () => {
    await open();
  });
}
