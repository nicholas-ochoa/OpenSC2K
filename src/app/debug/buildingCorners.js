import { colors } from "@/app/constants"
import game from "@/app/game"
import graphics, { getTile } from "@/app/graphics"
import { selectionBox } from "@/app/ui"
import debug from "./"

export const buildingCorners = ({ x, y, corners: cellCorners, coordinates: { center }, tiles: { building } }) => {
  if (!debug.showBuildingCorners || !building) return
  const { size } = getTile(building)
  if (size === `1x1`) return

  let line = colors.blue50
  let fill = colors.blue10
  let textStyle = colors.white75
  let tileType

  if (cellCorners === game.corners[0]) {
    tileType = `C0 TR`
  } else if (cellCorners === game.corners[1]) {
    tileType = `C1 BL`
  } else if (cellCorners === game.corners[2]) {
    tileType = `C2 BR`
  } else if (cellCorners === game.corners[3]) {
    tileType = `C3 TL`
  } else {
    line = colors.grey60
    fill = colors.grey40
    textStyle = colors.black0
    tileType = ``
  }

  if (cellCorners === game.corners[game.mapRotation]) {
    line = colors.red90
    fill = colors.red25
    tileType = `${tileType} K`
  }

  graphics.interfaceContext.font = `8px Verdana`
  graphics.interfaceContext.fillStyle = textStyle
  graphics.interfaceContext.fillText(tileType, center.x - 16, center.y + 3)
  selectionBox(x, y, line, 2, fill)
}
