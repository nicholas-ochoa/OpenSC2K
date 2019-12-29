// returns the number of frames in the animation sequence for a given palette index
// defaults to 1 if no sequence is found
export function getFrameCount(idx: number): number {
  if (idx >= 200 && idx <= 211) {
    return 12;
  }

  if ((idx >= 171 && idx <= 194) || (idx >= 212 && idx <= 219)) {
    return 8;
  }

  if ((idx >= 195 && idx <= 198) || (idx >= 220 && idx <= 231)) {
    return 4;
  }

  return 1;
}
