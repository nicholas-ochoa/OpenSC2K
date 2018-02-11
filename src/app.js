import data, { load, openFile } from "@/app/data"
import { start } from "@/app/game"
import { createRenderingCanvas, animationFrames } from "@/app/graphics"

const init = async () => {
  createRenderingCanvas()
  await load()

  if (!data.cityId) { // eslint-disable-line
    openFile()
    //window.location.reload()
  }

  animationFrames()
  start()
}

init()
