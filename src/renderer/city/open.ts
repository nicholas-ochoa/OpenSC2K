import ui from 'ui';
import { load } from './load';

export async function open() {
  try {
    const filePath: string = await ui.dialogs.openFile();

    if (filePath) {
      load(filePath);
    }
  } catch {}
}
