import { data } from '../data';

export function XBIT(bytes: Buffer) {
  bytes.forEach((bits, i) => {
    const xbit: any = {};

    // can this tile receive power?
    xbit.wired = (bits & 0b10000000) !== 0;

    // does this tile have power?
    xbit.powered = (bits & 0b01000000) !== 0;

    // can this tile receive piped water?
    xbit.piped = (bits & 0b00100000) !== 0;

    // does this tile have piped water?
    xbit.watered = (bits & 0b00010000) !== 0;

    // land value mask
    xbit.xvalMask = (bits & 0b00001000) !== 0;

    // is this tile covered by water?
    xbit.waterCovered = (bits & 0b00000100) !== 0;

    // rotate tile by 90 degrees?
    xbit.rotate = (bits & 0b00000010) !== 0;

    // is tile salt water or fresh water?
    xbit.saltWater = (bits & 0b00000001) !== 0;

    data.cells[i].segments.XBIT = xbit;
  });
}
