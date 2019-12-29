import { palette } from './palette';

// translate palette index into rgb color
export function getColor(idx: number, frame: number): any {
  if (idx === -1) {
    return {
      r: 0,
      g: 0,
      b: 0,
      a: 0,
    };
  }

  return palette[idx][frame];
}
