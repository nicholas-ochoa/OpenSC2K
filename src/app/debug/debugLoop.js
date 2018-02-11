import debug, { drawClipBounds, debugOverlay, showTileInfo, showFrameStats } from "./"

export const debugLoop = () => {
  if (!debug.enabled) return
  drawClipBounds()
  debugOverlay()
  showTileInfo()
  showFrameStats()
}
