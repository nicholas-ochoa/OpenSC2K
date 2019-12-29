export function createPathfindingMatrix(x: integer, y: integer) {
  const grid = [];

  for (let i = 0; i < x; i++) {
    const cells = [];

    for (let j = 0; j < y; j++)
      cells.push(0);

    grid.push(cells);
  }

  return grid;
}
