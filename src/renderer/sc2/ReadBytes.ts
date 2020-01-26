import colors from 'ansi-colors';

type Endianness = 'little' | 'big';

export default class ReadBytes {
  private _offset: number = 0;
  private _bytes: Buffer;
  private _endianness: Endianness = 'little';
  public log: boolean = false;
  public logAsHex: boolean = false;
  public labelMaxWidth: number = 30;

  constructor(bytes?: Buffer, endianness?: Endianness) {
    this._bytes = bytes;
    this._endianness = endianness;
  }

  set buffer(value: Buffer) {
    this._bytes = value;
  }

  get buffer(): Buffer {
    return this._bytes;
  }

  set endianness(value: Endianness) {
    this._endianness = value;
  }

  get endianness(): Endianness {
    return this._endianness;
  }

  set offset(value: number) {
    this._offset = value;
  }

  get offset(): number {
    return this._offset;
  }

  uint8(label?: string) {
    const data: number = this._bytes.readUInt8(this._offset);

    this.logData(1, label, data);
    this._offset += 1;
    return data;
  }

  uint16(label?: string) {
    let data: number;

    if (this._endianness == 'little') {
      data = this._bytes.readUInt16LE(this._offset);
    } else {
      data = this._bytes.readUInt16BE(this._offset);
    }

    this.logData(2, label, data);
    this._offset += 2;
    return data;
  }

  uint32(label?: string) {
    let data: number;

    if (this._endianness == 'little') {
      data = this._bytes.readUInt32LE(this._offset);
    } else {
      data = this._bytes.readUInt32BE(this._offset);
    }

    this.logData(4, label, data);
    this._offset += 4;
    return data;
  }

  int8(label?: string) {
    const data: number = this._bytes.readInt8(this._offset);

    this.logData(1, label, data);
    this._offset += 1;
    return data;
  }

  int16(label?: string) {
    let data: number;

    if (this._endianness == 'little') {
      data = this._bytes.readInt16LE(this._offset);
    } else {
      data = this._bytes.readInt16BE(this._offset);
    }

    this.logData(2, label, data);
    this._offset += 2;
    return data;
  }

  int32(label?: string) {
    let data: number;

    if (this._endianness == 'little') {
      data = this._bytes.readInt32LE(this._offset);
    } else {
      data = this._bytes.readInt32BE(this._offset);
    }

    this.logData(4, label, data);
    this._offset += 4;
    return data;
  }

  text(length: number, label?: string): string {
    const data: string = this._bytes.toString('utf8', this._offset, this._offset + length);

    this.logData(length, label, `"${data}"`);
    this._offset += length;
    return data;
  }

  uint8AtOffset(offset: number, label?: string) {
    const data: number = this._bytes.readUInt8(offset);

    this.logData(1, label, data);
    return data;
  }

  uint16AtOffset(offset: number, label?: string) {
    let data: number;

    if (this._endianness == 'little') {
      data = this._bytes.readUInt16LE(offset);
    } else {
      data = this._bytes.readUInt16BE(offset);
    }

    this.logData(2, label, data);
    return data;
  }

  uint32AtOffset(offset: number, label?: string) {
    let data: number;

    if (this._endianness == 'little') {
      data = this._bytes.readUInt32LE(offset);
    } else {
      data = this._bytes.readUInt32BE(offset);
    }

    this.logData(4, label, data);
    return data;
  }

  int8AtOffset(offset: number, label?: string) {
    const data: number = this._bytes.readInt8(this._offset);

    this.logData(1, label, data);
    this._offset += 1;
    return data;
  }

  int16AtOffset(offset: number, label?: string) {
    let data: number;

    if (this._endianness == 'little') {
      data = this._bytes.readInt16LE(offset);
    } else {
      data = this._bytes.readInt16BE(offset);
    }

    this.logData(2, label, data);
    return data;
  }

  int32AtOffset(offset: number, label?: string) {
    let data: number;

    if (this._endianness == 'little') {
      data = this._bytes.readInt32LE(offset);
    } else {
      data = this._bytes.readInt32BE(offset);
    }

    this.logData(4, label, data);
    return data;
  }

  textAtOffset(offset: number, length: number, label?: string): string {
    const data: string = this._bytes.toString('utf8', offset, offset + length);

    this.logData(length, label, `"${data}"`);
    return data;
  }

  bin(value: number, length: number): string {
    let text: string = value.toString(2).padStart(length * 8, '0').toLowerCase();

    text = colors.blue('0b') + text;

    return text;
  }

  hex(value: number, length: number, padding?: number): string {
    let text: string = value.toString(16).padStart(length, '0').toLowerCase();

    if (padding) {
      text = text.padEnd(padding, ' ');
    }

    text = colors.grey('0x') + text;

    return text;
  }

  logData(length: number, label: string, data: number | string) {
    let text: string;

    if (!this.log) {
      return;
    }

    if (typeof data == 'string') {
      text = colors.whiteBright(data);
    } else {
      text = `${colors.whiteBright(this.hex(data, length, 10))} ${colors.cyanBright(data.toString())}`;
    }

    console.log(`${colors.whiteBright(this.hex(this._offset, 4))} ${colors.yellowBright(`${length}B`)} ${colors.blueBright(label.padStart(this.labelMaxWidth, ' '))}: ${text}`);
  }

  group(label: string, collapsed: boolean = true) {
    if (!this.log) {
      return;
    }

    if (collapsed) {
      console.groupCollapsed(label);
    } else {
      console.group(label);
    }
  }

  groupEnd() {
    if (!this.log) {
      return;
    }

    console.groupEnd();
  }
}
