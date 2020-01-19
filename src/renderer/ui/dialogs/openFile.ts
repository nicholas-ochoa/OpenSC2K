import electron, { remote } from 'electron';
import config from 'config';
import path from 'path';

export async function openFile(
  title?: string,
  defaultPath?: string,
  filters?: electron.FileFilter[],
  multiSelections?: boolean
): Promise<string> {
  const dialog = remote.dialog;

  const defaultFilters: electron.FileFilter[] = [
    { name: 'SimCity 2000 and OpenSC2K Cities', extensions: ['sc2', 'scn', 'opensc2k'] },
    { name: 'SimCity 2000 Cities', extensions: ['sc2', 'scn'] },
    { name: 'OpenSC2K Cities', extensions: ['opensc2k'] },
  ];

  const options: any = {
    title,
    defaultPath: defaultPath ?? path.join(config.get('appPath'), config.get('paths.cities')),
    filters: filters ?? defaultFilters,
    properties: [],
  };

  if (multiSelections) {
    options.properties.push('multiSelections');
  }

  const result: any = await dialog.showOpenDialog(options);

  if (result.canceled) {
    throw new Error('cancelled');
  }

  if (multiSelections) {
    return result.filePaths.join(';');
  } else {
    return result.filePaths[0];
  }
}
