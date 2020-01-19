import fs from 'fs';
import constants from './constants';
import segmentHandlers from './segments/';
import { populateCells } from './populateCells';
import { splitSegments } from './splitSegments';
import { data } from './data';

export function parse(fileName: string): void {
  const buffer: Buffer = fs.readFileSync(fileName);
  const size = constants.MAP_SIZE;
  let x = 0;
  let y = 0;

  for (let i = 0; i < size * size; i++) {
    data.cells.push({ x, y, segments: {} });

    if (y === 127) {
      y = 0;
      x += 1;
    } else {
      y += 1;
    }
  }

  // iterate through each data segment and parse
  // ignoring the first 12 bytes of the file
  const segmentData = splitSegments(buffer.subarray(12));

  Object.keys(segmentData)
    .sort()
    .forEach(title => {
      let type = title;

      // handle special case for scenario text sections
      if (title.startsWith('TEXT')) {
        type = 'TEXT';
      }

      if (segmentHandlers[type]) {
        segmentHandlers[type](segmentData[title]);
      } else {
        console.log('Unknown Segment:', type);
      }
    });

  // city metadata
  data.info = {
    name: data.segments.CNAM.text ?? 'Default',
    height: size,
    width: size,
    rotation: data.segments.MISC.rotation,
    waterLevel: data.segments.MISC.globalSeaLevel,
  };

  populateCells();
}
