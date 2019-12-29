export function wrap(value: number, min: number, max: number): number {
  if (value > max) {
    value = min;
  }

  if (value < min) {
    value = max;
  }

  return value;
}
