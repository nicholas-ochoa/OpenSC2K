import { app } from 'electron';
import { init } from './init';

(async () => {
  await app.whenReady();
  init();
})();
