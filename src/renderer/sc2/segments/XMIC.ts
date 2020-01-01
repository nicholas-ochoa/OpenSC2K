import { data } from '../data';

export function XMIC(bytes: any) {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);

  data.segments.XMIC = [];

  for (let i = 0; i < bytes.byteLength; i++) {
    const offset = i * 8;

    if (offset >= bytes.byteLength) {
      break;
    }

    const xmic: any = {};

    xmic.building = view.getUint8(offset);

    xmic.data1 = xmic.building == 0 ? 0 : view.getUint8(offset + 1);
    xmic.data2 = xmic.building == 0 ? 0 : view.getUint16(offset + 2);
    xmic.data3 = xmic.building == 0 ? 0 : view.getUint16(offset + 4);
    xmic.data4 = xmic.building == 0 ? 0 : view.getUint16(offset + 6);

    data.segments.XMIC.push(xmic);
  }
}
