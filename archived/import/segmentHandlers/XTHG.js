export default (data, map) => {
  let view = new DataView(data.buffer, data.byteOffset, data.byteLength);

  map._segmentData.XTHG = [];

  for (let i = 0; i < data.byteLength; i++) {
    let offset = i * 12;

    if (offset >= data.byteLength)
      break;

    let xthg = {};

    xthg.id = view.getUint8(offset + 0);
    xthg.type = types[xthg.id];
    xthg.actor = actors[xthg.id];

    xthg.direction = xthg.type == 'actor' ? direction[view.getUint8(offset + 1)] : view.getUint8(offset + 1);

    xthg.x = view.getUint8(offset + 3);
    xthg.y = view.getUint8(offset + 4);
    xthg.z = view.getUint8(offset + 5);

    xthg.data2 = view.getUint8(offset + 2); // identifier? sequence number? type?
    xthg.data7 = view.getUint8(offset + 6);
    xthg.data8 = view.getUint8(offset + 7);
    xthg.data9 = view.getUint8(offset + 8);
    xthg.dataA = view.getUint8(offset + 9);
    xthg.dataB = view.getUint8(offset + 10);
    xthg.dataC = view.getUint8(offset + 11);

    map._segmentData.XTHG.push(xthg);
  }
};

let direction = {
  0x00: 'N',
  0x01: 'NE',
  0x02: 'E',
  0x03: 'SE',
  0x04: 'S',
  0x05: 'SW',
  0x06: 'W',
  0x07: 'NW',
  0x08: 'EIGHT!'
};

let types = {
  0x00: null,
  0x01: 'actor',
  0x02: 'actor',
  0x03: 'actor',
  0x04: null,
  0x05: 'actor',
  0x06: null,
  0x07: 'deploy',
  0x08: 'deploy',
  0x09: 'actor',
  0x0A: 'actor',
  0x0B: 'actor',
  0x0C: null,
  0x0D: null,
  0x0E: 'deploy',
  0x0F: 'actor',
  0x10: 'actor',
};

let actors = {
  0x00: null,
  0x01: 'Airplane',
  0x02: 'Helicopter',
  0x03: 'Cargo Ship',
  0x04: null,
  0x05: 'Monster',
  0x06: null,
  0x07: 'Deploy Police',
  0x08: 'Deploy Fire',
  0x09: 'Sailboat',
  0x0A: 'Train Engine',
  0x0B: 'Train Car',
  0x0C: null,
  0x0D: null,
  0x0E: 'Deploy Military',
  0x0F: 'Tornado',
  0x10: 'Maxis Man',
};