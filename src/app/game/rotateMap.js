import data from "@/app/data"
import { getTile, updateCanvasSize } from "@/app/graphics"
import game from "./"

// shifts tiles based on rotation and updates the tile array
export const rotateMap = direction => {
  let rotatedMap = []
  let newX = (direction === `left`) ? 0 : game.maxMapSize - 1
  let newY = (direction === `left`) ? game.maxMapSize - 1 : 0

  for (let mX = 0; mX < game.maxMapSize; mX++) {
    for (let mY = 0; mY < game.maxMapSize; mY++) {
      if (typeof rotatedMap[newY] === `undefined`) rotatedMap[newY] = []
      if (typeof rotatedMap[newX] === `undefined`) rotatedMap[newX] = []

      // update tile position x/y
      rotatedMap[newY][newX] = data.map[mX][mY]
      rotatedMap[newY][newX].x = newY
      rotatedMap[newY][newX].y = newX

      // if building tile should flip, toggle rotate flag
      const buildingTile = getTile(data.map[mX][mY].tiles.building)

      if (rotatedMap[newY][newX].rotate === `Y`) {
        rotatedMap[newY][newX].rotate = `N`
      } else if (rotatedMap[newY][newX].rotate === `N` && buildingTile.flip_h === `Y`) {
        rotatedMap[newY][newX].rotate = `Y`
      }

      if (direction === `left`) {
        newY--
        if (newY < 0) newY = game.maxMapSize - 1
      } else {
        newY++
        if (newY >= game.maxMapSize) newY = 0
      }
    }

    if (direction === `left`) {
      newX++
      if (newX >= game.maxMapSize) newX = 0
    } else {
      newX--
      if (newX < 0) newX = game.maxMapSize - 1
    }
  }

  data.map = rotatedMap

  if (direction === `left`) {
    game.mapRotation++
    if (game.mapRotation > 3) game.mapRotation = 0
  } else {
    game.mapRotation--
    if (game.mapRotation < 0) game.mapRotation = 3
  }

  updateCanvasSize()
}
