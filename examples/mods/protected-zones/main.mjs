// Protected zones: the bulldozer and the terrain tools cannot change the
// tiles in a protected rectangle. A sign marks each zone.
//
//   protect 10 10 20 20     protects the rectangle from tile 10, 10 to 20, 20
//   protect                 lists the zones
//   unprotect               removes all zones and their signs
//
// Uses: the cancelable tool.beforeApply event, city.setSign, game.storage.

const STORAGE_KEY = 'protected-zones.zones';
// the tool groups that remove or reshape what is on a tile
const GUARDED_GROUPS = ['Bulldozer', 'Landscape'];

const zones = () => game.storage.get(STORAGE_KEY, []);

function inside(zone, tile) {
  return tile.x >= zone.left && tile.x <= zone.right && tile.y >= zone.top && tile.y <= zone.bottom;
}

// true when the drag from start to finish touches a zone
function touches(zone, start, finish) {
  return !(
    Math.max(start.x, finish.x) < zone.left || Math.min(start.x, finish.x) > zone.right
    || Math.max(start.y, finish.y) < zone.top || Math.min(start.y, finish.y) > zone.bottom
  );
}

game.on('tool.beforeApply', (event) => {
  if (!GUARDED_GROUPS.includes(event.tool.groupName)) {
    return;
  }

  const zone = zones().find((candidate) => touches(candidate, event.start, event.finish));

  if (zone) {
    event.cancel();
    game.status(`${zone.name} is protected. The ${event.tool.name} tool cannot change it.`);
  }
});

export function protect(left, top, right, bottom) {
  const zone = {
    name: `Protected zone ${zones().length + 1}`,
    left: Math.min(left, right),
    top: Math.min(top, bottom),
    right: Math.max(left, right),
    bottom: Math.max(top, bottom),
  };

  game.storage.set(STORAGE_KEY, [...zones(), zone]);

  try {
    city.setSign(zone.left, zone.top, zone.name);
  } catch (error) {
    console.warn(`No sign for ${zone.name}: ${error.message}`);
  }

  return zone;
}

game.command('protect', 'Protect a rectangle from the bulldozer: protect left top right bottom.', (...words) => {
  if (words.length === 0) {
    const list = zones();

    return list.length === 0 ? 'No zones are protected.' : list.map((zone) => `${zone.name}: ${zone.left},${zone.top} to ${zone.right},${zone.bottom}`).join('\n');
  }

  const numbers = words.map(Number);

  if (numbers.length !== 4 || !numbers.every(Number.isInteger)) {
    throw new Error('Give four tile numbers: protect left top right bottom.');
  }

  const zone = protect(...numbers);

  return `${zone.name} protects ${zone.left},${zone.top} to ${zone.right},${zone.bottom}.`;
});

game.command('unprotect', 'Remove all protected zones and their signs.', () => {
  for (const zone of zones()) {
    if (city.sign(zone.left, zone.top) === zone.name) {
      city.setSign(zone.left, zone.top, '');
    }
  }

  game.storage.remove(STORAGE_KEY);

  return 'All zones are unprotected.';
});

export { inside };
