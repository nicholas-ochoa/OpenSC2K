import PF from 'pathfinding';
import createPathfindingMatrix from './createPathfindingMatrix';

export default function (start, end) {
  let cells = [];

  let width  = (start.x > end.x ? start.x - end.x : end.x - start.x) + 1;
  let height = (start.y > end.y ? start.y - end.y : end.y - start.y) + 1;
  let matrix = createPathfindingMatrix(width, height);

  let grid = new PF.Grid(matrix);

  let finder = new PF.AStarFinder();

  let path = finder.findPath(1, 1, width, height, grid);

  console.log(path);


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