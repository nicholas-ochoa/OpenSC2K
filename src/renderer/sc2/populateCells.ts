import { cells } from './data';

export function populateCells() {
  // populate data cells
  for (let i = 0; i < cells.length; i++) {
    const cell = cells[i];
    const data = cell.segments;

    cell.tiles = { list: [] };

    if (data.XTER.terrain) {
      cell.tiles.list.push({ id: data.XTER.terrain, type: 'terrain' });
    }

    if (data.XTER.water) {
      cell.tiles.list.push({ id: data.XTER.water, type: 'water' });
    }

    if (cell.x == 0 || cell.x == 127 || cell.y == 0 || cell.y == 127) {
      if (data.XTER.terrain) {
        cell.tiles.list.push({ id: data.XTER.terrain, type: 'edge' });
      }
    }

    if (data.XTER.terrain) {
      cell.tiles.list.push({ id: data.XTER.terrain, type: 'heightmap' });
    }

    if (data.XZON.zone) {
      cell.tiles.list.push({ id: data.XZON.zone, type: 'zone' });
    }

    if (data.XBLD.id != 0) {
      cell.tiles.list.push(data.XBLD);
    }

    if (data.XUND.subway) {
      cell.tiles.list.push({ id: data.XUND.subway, type: 'subway' });
    }

    if (data.XUND.pipes) {
      cell.tiles.list.push({ id: data.XUND.pipes, type: 'pipe' });
    }

    cell.corners = {
      left: data.XZON.left,
      top: data.XZON.top,
      bottom: data.XZON.bottom,
      right: data.XZON.right,
      none: data.XZON.none,
    };

    cell.zone = {
      id: data.XZON.zone,
      type: data.XZON.zoneType,
    };

    cell.z = data.ALTM.altitude;
    cell.rotate = data.XBIT.rotate;

    cell.power = {
      wired: data.XBIT.wired,
      powered: data.XBIT.powered,
    };

    cell.pipes = {
      piped: data.XBIT.piped,
      watered: data.XBIT.watered,
    };

    cell.water = {
      type: data.XTER.type,
      covered: data.XBIT.waterCovered,
      salt: data.XBIT.saltWater,
    };
  }
}
