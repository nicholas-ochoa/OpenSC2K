import { ipcMain } from 'electron';

export const data: any = {};

ipcMain.handle('config.data', event => {
  return data;
});
