let heightmap = [];

heightmap[0] =  { stroke: 'rgba(0, 4, 255,    1)', fill: 'rgba(0, 4, 255,     .3)', lines: 'rgba(0, 4, 255,    .5)' };
heightmap[1] =  { stroke: 'rgba(0, 37, 255,   1)', fill: 'rgba(0, 37, 255,    .3)', lines: 'rgba(0, 37, 255,   .5)' };
heightmap[2] =  { stroke: 'rgba(0, 68, 255,   1)', fill: 'rgba(0, 68, 255,    .3)', lines: 'rgba(0, 68, 255,   .5)' };
heightmap[3] =  { stroke: 'rgba(0, 99, 255,   1)', fill: 'rgba(0, 99, 255,    .3)', lines: 'rgba(0, 99, 255,   .5)' };
heightmap[4] =  { stroke: 'rgba(0, 131, 255,  1)', fill: 'rgba(0, 131, 255,   .3)', lines: 'rgba(0, 131, 255,  .5)' };
heightmap[5] =  { stroke: 'rgba(0, 163, 255,  1)', fill: 'rgba(0, 163, 255,   .3)', lines: 'rgba(0, 163, 255,  .5)' };
heightmap[6] =  { stroke: 'rgba(0, 195, 255,  1)', fill: 'rgba(0, 195, 255,   .3)', lines: 'rgba(0, 195, 255,  .5)' };
heightmap[7] =  { stroke: 'rgba(3, 227, 255,  1)', fill: 'rgba(3, 227, 255,   .3)', lines: 'rgba(3, 227, 255,  .5)' };
heightmap[8] =  { stroke: 'rgba(0, 255, 251,  1)', fill: 'rgba(0, 255, 251,   .3)', lines: 'rgba(0, 255, 251,  .5)' };
heightmap[9] =  { stroke: 'rgba(9, 255, 219,  1)', fill: 'rgba(9, 255, 219,   .3)', lines: 'rgba(9, 255, 219,  .5)' };
heightmap[10] = { stroke: 'rgba(11, 255, 187, 1)', fill: 'rgba(11, 255, 187,  .3)', lines: 'rgba(11, 255, 187, .5)' };
heightmap[11] = { stroke: 'rgba(12, 255, 155, 1)', fill: 'rgba(12, 255, 155,  .3)', lines: 'rgba(12, 255, 155, .5)' };
heightmap[12] = { stroke: 'rgba(14, 255, 123, 1)', fill: 'rgba(14, 255, 123,  .3)', lines: 'rgba(14, 255, 123, .5)' };
heightmap[13] = { stroke: 'rgba(14, 255, 91,  1)', fill: 'rgba(14, 255, 91,   .3)', lines: 'rgba(14, 255, 91,  .5)' };
heightmap[14] = { stroke: 'rgba(16, 255, 58,  1)', fill: 'rgba(16, 255, 58,   .3)', lines: 'rgba(16, 255, 58,  .5)' };
heightmap[15] = { stroke: 'rgba(16, 255, 25,  1)', fill: 'rgba(16, 255, 25,   .3)', lines: 'rgba(16, 255, 25,  .5)' };
heightmap[16] = { stroke: 'rgba(19, 255, 0,   1)', fill: 'rgba(19, 255, 0,    .3)', lines: 'rgba(19, 255, 0,   .5)' };
heightmap[17] = { stroke: 'rgba(41, 255, 0,   1)', fill: 'rgba(41, 255, 0,    .3)', lines: 'rgba(41, 255, 0,   .5)' };
heightmap[18] = { stroke: 'rgba(70, 255, 0,   1)', fill: 'rgba(70, 255, 0,    .3)', lines: 'rgba(70, 255, 0,   .5)' };
heightmap[19] = { stroke: 'rgba(101, 255, 0,  1)', fill: 'rgba(101, 255, 0,   .3)', lines: 'rgba(101, 255, 0,  .5)' };
heightmap[20] = { stroke: 'rgba(132, 255, 0,  1)', fill: 'rgba(132, 255, 0,   .3)', lines: 'rgba(132, 255, 0,  .5)' };
heightmap[21] = { stroke: 'rgba(164, 255, 0,  1)', fill: 'rgba(164, 255, 0,   .3)', lines: 'rgba(164, 255, 0,  .5)' };
heightmap[22] = { stroke: 'rgba(195, 255, 0,  1)', fill: 'rgba(195, 255, 0,   .3)', lines: 'rgba(195, 255, 0,  .5)' };
heightmap[23] = { stroke: 'rgba(227, 255, 0,  1)', fill: 'rgba(227, 255, 0,   .3)', lines: 'rgba(227, 255, 0,  .5)' };
heightmap[24] = { stroke: 'rgba(255, 251, 0,  1)', fill: 'rgba(2255, 251, 0,  .3)', lines: 'rgba(255, 251, 0,  .5)' };
heightmap[25] = { stroke: 'rgba(255, 219, 0,  1)', fill: 'rgba(2255, 219, 0,  .3)', lines: 'rgba(255, 219, 0,  .5)' };
heightmap[26] = { stroke: 'rgba(255, 187, 0,  1)', fill: 'rgba(25255, 187, 0, .3)', lines: 'rgba(255, 187, 0,  .5)' };
heightmap[27] = { stroke: 'rgba(255, 155, 0,  1)', fill: 'rgba(25255, 155, 0, .3)', lines: 'rgba(255, 155, 0,  .5)' };
heightmap[28] = { stroke: 'rgba(255, 123, 0,  1)', fill: 'rgba(22255, 123, 0, .3)', lines: 'rgba(255, 123, 0,  .5)' };
heightmap[29] = { stroke: 'rgba(255, 91, 0,   1)', fill: 'rgba(15255, 91, 0,  .3)', lines: 'rgba(255, 91, 0,   .5)' };
heightmap[30] = { stroke: 'rgba(255, 59, 0,   1)', fill: 'rgba(85255, 59, 0,  .3)', lines: 'rgba(255, 59, 0,   .5)' };
heightmap[31] = { stroke: 'rgba(255, 26, 0,   1)', fill: 'rgba(17255, 26, 0,  .3)', lines: 'rgba(255, 26, 0,   .5)' };

// selection highlight
heightmap[32] = { stroke: 'rgba(255, 255, 0,   1)', fill: 'rgba(0, 0, 0, 0)',        lines: 'rgba(255, 255, 0, .5)'   };

export default heightmap;