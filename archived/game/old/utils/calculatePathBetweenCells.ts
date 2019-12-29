import PF from 'pathfinding';
import { createPathfindingMatrix } from './createPathfindingMatrix';

export function calculatePathBetweenCells(start: any, end: any) {
  const cells: any = [];

  const width  = (start.x > end.x ? start.x - end.x : end.x - start.x) + 1;
  const height = (start.y > end.y ? start.y - end.y : end.y - start.y) + 1;
  const matrix = createPathfindingMatrix(width, height);

  const grid = new PF.Grid(matrix);

  const finder = new PF.AStarFinder();

  const path = finder.findPath(1, 1, width, height, grid);

  return cells;

  // let dx = end.x - start.x;
  // let dy = end.y - start.y;

  // let nx = Math.abs(dx);
  // let ny = Math.abs(dy);

  // let sx = dx > 0? 1 : -1;
  // let sy = dy > 0? 1 : -1;

  // let point = { x: start.x, y: start.y };
  // let cells = [];

  // cells.push({ x: start.x, y: start.y });

  // for (let ix = 0, iy = 0; ix < nx || iy < ny;) {
  //   if ((0.5 + ix) / nx < (0.5 + iy) / ny) {
  //     point.x += sx;
  //     ix++;
  //   } else {
  //     point.y += sy;
  //     iy++;
  //   }

  //   cells.push({ x: point.x, y: point.y });
  // }

  // return cells;
}
