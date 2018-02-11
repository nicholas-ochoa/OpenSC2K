import { colors } from "@/app/constants"
import game, { getMapCell } from "@/app/game"
import graphics, { drawPoly, flipTile, getTile } from "@/app/graphics"
import ui from "@/app/ui"
import debug from "./"

export const showTileInfo = () => {
  if (!debug.showSelectedTileInfo) return
  const cell = getMapCell(ui.cursorTileX, ui.cursorTileY)
  if (!cell) return
  const {
    x,
    y,
    z,
    corners,
    rotate,
    original_x: originalX,
    original_y: originalY,
    tiles: { terrain, building, zone },
    water_level: waterLevel
  } = cell

  // draw text
  let textData = []

  // todo: this should be moved to a function for drawing text?
  textData.push(`Cell Position:`)
  textData.push(`Current X: ${x}, Y: ${y}, Z: ${z}`)
  textData.push(`Original X: ${originalX}, Y: ${originalY}`)
  textData.push(``)

  if (terrain > 0) {
    const { id, slopes, frames } = getTile(terrain)

    textData.push(`Terrain: ${terrain} (R${game.mapRotation}: ${id})`)
    textData.push(`  Slopes: ${slopes}`)
    textData.push(`  Frames: ${frames}`)
    textData.push(`  Water Level: ${waterLevel}`)
    textData.push(``)
  }

  if (building > 0) {
    const tile = getTile(building)
    const {
      id,
      description,
      size,
      frames,
      flip_h: flipH,
      flip_alt_tile: flipAltTile
    } = tile

    textData.push(`Building: ${building} (R${game.mapRotation}: ${id})`)
    textData.push(`  Name: ${description}`)
    textData.push(`  Lot Size: ${size}`)
    textData.push(`  Frames: ${frames}`)
    textData.push(`  Corners: ${corners} / ${game.corners[game.mapRotation]}`)
    textData.push(`  Key Tile: ${(corners === game.corners[game.mapRotation] ? `Y` : `N`)}`)
    textData.push(`  Transforms:`)
    textData.push(`    Tile Flip: ${flipH}`)
    textData.push(`    Alt Flip Tile: ${flipAltTile}`)
    textData.push(`    Cell Rotate: ${rotate}`)
    textData.push(`    Display Mirrored: ${(flipTile(tile, cell) ? `Y` : `N`)}`)
    textData.push(``)
  }

  if (zone > 0) {
    const { id, name, description } = getTile(zone)

    textData.push(`Zone: ${zone} (R${game.mapRotation}: ${id})`)
    textData.push(`  Type: ${name}`)
    textData.push(`  Description: ${description}`)
    textData.push(``)
  }

  // draw background
  const height = 20 + (textData.length * 15)
  const width = 220
  drawPoly([
    { x: 0, y: 0 },
    { x: width, y: 0 },
    { x: width, y: height },
    { x: 0, y: height },
    { x: 0, y: 0 }
  ], colors.black50, colors.white75, ui.cursorX + 10, ui.cursorY + 10)

  let lineX = ui.cursorX + 20
  let lineY = ui.cursorY + 25
  graphics.interfaceContext.font = `10px Verdana`
  graphics.interfaceContext.fillStyle = colors.white90

  for (const line of textData) {
    graphics.interfaceContext.fillText(line, lineX, lineY)
    lineY += 15
  }
}
