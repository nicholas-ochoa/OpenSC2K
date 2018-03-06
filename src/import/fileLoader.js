import bmp from 'bmp-js';
import { Buffer } from 'buffer';

// workaround for binary-parser use of eval() and referencing Buffer
window.Buffer = Buffer;

class fileLoader {
  static async load (filename) {

  }
  
  static async getXhr (filename, callback, ...args) {
    let xhr = new XMLHttpRequest();

    xhr.open('GET', '/assets/import/' + filename);
    xhr.responseType = 'arraybuffer';

    xhr.onload = async (event) => {
      let buffer = Buffer.from(xhr.response);
      await callback.apply(args[0], [buffer, args]);
    }

    xhr.send();
  }
}

export default fileLoader;