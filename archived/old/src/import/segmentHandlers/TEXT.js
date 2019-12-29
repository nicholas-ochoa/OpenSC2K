import { bytesToAscii } from './common';

export default (data, map) => {
  let text = {};

  text.text = bytesToAscii(data.subarray(4)).replace(/[\r]/g, ' ');
  text.raw = data;

  map._segmentData.TEXT = text;
};