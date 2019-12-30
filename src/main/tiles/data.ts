import { ipcMain } from 'electron';

export const data: any[] = [];

ipcMain.handle('tiles.data', event => {
  return data;
});
