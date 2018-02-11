import { existsSync, writeFileSync } from "fs"

// quick and dirty function to write the blob contents of the tilemap canvas to a file
// todo: clean this up, make it generic
export const writeTilemapToFile = (blob, canvasCount) => {
  // let c = canvasCount
  let fileReader = new FileReader()

  fileReader.onload = () => {
    let x = 0

    while (existsSync(`${__dirname}/images/tilemap/tilemap_${x}.png`)) x++

    info(`Writing file: tilemap_${x}`)
    writeFileSync(`${__dirname}/images/tilemap/tilemap_${x}.png`, Buffer.from(new Uint8Array(this.result)))
  }

  fileReader.readAsArrayBuffer(blob)
}
