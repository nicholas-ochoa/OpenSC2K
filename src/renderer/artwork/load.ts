import { globalAny } from 'utils/globalAny';
import { createAnimations } from './createAnimations';

export async function load() {
  const scene = globalAny.scene;

  const tilemapImage: string = 'tilemap/tilemap.png';
  const tilemapData: string = 'tilemap/tilemap.json';

  scene.load.atlas('tilemap', tilemapImage, tilemapData);

  await createAnimations();
}
