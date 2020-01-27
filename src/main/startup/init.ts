import { app, BrowserWindow } from 'electron';
import { watchRenderer } from 'utils/watchRenderer';
import path from 'path';
import config from 'config';
import tiles from 'tiles';
import palette from 'palette';
import artwork from 'artwork';
import ui from 'ui';
import resources from 'resources';

export async function init() {
  // load assets
  await config.load();
  await tiles.load();
  await palette.load();
  await artwork.load();
  await resources.load();

  // register listeners
  await config.register();
  await tiles.register();

  // main window
  ui.windows.main = await new BrowserWindow({
    webPreferences: {
      nodeIntegration: true,
      nodeIntegrationInSubFrames: true,
    },
  });

  const main: Electron.BrowserWindow = ui.windows.main;

  // configure electron
  ui.applicationMenu();

  main.webContents.openDevTools();

  main.setContentSize(1024, 768);

  main.loadFile(path.resolve('assets/html/index.html'));

  main.on('closed', () => {
    app.quit();
  });

  watchRenderer();

  app.on('window-all-closed', () => {
    app.quit();
  });
}
