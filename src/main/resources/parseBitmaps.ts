import fs from 'fs';
import path from 'path';
import config from 'config';
import ReadBytes from 'common/ReadBytes';

export async function parseBitmaps(data: any) {
  const sc2kexe: string = config.get('paths.import.sc2k95se');
  const bmpPath: string = config.get('paths.images');

  const read = new ReadBytes();

  read.buffer = fs.readFileSync(sc2kexe);
  read.endianness = 'little';
  read.log = true;

  for (const entry of data.list) {
    read.offset = entry.offset;

    const bmpRead = new ReadBytes();
    bmpRead.buffer = read.slice(entry.size);
    bmpRead.endianness = 'little';
    bmpRead.log = true;

    bmpRead.group(`bmpRead ${entry.name}`);

    const header: any = {
      imageStart: bmpRead.uint32('bmpStartOffset'),
      width: bmpRead.uint32('width'),
      height: bmpRead.uint32('height'),
      plates: bmpRead.uint16('planes'),
      bitPP: bmpRead.uint16('bitPP'),
      compression: bmpRead.uint32('compression'),
      imageSize: bmpRead.uint32('imageSize'),
      xPixelsPerMeter: bmpRead.uint32('xPixelsPerMeter'),
      yPixelsPerMeter: bmpRead.uint32('yPixelsPerMeter'),
      colorsInColorTable: bmpRead.uint32('colorsInColorTable'),
      importantColorCount: bmpRead.uint32('importantColorCount'),
    };

    const rasterStart = 14 + bmpRead.buffer.length - header.imageSize;

    // create bmp header
    const bmpData = Buffer.alloc(14 + bmpRead.buffer.length);
    bmpData.write('BM', 0x00);
    bmpData.writeUInt32LE(14 + bmpRead.buffer.length, 0x02);
    bmpData.writeUInt32LE(0x00000000, 0x06);
    bmpData.writeUInt32LE(rasterStart, 0x0a);

    // append bmp data to the header
    bmpRead.buffer.copy(bmpData, 0x0e);

    const filePath: string = path.join(bmpPath, `${entry.name}.bmp`);

    fs.writeFileSync(filePath, bmpData);

    bmpRead.groupEnd();
  }
}
