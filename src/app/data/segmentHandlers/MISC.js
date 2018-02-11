export const MISC = ({ buffer, byteOffset, byteLength }, struct) => {
  const view = new DataView(buffer, byteOffset, byteLength)
  struct.MISC = {
    rotation: view.getUint32(0x0008), // 0 = base, 1 = counter clockwise (CCW), 2 = 2xCCW, 3 = 3xCCW
    yearFounded: view.getUint32(0x000c),
    daysElapsed: view.getUint32(0x0010),
    money: view.getUint32(0x0014),
    population: view.getUint32(0x0050),
    zoomLevel: view.getUint32(0x1014),
    cityCenterX: view.getUint32(0x1018),
    cityCenterY: view.getUint32(0x101c),
    waterLevel: view.getUint32(0x0E40)
  }
}
