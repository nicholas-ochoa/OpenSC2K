import debug, { buildingCorners, networkOverlay } from "./"

export const debugBuilding = cell => {
  if (!debug.enabled) return

  buildingCorners(cell)
  networkOverlay(cell)
}
