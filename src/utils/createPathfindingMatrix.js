export default function (x, y) {
  let grid = [];

  for (let i = 0; i < x; i++) {
    let cells = [];

    for (let j = 0; j < y; j++)
      cells.push(0);

    grid.push(cells);
  }

  return grid;
}