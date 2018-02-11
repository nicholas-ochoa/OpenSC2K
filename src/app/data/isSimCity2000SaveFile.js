export const isSimCity2000SaveFile = bytes => {
  const iff = (bytes[0] !== 0x46 || bytes[1] !== 0x4F || bytes[2] !== 0x52 || bytes[3] !== 0x4D)
  const sc2k = (bytes[8] !== 0x53 || bytes[9] !== 0x43 || bytes[10] !== 0x44 || bytes[11] !== 0x48)
  return (!iff || !sc2k)
}
