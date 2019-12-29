import constants from './constants';
import { parseRow } from './parseRow';

// processes image bytes into individual image data rows / chunks
export function parseBlock(header: any) {
  const block: any = [];
  let offset: number = 0x00;

  while (offset <= header.size) {
    const length: number = header.data.getUint8(offset);
    const more: number = header.data.getUint8(offset + 0x01);

    offset += 0x02;

    const data: any = header.data.buffer.slice(offset, offset + length);
    const pixels: any = parseRow(data);

    block.push({
      length,
      pixels,
    });

    // check "more" flag
    if (more == constants.LAST_LINE) {
      break;
    }

    offset += length;
  }

  return block;
}
