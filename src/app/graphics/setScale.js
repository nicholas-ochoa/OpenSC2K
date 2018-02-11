import graphics from "./"

export const setScale = val => {
  graphics.scale = val
  graphics.primaryContext.scale(val, val)
  graphics.scaledInterfaceContext.scale(val, val)
}
