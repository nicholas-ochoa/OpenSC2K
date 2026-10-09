// Road grid: builds a grid of roads with the Road tool, as a player who
// drags each road would. The normal costs and rules apply.
//
//   grid 20 20 30 30       a grid from tile 20, 20, 30 tiles wide and high
//   grid 20 20 30 30 6     the same with a road every 6 tiles (default 5)
//
// Uses: tools.select, tools.apply, tools.selected, game.command.

function build(from, to) {
  const result = tools.apply(from, to);

  return result.changed ? result.cost : 0;
}

game.command('grid', 'Build a road grid: grid x y width height [spacing].', (...words) => {
  const [x, y, width, height, spacing = 5] = words.map(Number);

  if (![x, y, width, height, spacing].every(Number.isInteger) || width < 1 || height < 1 || spacing < 2) {
    throw new Error('Use: grid x y width height [spacing], with whole numbers and a spacing of 2 or more.');
  }

  const previous = tools.selected;
  tools.select('Roads', 'Road');
  let cost = 0;
  let roads = 0;

  for (let row = y; row <= y + height; row += spacing) {
    cost += build([x, row], [x + width, row]);
    roads += 1;
  }

  for (let column = x; column <= x + width; column += spacing) {
    cost += build([column, y], [column, y + height]);
    roads += 1;
  }

  tools.select(previous.group, previous.subtool);

  return `Built ${roads} roads for $${cost}.`;
});
