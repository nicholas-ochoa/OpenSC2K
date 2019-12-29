import { app, BrowserWindow } from 'electron';
import path from 'path';
import debug from 'electron-debug';

export async function init() {
  debug();

  const win: Electron.BrowserWindow = new BrowserWindow({
    webPreferences: {
      nodeIntegration: true,
    },
  });

  win.setContentSize(1024, 768);

  win.loadFile(path.resolve('assets/html/index.html'));

  win.on('closed', () => {
    app.quit();
  });

  app.on('window-all-closed', () => {
    app.quit();
  });
}
