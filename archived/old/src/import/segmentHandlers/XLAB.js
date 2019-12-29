import { bytesToAscii } from './common';

export default (data, map) => {
  let xlab = [];

  for (let i = 0; i < 256; i++) {
    let offset = i * 25;
    let length = data[offset];
    let text = data.subarray(offset + 1, offset + 1 + length);

    xlab[i] = {
      text: bytesToAscii(text),
      offset: offset,
      length: length,
      raw: text,
    };
  }

  map._segmentData.XLAB = xlab;
};