import graphics from "./"

// calculates if the provided x/y coordinates are within the camera clipping boundary
export const isInsideClipBoundary = (x, y) => {
  const { tileHeight: h, tileWidth: w, clipBoundary: { top, left, bottom, right } } = graphics
  return ((x < left - (h * 4) || x > right + (h * 3)) || (y < top - w || y > bottom + (w * 3)))
}
