import { writeFileSync } from "fs"
import game from "@/app/game"
import graphics, { drawVectorTile } from "@/app/graphics"
import data, { writeTilemapToFile } from "./"

// creates a tilemap from the extracted LARGE.dat resources
// todo: utilize LARGE.DAT extraction to avoid writing PNG files
// todo: clean up, remove redundancy if possible
// todo: display results in a separate window?
// todo: interface
export const createTilemap = () => {
  let tilemap = {}

  let x = 0
  let y = 0
  let w = 0
  let h = 0

  let tilemapWidth = 4096
  let tilemapHeight = 4096

  let maxWidth = 64
  let maxHeight = 64
  let rowMaxY = 0
  let canvasCount = 0

  let tiles = data.tiles
  // let tileCount = tiles.length

  // let scaling = 1
  let drawStroke = false

  //primaryContext.scale(scaling,scaling)
  //primaryCanvas.width = tilemapWidth
  //primaryCanvas.height = tilemapHeight

  let canvas = document.createElement(`canvas`)
  canvas.width = tilemapWidth
  canvas.height = graphics.primaryCanvas.height
  let context = canvas.getContext(`2d`)

  context.strokeStyle = `white`
  //context.fillStyle = `blue`
  //context.fillRect(0,0,tilemapWidth,tilemapHeight)

  //primaryContext.drawImage(canvas, 0, 0)

  // add tilemap loaded flag
  for (let i = 0; i < 500; i++) {
    tiles[i].tilemapLoaded = false
  }

  const toBlob = blob => {
    writeTilemapToFile(blob, canvasCount)
  }
  // draw all tiles + framaes
  for (let loop = 0; loop < 16; loop++) {
    for (let i = 0; i < 500; i++) {
      for (let f = 0; f < tiles[i].image.length; f++) {
        if (!tiles[i].tilemapLoaded) {
          w = tiles[i].image[f].width
          h = tiles[i].image[f].height

          if (!(w > maxWidth || h > maxHeight)) {
            // max tile height in this row
            if (h > rowMaxY) rowMaxY = h

            if (x + w > tilemapWidth) {
              y += rowMaxY
              rowMaxY = 0
              x = 0
            }

            // flush canvas
            if (y + h > tilemapHeight) {
              //this.primaryContext.drawImage(canvas, tilemapWidth * canvasCount, 0)
              canvas.toBlob(toBlob)
              context.clearRect(0, 0, tilemapWidth, tilemapHeight)
              //context.fillStyle = 'blue'
              //context.fillRect(0,0,tilemapWidth,tilemapHeight)
              canvasCount++
              data.tilemapCount++
              y = 0
              x = 0
            }

            context.drawImage(tiles[i].image[f], x, y)

            tilemap[`${tiles[i].id}_${f}`] = { t: canvasCount, x, y, w, h }

            if (drawStroke) {
              context.strokeStyle = `blue`
              context.strokeRect(x, y, w, h)
            }

            x += w

            if (tiles[i].frames === f + 1 || tiles[i].frames === 0) tiles[i].tilemapLoaded = true
          }
        }
      }
    }

    maxWidth += 32
    maxHeight += 32
  }

  // reinitialize
  for (let i = 0; i < 500; i++) {
    tiles[i].tilemapLoaded = false
  }

  y += rowMaxY
  maxWidth = 64
  maxHeight = 64
  rowMaxY = 0

  // once again, only including tiles that are flagged to flip horizontally
  for (let loop = 0; loop < 16; loop++) {
    for (let i = 0; i < 500; i++) {
      for (let f = 0; f < tiles[i].image.length; f++) {
        if (tiles[i].flip_h !== `Y`) continue

        if (tiles[i].tilemapLoaded) continue

        w = tiles[i].image[f].width
        h = tiles[i].image[f].height

        if (w > maxWidth || h > maxHeight) continue

        // max tile height in this row
        if (h > rowMaxY) rowMaxY = h

        if (x + w > tilemapWidth) {
          y += rowMaxY
          rowMaxY = 0
          x = 0
        }

        // flush canvas
        if (y + h > tilemapHeight) {
          //primaryContext.drawImage(canvas, tilemapWidth * canvasCount, 0)
          canvas.toBlob(toBlob)
          context.clearRect(0, 0, tilemapWidth, tilemapHeight)
          //context.fillStyle = 'blue'
          //context.fillRect(0,0,tilemapWidth,tilemapHeight)
          canvasCount++
          data.tilemapCount++
          y = 0
          x = 0
        }

        // flip image
        let tempCanvas = document.createElement(`canvas`)
        tempCanvas.width = tiles[i].image[f].width
        tempCanvas.height = tiles[i].image[f].height
        let tempCtx = tempCanvas.getContext(`2d`)
        tempCtx.scale(-1, 1)
        tempCtx.translate(-tempCanvas.width - tiles[i].image[f].width, 0)
        tempCtx.drawImage(tiles[i].image[f], tempCanvas.width, 0)

        // draw to tilemap
        context.drawImage(tempCanvas, x, y)

        if (drawStroke) {
          context.strokeStyle = `green`
          context.strokeRect(x, y, w, h)
        }

        tilemap[`${tiles[i].id}_H_${f}`] = { t: canvasCount, x, y, w, h }

        x += w

        if (tiles[i].frames === f + 1 || tiles[i].frames === 0) tiles[i].tilemapLoaded = true
      }
    }

    maxWidth += 32
    maxHeight += 32
  }

  // finally, one last round to generate all of the "vector" based tiles used for various purposes
  y += rowMaxY
  maxWidth = 64
  maxHeight = 64
  rowMaxY = 0

  for (let i = 256; i < 269; i++) {
    for (let p = 0; p < 32; p++) {
      if (tiles[i].polygon === null) continue

      let f = 0

      w = tiles[i].image[f].width
      h = tiles[i].image[f].height

      // max tile height in this row
      if (h > rowMaxY) rowMaxY = h

      if (x + w > tilemapWidth / 2) {
        y += rowMaxY
        rowMaxY = 0
        x = 0
      }

      // flush canvas
      if (y + h > tilemapHeight) {
        graphics.primaryContext.drawImage(canvas, tilemapWidth * canvasCount, 0)
        canvas.toBlob(toBlob)
        context.clearRect(0, 0, tilemapWidth, tilemapHeight)
        //context.fillStyle = 'blue'
        //context.fillRect(0,0,tilemapWidth,tilemapHeight)
        canvasCount++
        this.tilemapCount++
        y = 0
        x = 0
      }

      let tempCanvas = document.createElement(`canvas`)
      tempCanvas.width = tiles[i].image[f].width
      tempCanvas.height = tiles[i].image[f].height
      let tempCtx = tempCanvas.getContext(`2d`)
      let tilemapId
      // shift id by 16 for water height map
      if (p > 15) {
        let o = p - 16
        drawVectorTile(tiles[i].id, game.tiles.waterHeightMap[o].fill, game.tiles.waterHeightMap[o].stroke, game.tiles.waterHeightMap[o].lines, 0+32, 0, tempCtx)
        tilemapId = `${tiles[i].id}_VW_${o}`
      } else {
        drawVectorTile(tiles[i].id, game.tiles.landHeightMap[p].fill, game.tiles.landHeightMap[p].stroke, game.tiles.landHeightMap[p].lines, 0+32, 0, tempCtx)
        tilemapId = `${tiles[i].id}_VT_${p}`
      }

      // draw to tilemap
      context.drawImage(tempCanvas, x, y)

      tilemap[tilemapId] = { t: canvasCount, x, y, w, h }

      if (drawStroke) {
        context.strokeStyle = `red`
        context.strokeRect(x, y, w, h)
      }

      x += w
    }
  }

  canvas.toBlob(toBlob)

  //primaryContext.drawImage(canvas, 0, tilemapHeight)

  let tilemapString = JSON.stringify(tilemap)

  writeFileSync(`${__dirname}/images/tilemap/tilemap.json`, tilemapString)
}
