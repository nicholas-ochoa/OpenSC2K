import { data } from '../data';

export function XTHG(bytes: Buffer) {
  data.segments.XTHG = [];

  for (let i = 0; i < bytes.byteLength; i++) {
    const offset = i * 12;

    if (offset >= bytes.byteLength) break;

    const xthg: any = {};

    xthg.id = bytes.readUInt8(offset + 0);
    xthg.type = types[xthg.id];
    xthg.actor = actors[xthg.id];

    if (xthg.type == 'actor') {
      xthg.direction = direction[bytes.readUInt8(offset + 1)];
    } else {
      xthg.direction = bytes.readUInt8(offset + 1);
    }

    xthg.x = bytes.readUInt8(offset + 3);
    xthg.y = bytes.readUInt8(offset + 4);
    xthg.z = bytes.readUInt8(offset + 5);

    xthg.data2 = bytes.readUInt8(offset + 2); // identifier? sequence number? type?
    xthg.data7 = bytes.readUInt8(offset + 6);
    xthg.data8 = bytes.readUInt8(offset + 7);
    xthg.data9 = bytes.readUInt8(offset + 8);
    xthg.dataA = bytes.readUInt8(offset + 9);
    xthg.dataB = bytes.readUInt8(offset + 10);
    xthg.dataC = bytes.readUInt8(offset + 11);

    data.segments.XTHG.push(xthg);
  }
}

const direction = {
  0x00: 'N',
  0x01: 'NE',
  0x02: 'E',
  0x03: 'SE',
  0x04: 'S',
  0x05: 'SW',
  0x06: 'W',
  0x07: 'NW',
};

const types = {
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
  0x0a: 'actor',
  0x0b: 'actor',
  0x0c: null,
  0x0d: null,
  0x0e: 'deploy',
  0x0f: 'actor',
  0x10: 'actor',
};

const actors = {
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
  0x0a: 'Train Engine',
  0x0b: 'Train Car',
  0x0c: null,
  0x0d: null,
  0x0e: 'Deploy Military',
  0x0f: 'Tornado',
  0x10: 'Maxis Man',
};
