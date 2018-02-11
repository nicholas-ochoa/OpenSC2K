export const ALTM = ({ buffer, byteOffset, byteLength }, { tiles }) => {
  const view = new DataView(buffer, byteOffset, byteLength)

  // read two bytes every loop
  for (let i = 0; i < byteLength / 2; i++) {
    const square = view.getUint16(i * 2)
    tiles[i].ALTM = {}
    tiles[i].ALTM.tunnelLevels = (square & 0xFF00) // bytes 0..7
    tiles[i].ALTM.waterFlag = (square & 0x0080) !== 0 // bytes 8, bool
    tiles[i].ALTM.globalWaterLevel = (square & 0x0060) // bytes 9..10
    tiles[i].ALTM.altitude = (square & 0x001F) // bytes 11..15
    //tiles[i].ALTM.raw = binaryString(square, 2) // save binary flags as string
  }
}
