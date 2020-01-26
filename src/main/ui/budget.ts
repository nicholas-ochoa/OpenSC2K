import { BrowserWindow } from 'electron';
import { ipcMain } from 'electron';
import path from 'path';
import ui from 'ui';

export async function budget() {
  ui.windows.budget = await new BrowserWindow({
    parent: ui.windows.main,
    modal: true,
    show: false,
    frame: false,
    resizable: false,
    skipTaskbar: true,
    backgroundColor: '#d4d0c8',
    webPreferences: {
      nodeIntegration: true,
    },
  });

  const budget: Electron.BrowserWindow = ui.windows.budget;

  budget.webContents.openDevTools();

  budget.setContentSize(440, 470);

  budget.loadFile(path.resolve('src/renderer/ui/windows/budget/budget.html'));

  budget.show();
}

ipcMain.handle('openBudgetWindow', async (event) => {
  try {
    await budget();
  } catch (err) {
    console.error('handler error', err);
  }
});
