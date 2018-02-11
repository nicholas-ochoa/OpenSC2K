import debug, { heightMap, cellCoordinates } from "./"

export const debugTerrain = cell => {
  if (!debug.enabled) return

  heightMap(cell)
  cellCoordinates(cell)
}
