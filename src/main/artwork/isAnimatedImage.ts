import { isAnimatedIndex } from 'palette';

// check if image contains any palette indexes that cycle with each frame (animated)
export function isAnimatedImage(image): boolean {
  for (let y = 0; y < image.length; y++) {
    for (let x = 0; x < image[y].pixels.length; x++) {
      if (isAnimatedIndex(image[y].pixels[x])) {
        return true;
      }
    }
  }

  return false;
}
