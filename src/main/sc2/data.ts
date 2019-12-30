import { ipcMain } from 'electron';

const data: any = {
  info: {},
  cells: [],
  segments: {},
};

const cells = data.cells;

const segments = data.segments;

const info = data.info;

export default {
  cells,
  segments,
  info,
};

export { data, cells, segments, info };

ipcMain.handle('tiles.data', event => {
  return data;
});
