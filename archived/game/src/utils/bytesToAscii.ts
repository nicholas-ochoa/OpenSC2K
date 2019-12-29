export function bytesToAscii(bytes: any): string {
  return Array.prototype.map.call(bytes, x => String.fromCharCode(x)).join('');
}
