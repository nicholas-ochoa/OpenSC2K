import { bytesToAscii } from './common';

export default (data, map) => {
  let text = data.subarray(1, data.indexOf(0));

  map._segmentData.CNAM = {
    text: bytesToAscii(text),
    data: data,
    raw: text,
  };
};