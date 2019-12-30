import tiles from 'tiles';
import { globalAny } from 'utils/globalAny';

export async function createAnimations() {
  const scene = globalAny.scene;

  await tiles.getData();

  for (let i = 1; i < tiles.data.length; i++) {
    const tile = tiles.data[i];

    // set up animations
    if (tile.frames > 1) {
      scene.anims.create({
        key: tile.id,
        frames: scene.anims.generateFrameNames('tilemap', {
          prefix: tile.id + '_',
          start: tile.reverseAnimation ? tile.frames : 0,
          end: tile.reverseAnimation ? 0 : tile.frames,
        }),
        repeat: -1,
        frameRate: tile.frameRate || 2,
        delay: tile.animationDelay || 0,
      });

      scene.anims.create({
        key: tile.id + '_R',
        frames: scene.anims.generateFrameNames('tilemap', {
          prefix: tile.id + '_',
          start: tile.reverseAnimation ? 0 : tile.frames,
          end: tile.reverseAnimation ? tile.frames : 0,
        }),
        repeat: -1,
        frameRate: tile.frameRate || 2,
        delay: tile.animationDelay || 0,
      });
    }
  }
}
