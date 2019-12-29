import constants from './constants';

// process image rows / chunks
export function parseRow(buffer: ArrayBuffer) {
  const data: DataView = new DataView(buffer);
  const pixels: number[] = [];
  let offset: number = 0x00;

  if (data.byteLength == 0x00) {
    return pixels;
  }

  // loop through the row chunks
  while (offset < data.buffer.byteLength - 0x01) {
    const count: number = data.getUint8(offset + 0x00);
    let pixelData: DataView;
    let extra: number;
    let padding: number;
    let length: number;
    let header: number;

    // special case for multi-chunk rows, drop first byte if zero
    if (count == 0x00 && offset > 0x00) {
      offset++;
    }

    const mode: number = data.getUint8(offset + 0x01);

    if (mode == constants.MODE_00 || mode == constants.MODE_03) {
      padding = data.getUint8(offset + 0x00); // padding pixels from the left edge
      length = data.getUint8(offset + 0x02); // pixels in the row to draw
      extra = data.getUint8(offset + 0x03); // extra bit / flag

      if (length == 0x00 && extra == 0x00) {
        header = 0x06;
        length = data.getUint8(offset + 0x04);
        extra = data.getUint8(offset + 0x05);
        pixelData = new DataView(data.buffer.slice(offset + header, offset + header + length));
      } else {
        header = 0x04;
        pixelData = new DataView(data.buffer.slice(offset + header, offset + header + length));
      }
    } else if (mode == constants.MODE_04) {
      header = 0x02;
      length = data.getUint8(offset + 0x00);
      pixelData = new DataView(data.buffer.slice(offset + header, offset + header + length));
    } else {
      return pixels;
    }

    // byte offset for the next loop
    offset += header + length;

    // save padding pixels (transparent) as -1
    for (let i = 0; i < padding; i++) {
      pixels.push(-1);
    }

    // save pixel data afterwards
    if (pixelData) {
      for (let i = 0; i < pixelData.buffer.byteLength; i++) {
        pixels.push(pixelData.getUint8(i));
      }
    }
  }

  // let out: string = '';

  // for (let i = 0; i < pixels.length; i++) {
  //   if (pixels[i] == -1) {
  //     out += ' ';
  //   } else {
  //     out += 'X';
  //   }
  // }

  // console.log(out);

  return pixels;
}
