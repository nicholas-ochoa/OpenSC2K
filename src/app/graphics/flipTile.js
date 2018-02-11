import data from "@/app/data"
import game from "@/app/game"

// returns true if the tile should be flipped horizontally (mirrored)
// based on the tile object, cell object, current map rotation and original city rotation
// todo: needs work, does not work as expected
export const flipTile = ({ id, flip_h: flipH }, { rotate }) => (
  id <= 110
  && flipH !== `N`
  && rotate !== `Y`
  && (data.cityRotation === 0 || 1 || 2 || 3)
  && ([0, 2].includes(game.mapRotation) || [1, 3].includes(game.mapRotation))
)
