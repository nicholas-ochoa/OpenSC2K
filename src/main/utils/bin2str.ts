export function bin2str(bin: any, length: number) {
  return bin.toString(2).padStart(length, '0');
}
