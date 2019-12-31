import 'source-map-support/register';
import startup from 'startup';

if (document.readyState !== 'loading') {
  startup.init();
} else {
  document.addEventListener('DOMContentLoaded', startup.init);
}
