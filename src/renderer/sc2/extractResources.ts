import fs from 'fs';
import ReadBytes from './ReadBytes';
import sections from './sections';

export async function extractResources(fileName: string): Promise<void> {
  const exeData: any = {};
  const read = new ReadBytes();

  read.buffer = fs.readFileSync(fileName);
  read.endianness = 'little';
  read.log = true;

  read.group('dos stub', true);
  exeData.dosStubMagic = read.uint16('dosStubMagic');
  read.offset = 0x3c;
  exeData.peSignatureOffset = read.uint8('peSignatureOffset');
  read.offset = exeData.peSignatureOffset;
  read.groupEnd();

  read.group('pe header', true);
  exeData.identifier = read.text(4, 'peIdentifier');
  exeData.machineType = read.uint16('peMachineType');
  exeData.numberOfSections = read.uint16('peNumberOfSections');
  exeData.timeDateStamp = read.uint32('timeDateStamp');
  exeData.pointerToSymbolTable = read.uint32('pointerToSymbolTable');
  exeData.numberOfSymbols = read.uint32('numberOfSymbols');
  exeData.sizeOfOptionalHeader = read.uint16('sizeOfOptionalHeader');
  exeData.characteristics = read.uint16('characteristics');
  read.groupEnd();

  read.group('pe optional header', true);
  exeData.magic = read.uint16('magic');
  exeData.majorLinkerVer = read.uint8('majorLinkerVer');
  exeData.minorLinkerVer = read.uint8('minorLinkerVer');
  exeData.sizeOfCode = read.uint32('sizeOfCode');
  exeData.sizeOfInitializedData = read.uint32('sizeOfInitializedData');
  exeData.sizeOfUnInitializedData = read.uint32('sizeOfUnInitializedData');
  exeData.addressOfEntryPoint = read.uint32('addressOfEntryPoint');
  exeData.baseOfCode = read.uint32('baseOfCode');
  exeData.baseOfData = read.uint32('baseOfData');
  exeData.imageBase = read.uint32('imageBase');
  exeData.sectionAlignment = read.uint32('sectionAlignment');
  exeData.fileAlignment = read.uint32('fileAlignment');
  exeData.majorOpSysVer = read.uint16('majorOpSysVer');
  exeData.minOpSysVer = read.uint16('minOpSysVer');
  exeData.majorImgVer = read.uint16('majorImgVer');
  exeData.minorImgVer = read.uint16('minorImgVer');
  exeData.majorSubsysVer = read.uint16('majorSubsysVer');
  exeData.minorSubsysVer = read.uint16('minorSubsysVer');
  exeData.win32Ver = read.uint32('win32Ver');
  exeData.sizeOfImage = read.uint32('sizeOfImage');
  exeData.sizeOfHeaders = read.uint32('sizeOfHeaders');
  exeData.checksum = read.uint32('checksum');
  exeData.subSystem = read.uint16('subSystem');
  exeData.dllCharacteristics = read.uint16('dllCharacteristics');
  exeData.sizeOfStackReserve = read.uint32('sizeOfStackReserve');
  exeData.sizeOfStackCommit = read.uint32('sizeOfStackCommit');
  exeData.sizeOfHeapReserve = read.uint32('sizeOfHeapReserve');
  exeData.sizeOfHeapCommit = read.uint32('sizeOfHeapCommit');
  exeData.loaderFlags = read.uint32('loaderFlags');
  exeData.numberOfRvaAndSizes = read.uint32('numberOfRvaAndSizes');
  exeData.exportTableAddress = read.uint32('exportTableAddress');
  exeData.exportTableSize = read.uint32('exportTableSize');
  exeData.importTableAddress = read.uint32('importTableAddress');
  exeData.importTableSize = read.uint32('importTableSize');
  exeData.resourceTableAddress = read.uint32('resourceTableAddress');
  exeData.resourceTableSize = read.uint32('resourceTableSize');
  exeData.exceptionTableAddress = read.uint32('exceptionTableAddress');
  exeData.exceptionTableSize = read.uint32('exceptionTableSize');
  exeData.certTableAddress = read.uint32('certTableAddress');
  exeData.certTableSize = read.uint32('certTableSize');
  exeData.baseRelocTableAddress = read.uint32('baseRelocTableAddress');
  exeData.baseRelocTableSize = read.uint32('baseRelocTableSize');
  exeData.debugAddress = read.uint32('debugAddress');
  exeData.debugSize = read.uint32('debugSize');
  exeData.archAddress = read.uint32('archAddress');
  exeData.archSize = read.uint32('archSize');
  exeData.globalPtrAddress = read.uint32('globalPtrAddress');
  exeData.globalPtrSize = read.uint32('globalPtrSize');
  exeData.tlsTableAddress = read.uint32('tlsTableAddress');
  exeData.tlsTableSize = read.uint32('tlsTableSize');
  exeData.loadConfigTableAddress = read.uint32('loadConfigTableAddress');
  exeData.loadConfigTableSize = read.uint32('loadConfigTableSize');
  exeData.boundImportAddress = read.uint32('boundImportAddress');
  exeData.boundImportSize = read.uint32('boundImportSize');
  exeData.iatAddress = read.uint32('iatAddress');
  exeData.iatSize = read.uint32('iatSize');
  exeData.delayImportEscAddress = read.uint32('delayImportEscAddress');
  exeData.delayImportEscSize = read.uint32('delayImportEscSize');
  exeData.clsRuntimeHeaerAddress = read.uint32('clsRuntimeHeaerAddress');
  exeData.clsRuntimeHeaerSize = read.uint32('clsRuntimeHeaerSize');
  exeData.reservedAddress = read.uint32('reservedAddress');
  exeData.reservedSize = read.uint32('reservedSize');
  read.groupEnd();

  read.group('section table', false);
  exeData.sections = {};

  read.log = true;

  for (let i = 0; i < exeData.numberOfSections; i++) {
    read.group(`section header: ${i}`, false);
    const name = read.text(8, `${i} name`).replace(/(\u0000|\.)/g, '');

    exeData.sections[name] = {};
    exeData.sections[name].name = name;
    exeData.sections[name].virtualSize = read.uint32(`${i} virtualSize`);
    exeData.sections[name].virtualAddress = read.uint32(`${i} virtualAddress`);
    exeData.sections[name].sizeOfRawData = read.uint32(`${i} sizeOfRawData`);
    exeData.sections[name].pointerToRawData = read.uint32(`${i} pointerToRawData`);
    exeData.sections[name].pointerToRelocations = read.uint32(`${i} pointerToRelocations`);
    exeData.sections[name].pointerToLineNumbers = read.uint32(`${i} pointerToLineNumbers`);
    exeData.sections[name].numberOfRelocations = read.uint16(`${i} numberOfRelocations`);
    exeData.sections[name].numberOfLineNumbers = read.uint16(`${i} numberOfLineNumbers`);
    exeData.sections[name].characteristics = read.uint32(`${i} characteristics`);

    const start: number = exeData.sections[name].pointerToRawData;
    const end: number = exeData.sections[name].pointerToRawData + exeData.sections[name].sizeOfRawData;
    exeData.sections[name].data = read.buffer.subarray(start, end);

    if (sections[name]) {
      exeData.sections[name].parsedData = await sections[name](exeData.sections[name].data, exeData.resourceTableAddress);
    }

    // if (name == 'rsrc') {
      // console.log(exeData.sections[name].data);
      // console.log(exeData.sections[name].parsedData);
    // }

    read.groupEnd();
  }

  read.groupEnd();
}


