import graphics from "./"

// calculates if the provided cell object exists within the camera clipping boundary
export const isCellInsideClipBoundary = ({ coordinates: { center: { x, y } } }) => {
  const { top, left, bottom, right } = graphics.clipBoundary
  return (x < left || x > right) || (y < top || y > bottom)
}
