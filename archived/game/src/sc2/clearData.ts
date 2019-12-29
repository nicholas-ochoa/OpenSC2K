import { data } from './data';

export function clearData() {
  for (const prop in data.info) {
    delete data.info[prop];
  }

  for (const prop in data.segments) {
    delete data.segments[prop];
  }

  for (const idx in data.cells) {
    delete data.cells[idx];
  }
}
