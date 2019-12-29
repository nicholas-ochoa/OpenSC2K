export function isAnimatedIndex(idx: number): boolean {
  if ((idx >= 171 && idx <= 198) || (idx >= 200 && idx <= 219) || (idx >= 224 && idx <= 231)) {
    return true;
  } else {
    return false;
  }
}
