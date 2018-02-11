import graphics from "./"

// checks whether the tilemap images are loaded
export const checkLoad = () => {
  (graphics.totalTilemaps === graphics.loadedTilemaps) ? graphics.ready = true : graphics.ready = false

  if (graphics.ready) info(`Tilemaps Loaded`)
}
