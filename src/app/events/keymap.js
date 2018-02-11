import { clear, openFile } from "@/app/data"
import debug, { toggleClipBoundDebug } from "@/app/debug"
import { rotateMap } from "@/app/game"
import { moveCamera } from "@/app/ui"
import events from "./"

export const keymap = {
  1: key => {
    events.activeCursorTool = `none`
    debug.showSelectedTileInfo = false
    if (debug.logEvents) info(`Key Event: '${key}' - Set Active Cursor Tool to: ${events.activeCursorTool}`)
  },
  2: key => {
    events.activeCursorTool = `center`
    debug.showSelectedTileInfo = true
    if (debug.logEvents) info(`Key Event: '${key}' - Set Active Cursor Tool to: ${events.activeCursorTool}`)
  },
  3: key => {
    events.activeCursorTool = `info`
    debug.showSelectedTileInfo = true
    if (debug.logEvents) info(`Key Event: '${key}' - Set Active Cursor Tool to: ${events.activeCursorTool}`)
  },
  a: key => {
    debug.hideAnimatedTiles = !debug.hideAnimatedTiles
    if (debug.logEvents) log(`Key Event: '${key}' - Toggle Hide Animated Tiles: ${debug.hideAnimatedTiles}`)
  },
  z: key => {
    debug.showBuildingCorners = !debug.showBuildingCorners
    if (debug.logEvents) info(`Key Event: '${key}' - Toggle Show Building Corners: ${debug.showBuildingCorners}`)
  },
  c: key => {
    debug.showTileCoordinates = !debug.showTileCoordinates
    if (debug.logEvents) info(`Key Event: '${key}' - Toggle Show Tile Coordinates: ${debug.showTileCoordinates}`)
  },
  i: key => {
    debug.showTileCount = !debug.showTileCount
    if (debug.logEvents) info(`Key Event: '${key}' - Toggle Show Tile Count: ${debug.showTileCount}`)
  },
  x: key => {
    debug.hideTerrain = !debug.hideTerrain
    if (debug.logEvents) info(`Key Event: '${key}' - Toggle Hide Terrain: ${debug.hideTerrain}`)
  },
  v: key => {
    debug.hideZones = !debug.hideZones
    if (debug.logEvents) info(`Key Event: '${key}' - Toggle Hide Zones: ${debug.hideZones}`)
  },
  y: key => {
    debug.hideNetworks = !debug.hideNetworks
    if (debug.logEvents) info(`Key Event: '${key}' - Toggle Hide Networks: ${debug.hideNetworks}`)
  },
  b: key => {
    debug.hideBuildings = !debug.hideBuildings
    if (debug.logEvents) info(`Key Event: '${key}' - Toggle Hide Buildings: ${debug.hideBuildings}`)
  },
  n: key => {
    debug.hideWater = !debug.hideWater
    if (debug.logEvents) info(`Key Event: '${key}' - Toggle Hide Water: ${debug.hideWater}`)
  },
  m: key => {
    debug.hideTerrainEdge = !debug.hideTerrainEdge
    if (debug.logEvents) info(`Key Event: '${key}' - Toggle Hide Terrain Edge: ${debug.hideTerrainEdge}`)
  },
  h: key => {
    debug.showHeightMap = !debug.showHeightMap
    if (debug.showHeightMap) {
      debug.hideTerrain = true
      debug.hideZones = true
      debug.hideBuildings = true
      debug.hideNetworks = true
      debug.hideWater = true
      debug.hideTerrainEdge = true
    } else {
      debug.hideTerrain = false
      debug.hideZones = false
      debug.hideBuildings = false
      debug.hideNetworks = false
      debug.hideWater = false
      debug.hideTerrainEdge = false
    }
    if (debug.logEvents) info(`Key Event: '${key}' - Toggle Show Height Map: ${debug.showHeightMap}`)
  },
  k: key => {
    debug.showZoneOverlay = !debug.showZoneOverlay
    if (debug.logEvents) info(`Key Event: '${key}' - Toggle Show Zone Overlay: ${debug.showZoneOverlay}`)
  },
  j: key => {
    debug.showNetworkOverlay = !debug.showNetworkOverlay
    if (debug.logEvents) info(`Key Event: '${key}' - Toggle Show Network Overlay: ${debug.showNetworkOverlay}`)
  },
  q: key => {
    rotateMap(`left`)
    if (debug.logEvents) info(`Key Event: '${key}' - Rotate Map Left`)
  },
  w: key => {
    rotateMap(`right`)
    if (debug.logEvents) info(`Key Event: '${key}' - Rotate Map Right`)
  },
  t: key => {
    toggleClipBoundDebug()
    if (debug.logEvents) info(`Key Event: '${key}' - Toggle Clip Bound Debug`)
  },
  o: key => {
    if (debug.logEvents) info(`Key Event: '${key}' - Open File`)
    openFile()
  },
  0: key => {
    if (debug.logEvents) info(`Key Event: '${key}' - Reset Game`)
    clear()
    window.location.reload()
  },
  F5: key => window.location.reload(),
  ArrowUp: key => {
    moveCamera(`up`)
    if (debug.logEvents) info(`Key Event: '${key}' - Move Camera Up`)
  },
  ArrowRight: key => {
    moveCamera(`right`)
    if (debug.logEvents) info(`Key Event: '${key}' - Move Camera Right`)
  },
  ArrowDown: key => {
    moveCamera(`down`)
    if (debug.logEvents) info(`Key Event: '${key}' - Move Camera Down`)
  },
  ArrowLeft: key => {
    moveCamera(`left`)
    if (debug.logEvents) info(`Key Event: '${key}' - Move Camera Left`)
  }
}
