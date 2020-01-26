import { Menu, MenuItem } from 'electron';
import ui from 'ui';

function openCity() {
  ui.windows.main.webContents.send('menu.file.openCity');
}

function openBudgetWindow() {
  ui.budget();
}

export function applicationMenu() {
  const template: any = [
    {
      label: 'File',
      submenu: [
        new MenuItem({
          label: 'Open City...',
          click: openCity,
        }),
        new MenuItem({
          label: 'Budget Window',
          click: openBudgetWindow
        }),
        { role: 'quit' },
      ],
    },

    {
      label: 'Edit',
      submenu: [
        { role: 'undo' },
        { role: 'redo' },
        { type: 'separator' },
        { role: 'cut' },
        { role: 'copy' },
        { role: 'paste' },
        { role: 'delete' },
        { type: 'separator' },
        { role: 'selectAll' },
      ],
    },

    {
      label: 'View',
      submenu: [
        { role: 'reload' },
        { role: 'forcereload' },
        { role: 'toggledevtools' },
        { type: 'separator' },
        { role: 'resetzoom' },
        { role: 'zoomin' },
        { role: 'zoomout' },
        { type: 'separator' },
        { role: 'togglefullscreen' },
      ],
    },

    {
      label: 'Window',
      submenu: [{ role: 'minimize' }, { role: 'zoom' }, { role: 'close' }],
    },
  ];

  const menu: any = Menu.buildFromTemplate(template);
  Menu.setApplicationMenu(menu);
}
