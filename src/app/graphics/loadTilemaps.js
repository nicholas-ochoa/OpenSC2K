import { readFileSync } from "fs"
import graphics, { checkLoad } from "./"

// loads the tilemaps into memory
export const loadTilemaps = () => {
  info(`Loading Tilemaps..`)

  const tilemapJson = readFileSync(`${__dirname}/../../images/tilemap/tilemap.json`)
  graphics.tilemap = JSON.parse(tilemapJson)

  const onload = (img, tilemapId) => {
    let canvas = document.createElement(`canvas`)
    canvas.width = img.width
    canvas.height = img.height
    const context = canvas.getContext(`2d`)
    context.drawImage(img, 0, 0)
    graphics.tilemapImages[tilemapId] = canvas
    graphics.loadedTilemaps++
    info(` - tilemap_${tilemapId}.png loaded`)
    checkLoad()
  }

  for (let i = 0; i < graphics.totalTilemaps; i++) {
    let img = new Image()
    img.src = `src/images/tilemap/tilemap_${i}.png`
    img.setAttribute(`tilemap_id`, i)
    img.onload = onload(img, i)
  }
}
