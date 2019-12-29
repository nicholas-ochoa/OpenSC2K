import palette from 'palette';
import lcm from 'compute-lcm';

// get the lowest common multiplier for all palette animation sequences
export function getFrameCount(image): number {
  const frames: any[] = [];

  for (let y = 0; y < image.block.length; y++) {
    for (let x = 0; x < image.block[y].pixels.length; x++) {
      const idx: number = image.block[y].pixels[x];
      const frameCount: number = palette.getFrameCount(idx);
      frames.push(frameCount);
    }
  }

  if (frames.length <= 1) {
    return 1;
  } else {
    const result: number = lcm(frames);
    return result;
  }
}
