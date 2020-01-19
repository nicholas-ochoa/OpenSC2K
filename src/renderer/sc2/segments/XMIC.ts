import { data } from '../data';

export function XMIC(bytes: Buffer) {
  data.segments.XMIC = [];

  for (let i = 0; i < bytes.byteLength; i++) {
    const offset = i * 8;

    if (offset >= bytes.byteLength) {
      break;
    }

    const xmic: any = {};

    xmic.building = bytes.readUInt8(offset);

    if (xmic.building !== 0) {
      xmic.data1 = bytes.readUInt8(offset + 1);
      xmic.data2 = bytes.readUInt16BE(offset + 2);
      xmic.data3 = bytes.readUInt16BE(offset + 4);
      xmic.data4 = bytes.readUInt16BE(offset + 6);
    }

    data.segments.XMIC.push(xmic);
  }
}
