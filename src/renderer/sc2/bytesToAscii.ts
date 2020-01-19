export function bytesToAscii(bytes: Buffer): string {
  return Array.prototype.map.call(bytes, x => String.fromCharCode(x)).join('');
}
