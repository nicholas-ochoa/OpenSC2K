import * as CONST from '../constants';
import * as segmentHandlers from './segmentHandlers/';
import { bytesToAscii } from './segmentHandlers/common';

export default class sc2 {
  import (buffer) {
    let size = CONST.MAP_SIZE;
    let x = 0;
    let y = 0;
    let map = {
      cells: [],
      _segmentData: {}
    };

    for (let i = 0; i < size * size; i++) {
      map.cells.push({ x: x, y: y, _segmentData: {} });

      if (y === 127) {
        y = 0;
        x += 1;
      } else {
        y += 1;
      }
    }


    // iterate through each data segment and parse
    let bytes = buffer.subarray(12);
    let segments = this.splitSegments(bytes);

    Object.keys(segments).sort().forEach((title) => {
      let type = title;

      // handle special case for scenario
      // text sections
      if (title.startsWith('TEXT'))
        type = 'TEXT';
        
      let handler = segmentHandlers[type];

      if (handler)
        handler(segments[title], map);
      else
        console.log('Unknown Segment:',type);
    });


    // city metadata
    map.info = {
      name:        map._segmentData.CNAM.text || 'Default',
      height:      size,
      width:       size,
      rotation:    map._segmentData.MISC.rotation,
      waterLevel:  map._segmentData.MISC.globalSeaLevel,
    };


    // populate data cells
    for (let i = 0; i < map.cells.length; i++) {
      let cell = map.cells[i];
      let data = cell._segmentData;

      cell.tiles = { _list: [] };

      if (data.XTER.terrain)  cell.tiles._list.push({ id: data.XTER.terrain,  type: CONST.T_TERRAIN });
      if (data.XTER.water)    cell.tiles._list.push({ id: data.XTER.water,    type: CONST.T_WATER });

      if (cell.x == 0 || cell.x == 127 || cell.y == 0 || cell.y == 127)
        if (data.XTER.terrain)  cell.tiles._list.push({ id: data.XTER.terrain,  type: CONST.T_EDGE });

      //if (data.XTER.terrain)  cell.tiles._list.push({ id: data.XTER.terrain,  type: CONST.T_HEIGHTMAP });
      
      //if (data.XZON.zone)     cell.tiles._list.push({ id: data.XZON.zone,     type: CONST.T_ZONE });

      if (data.XBLD.id != 0) cell.tiles._list.push(data.XBLD);

      //if (data.XUND.subway)   cell.tiles._list.push({ id: data.XUND.subway,   type: CONST.T_SUBWAY });
      //if (data.XUND.pipes)    cell.tiles._list.push({ id: data.XUND.pipes,    type: CONST.T_PIPES });

      cell.corners = {
        left:   data.XZON.left,
        top:    data.XZON.top,
        bottom: data.XZON.bottom,
        right:  data.XZON.right,
        none:   data.XZON.none,
      };

      cell.zone = {
        id:   data.XZON.zone,
        type: data.XZON.zoneType,
      };

      cell.z      = data.ALTM.altitude;
      cell.rotate = data.XBIT.rotate;

      cell.power = {
        wired:   data.XBIT.wired,
        powered: data.XBIT.powered,
      };

      cell.pipes = {
        piped:   data.XBIT.piped,
        watered: data.XBIT.watered,
      };

      cell.water = {
        type:       data.XTER.type,
        covered:    data.XBIT.waterCovered,
        salt:       data.XBIT.saltWater,
      };

      map.cells[i] = cell;
    }

    return map;
  }


  splitSegments (bytes) {
    let segments = {};

    while (bytes.length > 0) {
      let title    = bytesToAscii(bytes.subarray(0x00, 0x04));
      let length   = new DataView(bytes.subarray(0x04, 0x08).buffer).getUint32(bytes.subarray(0x04, 0x08).byteOffset);
      let contents = bytes.subarray(0x08, 0x08 + length);

      if (!['ALTM','CNAM','TEXT','PICT','SCEN','TMPL'].includes(title))
        contents = this.decompressSegment(contents);

      // can have multilpe TEXT segments
      if (title == 'TEXT') {
        let type = bytes.subarray(0x08, 0x09);

        if (type == 0x80)
          title = 'TEXT_1';
        else if (type == 0x81)
          title = 'TEXT_2';
      }

      segments[title] = contents;
      bytes = bytes.subarray(0x08 + length);
    }

    return segments;
  }


  decompressSegment (bytes) {
    let output = [];
    let dataCount = 0;

    for (let i = 0; i < bytes.length; i++) {
      if (dataCount > 0) {
        output.push(bytes[i]);
        dataCount -= 1;
        continue;
      }

      // data bytes
      if (bytes[i] < 128) {
        dataCount = bytes[i];
      
      // run-length encoded byte
      } else {
        let repeatCount = bytes[i] - 127;
        let repeated = bytes[i + 1];

        for (let i = 0; i < repeatCount; i++)
          output.push(repeated);
        
        // skip the next byte
        i += 1;
      }
    }

    return Uint8Array.from(output);
  }
}