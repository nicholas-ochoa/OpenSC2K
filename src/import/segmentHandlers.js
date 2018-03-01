import { xundMap, xterMap, xzonMap, waterLevels } from './constants';

class segmentHandlers {
  ALTM (data, struct) {
    let view = new DataView(data.buffer, data.byteOffset, data.byteLength);

    // read two bytes every loop
    for (let i = 0; i < data.byteLength / 2; i++) {
      let bits = view.getUint16(i * 2);
      let altm = {};

      altm.tunnelLevels  = (bits & 0xFF00); // bytes 0..7
      altm.waterCovered  = (bits & 0x0080) !== 0; // bytes 8, bool
      altm.waterLevel    = (bits & 0x0060); // bytes 9..10
      altm.altitude      = (bits & 0x001F); // bytes 11..15

      struct.tiles[i].ALTM = altm;
    }
  }


  CNAM (data, struct) {
    let view = new Uint8Array(data);
    let len = view[0] & 0x3F; // limit to 32
    let strDat = view.subarray(1, 1 + len);

    struct.cityName = Array.prototype.map.call(strDat, x => String.fromCharCode(x)).join('').replace(/[^a-zA-Z0-9 ]+/g, '');
  }


  XBIT (data, struct) {
    let view = new Uint8Array(data);

    view.forEach((bits, i) => {
      let xbit = {};

      xbit.conductive    = (bits & 0x80) !== 0;
      xbit.powered       = (bits & 0x40) !== 0;
      xbit.piped         = (bits & 0x20) !== 0;
      xbit.watered       = (bits & 0x10) !== 0;
      xbit.landValueMask = (bits & 0x08) !== 0;
      xbit.waterCovered  = (bits & 0x04) !== 0;
      xbit.rotate        = (bits & 0x02) !== 0;
      xbit.saltWater     = (bits & 0x01) !== 0;

      struct.tiles[i].XBIT = xbit;
    });
  }


  XBLD (data, struct) {
    let view = new Uint8Array(data);

    view.forEach((bits, i) => {
      let xbld = {};

      xbld.building = 0;
      xbld.road = 0;
      xbld.rail = 0;
      xbld.power = 0;
      xbld.highway = 0;

      // buildings
      if ((bits > 0x00 && bits <= 0x0D) || (bits >= 0x70 && bits <= 0xFF))
        xbld.building = bits;

      // road
      if ((bits >= 0x1D && bits <= 0x2B) || (bits >= 0x3F && bits <= 0x46) || bits == 0x4B || bits == 0x4C || (bits >= 0x51 && bits <= 0x59))
        xbld.road = bits;

      // rail
      if ((bits >= 0x2C && bits <= 0x3E) || (bits >= 0x45 && bits <= 0x48) || (bits >= 0x4D && bits <= 0x4E) || (bits >= 0x5A && bits <= 0x5B) || (bits >= 0x6C && bits <= 0x6F))
        xbld.rail = bits;

      // power
      if ((bits >= 0x0E && bits <= 0x1C) || bits == 0x43 || bits == 0x44 || bits == 0x47 || bits == 0x48 || bits == 0x4F || bits == 0x50 || bits == 0x5C)
        xbld.power = bits;

      // highway
      if ((bits >= 0x49 && bits <= 0x50) || (bits >= 0x5D && bits <= 0x6B))
        xbld.highway = bits;

      struct.tiles[i].XBLD = xbld;
    });
  }


  XTER (data, struct) {
    let view = new Uint8Array(data);

    view.forEach((bits, i) => {
      let xter = {};

      if (bits >= 0x00 && bits <= 0x0D) {
        xter.terrain = bits;
        xter.water = null;
        xter.waterLevel = 'dry';
      }

      if (bits >= 0x10 && bits <= 0x1D) {
        xter.terrain = (bits & 0x0F);
        xter.water = bits;
        xter.waterLevel = 'submerged';
      }

      if (bits >= 0x20 && bits <= 0x2D) {
        xter.terrain = (bits & 0x0F);
        xter.water = bits;
        xter.waterLevel = 'shore';
      }

      if ((bits >= 0x30 && bits < 0x3E) || bits > 0x3E) {
        xter.terrain = (bits & 0x0F);
        xter.water = bits;
        xter.waterLevel = 'surface';
      }

      if (bits == 0x3E) {
        xter.terrain = (bits & 0x0F);
        xter.water = bits;
        xter.waterLevel = 'waterfall';
      }

      xter.water = xterMap[xter.water];
      xter.terrain = xterMap[xter.terrain];

      struct.tiles[i].XTER = xter;
    });
  }
    

  XUND (data, struct) {
    let view = new Uint8Array(data);

    view.forEach((bits, i) => {
      let xund = {};

      // defaults
      xund.subway = 0;
      xund.pipes = 0;
      xund.missileSilo = false;

      // subway
      if ((bits > 0x00 && bits <= 0x0F) || (bits === 0x1F || bits === 0x20) || (bits === 0x23))
        xund.subway = bits;

      // pipes
      if ((bits >= 0x10 && bits <= 0x1E) || (bits === 0x1F || bits === 0x20))
        xund.pipes = bits;

      // missile silo
      if (bits === 0x22)
        xund.missileSilo = true;

      xund.subway = xundMap[xund.subway];
      xund.pipes = xundMap[xund.pipes];

      struct.tiles[i].XUND = xund;
    });
  }


  XZON (data, struct) {
    let view = new Uint8Array(data);

    view.forEach((bits, i) => {
      let xzon = {};

      xzon.topLeft = (bits & 0x80) !== 0;
      xzon.topRight = (bits & 0x10) !== 0;
      xzon.bottomLeft = (bits & 0x40) !== 0;
      xzon.bottomRight = (bits & 0x20) !== 0;
      xzon.zone = bits & 0x0F;

      xzon.zone = xzonMap[xzon.zone];

      struct.tiles[i].XZON = xzon;
    });
  }


  // signs, microsim labels, xthg data / references
  XTXT (data, struct) {
    let view = new Uint8Array(data);

    view.forEach((bits, i) => {
      let txt = {};

      if(bits === 0x00) {
        txt.sign = false;
        txt.microsimLabel = false;
      } else if (bits >= 0x01 && bits <= 0x32) {
        txt.sign = true;
        txt.microsimLabel = false;
        txt.xlabId = bits;
      } else if (bits >= 0x33 && bits <= 0xC9){
        txt.sign = false;
        txt.microsimLabel = true;
        txt.xlabId = bits;
      } else if (bits >= 0xC9) {
        txt.sign = false;
        txt.microsimLabel = false;
        txt.xthgData = bits;
      }

      struct.tiles[i].XTXT = txt;
    });
  }


  // user text / labels / signs
  XLAB (data, struct) {
    // labels (1 byte len + 24 byte string)
    let view = new Uint8Array(data);
    let labels = [];

    for (let i = 0; i < 256; i++) {
      let labelPos = i * 25;
      let labelLength = Math.max(0, Math.min(view[labelPos], 24));
      let labelData = view.subarray(labelPos + 1, labelPos + 1 + labelLength);

      labels[i] = Array.prototype.map.call(labelData, x => String.fromCharCode(x)).join('');
    }

    struct.XLAB = labels;
  }


  // misc data and statistics
  MISC (data, struct) {
    let view = new DataView(data.buffer, data.byteOffset, data.byteLength);
    let misc = {};

    misc.rotation    = view.getUint32(0x0008); // 0 = base, 1 = counter clockwise (CCW), 2 = 2xCCW, 3 = 3xCCW
    misc.yearFounded = view.getUint32(0x000c);
    misc.daysElapsed = view.getUint32(0x0010);
    misc.money       = view.getUint32(0x0014);
    misc.population  = view.getUint32(0x0050);
    misc.zoomLevel   = view.getUint32(0x1014);
    misc.cityCenterX = view.getUint32(0x1018);
    misc.cityCenterY = view.getUint32(0x101c);
    misc.waterLevel  = view.getUint32(0x0E40);

    struct.MISC = misc;
  }
}

export default segmentHandlers;