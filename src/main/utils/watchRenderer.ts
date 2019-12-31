import chokidar from 'chokidar';
import config from 'config';
import path from 'path';

export function watchRenderer(win: any) {
  const appPath: string = config.get('appPath');
  const rendererOutput: string = path.join(appPath, 'dist', 'renderer');

  chokidar
    .watch(rendererOutput, {
      awaitWriteFinish: true,
      ignored: [/(^|[/\\])\../, '**/*.map'],
      ignoreInitial: true,
    })
    .on('change', (event, path) => {
      console.log('Reload renderer..');
      win.reload();
    });
}
