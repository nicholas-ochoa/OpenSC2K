import ReadBytes from '../ReadBytes';

export async function rsrc(bytes: Buffer, section: any, exe: any): Promise<any> {
  const read = new ReadBytes();

  read.buffer = section.data;
  read.endianness = 'little';
  read.log = true;
  read.labelMaxWidth = 25;

  const data: any = table(bytes, section, exe);

  return data;
}

function table(bytes: Buffer, section: any, exe: any, type?: string, offset?: number): any {
  const read = new ReadBytes();

  if (offset) {
    console.log(type, hex(offset));
  }

  read.buffer = !type ? section.data : bytes;
  read.offset = !type ? 0 : offset;
  read.endianness = 'little';
  read.log = true;
  read.labelMaxWidth = 25;

  read.group('resource directory table', false);

  const data: any = {};

  data.characteristics = read.uint32('characteristics');
  data.timeDate = read.uint32('timeDate');
  data.majorVer = read.uint16('majorVer');
  data.minorVer = read.uint16('minorVer');
  data.numberOfNameEntries = read.uint16('numberOfNameEntries');
  data.numberOfIdEntries = read.uint16('numberOfIdEntries');
  data.nodes = [];

  if (data.numberOfNameEntries + data.numberOfIdEntries > 0) {
    for (let i = 0; i < data.numberOfNameEntries + data.numberOfIdEntries; i++) {
      data.nodes[i] = {};

      const result: any = node(bytes, section, exe, type, read.offset);

      data.nodes[i].nodes = result.data;
      read.offset = result.offset;
    }
  }

  read.groupEnd();

  return data;
}

function node(bytes: Buffer, section: any, exe: any, type?: string, offset?: number): any {
  const read = new ReadBytes();

  if (offset) {
    console.log(type, hex(offset));
  }

  read.buffer = !type ? section.data : bytes;
  read.offset = offset;
  read.endianness = 'little';
  read.log = true;
  read.labelMaxWidth = 10;

  const highBit = 0x80000000;
  const baseOffset = exe.dataDirectories.resourceTable.address;

  read.group('node', false);

  const data: any = {};

  data.type = resourceTypes[read.uint32(`type`)];

  if (type) {
    data.type = type;
  }

  data.offset = read.uint32(`offset`);

  if (data.offset < highBit) {
    console.log('entry');
    // data.entry = entry(bytes, type, data.offset);
  } else {
    data.offset = data.offset - highBit + baseOffset;

    const result: any = table(bytes, section, exe, data.type, data.offset);

    data.nodes = result.data;
    //read.offset = result.offset;
  }

  read.groupEnd();

  return { data, offset: read.offset };
}

// function entry(bytes: Buffer, type: string, offset: number): any {
//   const read = new ReadBytes();
//   read.buffer = bytes;
//   read.endianness = 'little';
//   read.log = true;
//   read.labelMaxWidth = 10;
//   read.offset = offset;

//   const highBit = 0x80000000;
//   const baseOffset = exe.dataDirectories.resourceTable.address;

//   read.group('entry', false);

//   const data: any = {};
//   data.dataRva = read.uint32('dataRva');
//   data.size = read.uint32('size');
//   data.type = type;
//   data.codePage = read.uint32('codePage');
//   data.reserved = read.uint32('reserved');

//   read.groupEnd();

//   return data;
// }

function hex(value: number, length: number = 8): string {
  return '0x' + value.toString(16).padStart(length, '0').toLowerCase();
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
