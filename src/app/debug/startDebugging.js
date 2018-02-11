import debug from "./"

export const startDebugging = () => {
  debug.beginTime = performance.now()
  debug.tileCount = 0
}
