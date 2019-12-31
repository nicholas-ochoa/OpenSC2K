import 'source-map-support/register';
import { app } from 'electron';
import startup from 'startup';

(async () => {
  await app.whenReady();
  startup.init();
})();
