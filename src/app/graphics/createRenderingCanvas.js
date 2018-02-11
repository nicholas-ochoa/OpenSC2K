import graphics, { loadTilemaps } from "./"

// create the initial rendering canvas for primary and interface components
export const createRenderingCanvas = () => {
  graphics.primaryCanvas = document.querySelectorAll(`#primaryCanvas`)
  graphics.primaryContext = graphics.primaryCanvas[0].getContext(`2d`)

  graphics.interfaceCanvas = document.querySelectorAll(`#interfaceCanvas`)
  graphics.interfaceContext = graphics.interfaceCanvas[0].getContext(`2d`)

  graphics.scaledInterfaceCanvas = document.querySelectorAll(`#interfaceCanvas`)
  graphics.scaledInterfaceContext = graphics.interfaceCanvas[0].getContext(`2d`)

  // set initial properties
  const width = document.documentElement.clientWidth
  const height = document.documentElement.clientHeight

  graphics.primaryContext.canvas.width = width
  graphics.primaryContext.canvas.height = height

  graphics.interfaceContext.canvas.width = width
  graphics.interfaceContext.canvas.height = height

  graphics.scaledInterfaceContext.canvas.width = width
  graphics.scaledInterfaceContext.canvas.height = height

  graphics.primaryContext.imageSmoothingEnabled = false
  graphics.interfaceContext.imageSmoothingEnabled = false
  graphics.scaledInterfaceContext.imageSmoothingEnabled = false

  loadTilemaps()
}
