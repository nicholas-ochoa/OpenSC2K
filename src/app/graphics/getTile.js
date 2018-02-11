import data from "@/app/data"
import game from "@/app/game"
import { flipTile } from "./"

// returns the appropriate tile for the current map rotation
export const getTile = (tileId, cell = null) => {
  let tile = data.tiles[tileId]
  let rotation = game.mapRotation

  if (tile.flip_alt_tile === `Y` && cell !== null) {
    if ([0, 2].includes(rotation) && flipTile(tile, cell)) {
      if (rotation < 3) rotation++
      else rotation = 0
    } else if ([1, 3].includes(rotation) && !flipTile(tile, cell)) {
      if (rotation < 3) rotation++
      else rotation = 0
    } else if ([1, 3].includes(rotation) && flipTile(tile, cell)) {
      if (rotation < 3) rotation++
      else rotation = 0
    }
  }

  return data.tiles[tile[`rotate_${rotation}`]]
}
