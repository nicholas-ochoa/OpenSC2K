import { bytesToAscii } from 'utils';
import { decompressSegment } from './decompressSegment';

export function splitSegments(bytes) {
  const segments = {};

  while (bytes.length > 0) {
    let title = bytesToAscii(bytes.subarray(0x00, 0x04));
    const length = new DataView(bytes.subarray(0x04, 0x08).buffer).getUint32(bytes.subarray(0x04, 0x08).byteOffset);
    let contents = bytes.subarray(0x08, 0x08 + length);

    if (!['ALTM', 'CNAM', 'TEXT', 'PICT', 'SCEN', 'TMPL'].includes(title)) {
      contents = decompressSegment(contents);
    }

    // can have multilpe TEXT segments
    if (title == 'TEXT') {
      const type = bytes.subarray(0x08, 0x09);

      if (type == 0x80) {
        title = 'TEXT_1';
      } else if (type == 0x81) {
        title = 'TEXT_2';
      }
    }

    segments[title] = contents;
    bytes = bytes.subarray(0x08 + length);
  }

  return segments;
}
