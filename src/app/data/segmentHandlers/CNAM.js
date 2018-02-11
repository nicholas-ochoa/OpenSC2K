export const CNAM = (segment, { cityName }) => {
  const view = new Uint8Array(segment)
  const strDat = view.subarray(1, 1 + (view[0] & 0x3F))

  cityName = Array.prototype.map.call(strDat, x => String.fromCharCode(x)).join(``).replace(/[^\x00-\x7F]/g, ``) //eslint-disable-line
}
