import fs from 'fs';
import { PNG } from 'pngjs';

function create(width: number, height: number): any {
  return new PNG({
    width,
    height,
    filterType: -1,
    inputHasAlpha: true,
  });
}

function setPixel(image: any, x: number, y: number, r: number | any, g?: number, b?: number, a?: number): void {
  const color: any = {
    r: 0,
    g: 0,
    b: 0,
    a: 255,
  };

  if (typeof r === 'object') {
    color.r = r.r;
    color.g = r.g;
    color.b = r.b;
    color.a = r.a;
  }

  const width: number = image.width;
  const idx: number = (width * y + x) << 2;

  image.data[idx + 0] = color.r;
  image.data[idx + 1] = color.g;
  image.data[idx + 2] = color.b;
  image.data[idx + 3] = color.a;
}

function save(image: any, filename: string): void {
  image.pack().pipe(fs.createWriteStream(filename));
}

export default { create, setPixel, save };

export { create, setPixel, save };
