import { app, BrowserWindow } from 'electron';
import path from 'path';
import debug from 'electron-debug';
import config from 'config';
import tiles from 'tiles';
import palette from 'palette';
import artwork from 'artwork';
import { watchRenderer } from 'utils/watchRenderer';

export async function init() {
  await config.load();

  await tiles.load();
  await palette.load();
  await artwork.load();

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

  watchRenderer(win);

  app.on('window-all-closed', () => {
    app.quit();
  });
}
