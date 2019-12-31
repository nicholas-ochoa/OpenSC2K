import tiles from 'tiles';
import { globals } from 'utils/globals';

export function animations() {
  const scene = globals.scenes.load;

  for (let i = 1; i < tiles.data.length; i++) {
    const tile = tiles.data[i];
    const imageName: string = tile.id + 1000;

    if (tile.frames > 1) {
      scene.anims.create({
        key: `${imageName}`,
        frames: scene.anims.generateFrameNames('tilemap', {
          prefix: `${imageName}_`,
          start: tile.reverseAnimation ? tile.frames : 0,
          end: tile.reverseAnimation ? 0 : tile.frames,
        }),
        repeat: -1,
        frameRate: tile.frameRate ?? 2,
        delay: tile.animationDelay ?? 0,
      });

      scene.anims.create({
        key: `${imageName}_R`,
        frames: scene.anims.generateFrameNames('tilemap', {
          prefix: `${imageName}_`,
          start: tile.reverseAnimation ? 0 : tile.frames,
          end: tile.reverseAnimation ? tile.frames : 0,
        }),
        repeat: -1,
        frameRate: tile.frameRate ?? 2,
        delay: tile.animationDelay ?? 0,
      });
    }
  }

  globals.loaded.animations = true;
}
