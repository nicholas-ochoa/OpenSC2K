import sc2 from 'sc2';
import path from 'path';

export async function load(filePath: string): Promise<void> {
  const ext: string = path.extname(filePath).toLowerCase();

  if (ext == '.sc2' || ext == '.scn') {
    await sc2.load(filePath);
  } else if (ext == '.opensc2k') {
    // await opensc2k.load(filePath);
  } else {
    console.error('unknown file format');
  }
}
