import { data } from '../data';

export function ALTM(bytes: Buffer) {
  for (let i = 0; i < bytes.length / 2; i++) {
    const bits: number = bytes.readUInt16BE(i * 2);
    const altm: any = {};

    // how many levels below altitude should we display a grey
    // block for a tunnel?
    altm.tunnelLevels = ((bits >> 8) & 0b11111100) >> 2;

    // related to tunnel? appears to be set to 1 for
    // hydroelectric dams and nearby surface water tiles
    altm.unknownBits = ((bits >> 8) & 0b00000011);

    // level / altitude
    altm.altitude = bits & 0b0000000000011111;

    // not always accurate (rely on XTER value instead)
    altm.waterLevel = (bits & 0b0000000001100000) >> 5;

    // not always accurate (rely on XTER value instead)
    altm.waterCovered = (bits & 0b0000000010000000) >> 7;

    data.cells[i].segments.ALTM = altm;
  }
}
