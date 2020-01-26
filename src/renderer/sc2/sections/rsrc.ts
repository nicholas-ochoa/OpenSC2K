import ReadBytes from '../ReadBytes';

export async function rsrc(bytes: Buffer, offset: number): Promise<any> {
  const data: any = {};
  const read = new ReadBytes();

  read.buffer = bytes;
  read.endianness = 'little';
  read.log = true;

  read.group('resource directory header', false);
  data.characteristics = read.uint32('characteristics');
  data.timeDate = read.uint32('timeDate');
  data.majorVer = read.uint16('majorVer');
  data.minorVer = read.uint16('minorVer');
  data.numberOfNameEntries = read.uint16('numberOfNameEntries');
  data.numberOfIdEntries = read.uint16('numberOfIdEntries');
  read.groupEnd();

  read.group('resource directory entries', false);
  const entries: number = data.numberOfNameEntries + data.numberOfIdEntries;
  data.entries = [];

  for (let i = 0; i < entries; i++) {
    read.group(`entry ${i}`, false);
    data.entries[i] = {};
    data.entries[i].nameOffset = read.uint32(`${i} nameOffset`);
    data.entries[i].resourceType = resourceTypes[data.entries[i].nameOffset];
    console.log(data.entries[i].resourceType);
    data.entries[i].integerId = read.uint32(`${i} integerId`);
    data.entries[i].dataEntryOffset = read.uint32(`${i} dataEntryOffset`);
    data.entries[i].subdirOffset = read.uint32(`${i} subdirOffset`) << 1 >> 1;
    read.groupEnd();
  }

  read.groupEnd();

  return data;
}

const resourceTypes = {
  0x01: 'RT_CURSOR',
  0x02: 'RT_BITMAP',
  0x03: 'RT_ICON',
  0x04: 'RT_MENU',
  0x05: 'RT_DIALOG',
  0x06: 'RT_STRING',
  0x07: 'RT_FONTDIR',
  0x08: 'RT_FONT',
  0x09: 'RT_ACCELERATOR',
  0x0a: 'RT_RCDATA',
  0x0b: 'RT_MESSAGETABLE',
  0x0c: 'RT_GROUP_CURSOR',
  0x0e: 'RT_GROUP_ICON',
  0x10: 'RT_VERSION',
  0x11: 'RT_DLGINCLUDE',
  0x13: 'RT_PLUGPLAY',
  0x14: 'RT_VXD',
  0x15: 'RT_ANICURSOR',
  0x16: 'RT_ANIICON',
  0x17: 'RT_HTML',
  0x18: 'RT_MANIFEST',
  0xf0: 'RT_DLGINIT',
};
