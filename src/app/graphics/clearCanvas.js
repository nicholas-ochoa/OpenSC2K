import graphics from "./"

// clears the interface canvas every tick
// clears the primary canvas once per draw frame
export const clearCanvas = () => {
  const width = document.documentElement.clientWidth
  const height = document.documentElement.clientHeight

  graphics.interfaceContext.clearRect(0, 0, width, height)
  graphics.scaledInterfaceContext.clearRect(0, 0, width, height)

  if (graphics.drawFrame) graphics.primaryContext.clearRect(0, 0, width, height)
}
