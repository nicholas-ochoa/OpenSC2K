import { bytesToAscii } from './bytesToAscii';
import { decompressSegment } from './decompressSegment';

export function splitSegments(bytes: Buffer) {
  const segments = {};

  while (bytes.length > 0) {
    let contents: Buffer;
    let title = bytesToAscii(bytes.subarray(0x00, 0x04));
    const length = bytes.readUInt32BE(0x04) + 0x08;

    if (!['ALTM', 'CNAM', 'TEXT', 'PICT', 'SCEN', 'TMPL'].includes(title)) {
      contents = decompressSegment(bytes.subarray(0x08, length));
    } else {
      contents = bytes.subarray(0x08, length);
    }

    // there can be more than one TEXT segment
    if (title == 'TEXT') {
      const type = bytes.readUInt8(0x08);

      if (type == 0x80) {
        title = 'TEXT_1';
      } else if (type == 0x81) {
        title = 'TEXT_2';
      }
    }

    segments[title] = contents;
    bytes = bytes.subarray(length);
  }

  return segments;
}
