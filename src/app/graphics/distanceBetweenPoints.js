// calculate distance in pixels between two sets of x/y coordinates
export const distanceBetweenPoints = (x1, y1, x2, y2) => Math.sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2))
