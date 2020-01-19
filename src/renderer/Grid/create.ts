import sc2 from 'sc2';
import { data } from './data';
import Grid from 'Grid';
import Cell from 'Cell';

export async function create(this: Grid) {
  for (let i = 0; i < sc2.data.cells.length; i++) {
    const x: number = sc2.data.cells[i].x;
    const y: number = sc2.data.cells[i].y;

    if (!data.cells[x]) {
      data.cells[x] = [];
    }

    if (!data.cells[x][y]) {
      data.cells[x][y] = [];
    }

    //data.cells[x][y] = new Cell({ data: sc2.data.cells[i] });
    data.list.push(data.cells[x][y]);
  }

  //console.log(data.cells);
}
