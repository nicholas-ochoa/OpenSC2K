import debug from "./"

export const endDebugging = () => {
  const time = performance.now()

  debug.frames++

  if (time > debug.previousTime + 1000) {
    debug.msPerFrame = Math.round(time - debug.beginTime)
    debug.fps = Math.round((debug.frames * 1000) / (time - debug.previousTime))
    debug.previousTime = time
    debug.frameCount += debug.frames
    debug.frames = 0
  }

  return time
}
