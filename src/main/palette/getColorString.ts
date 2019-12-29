import { palette } from './palette';

// translate palette index into rgb color
export function getColorString(idx: number, frame: number): string {
  if (idx === -1) {
    return '0,0,0,0';
  }

  const { r, g, b, a }: any = palette[idx][frame];

  return `${r},${g},${b},${a}`;
}
