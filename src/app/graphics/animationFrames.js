import graphics from "./"

// game animation loop
// every 500ms (this.animationFrameRate), this increases the frame counter by 1
// sets draw frame to true to force an update
export const animationFrames = () => {
  graphics.animationFrame--

  if (graphics.animationFrame < 0) graphics.animationFrame = graphics.maxAnimationFrames

  graphics.drawFrame = true

  setTimeout(() => { animationFrames() }, graphics.animationFrameRate)
}
