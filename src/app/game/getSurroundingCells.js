// [NW, N, NE] || [x-1 y+1,  x y+1, x+1 y+1]
// [W,  C,  W] || [x-1  y ,   xy  , X+1  y ]
// [SW, S, SE] || [x-1 y-1,  x y-1, x-1 y-1]
export const getSurroundingCells = (tX, tY) => [
  { x: tX - 1, y: tY + 1 }, { x: tX, y: tY + 1 }, { x: tX + 1, y: tY + 1 },
  { x: tX - 1, y: tY     },                       { x: tX + 1, y: tY     }, // eslint-disable-line
  { x: tX - 1, y: tY - 1 }, { x: tX, y: tY - 1 }, { x: tX + 1, y: tY - 1 }
]
