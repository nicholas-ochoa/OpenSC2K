//import jszip from 'jszip';
import * as CONST from '../constants';
import sc2 from '../import/sc2';

export default class load {
  constructor (options) {
    this.scene   = options.scene;
    this.sc2     = new sc2();
    this.file    = 'Default.sc2';
  }


  open () {
    if (!document.querySelector('#fileOpen')) {
      let input = document.createElement('input');

      input.id = 'fileOpen';
      input.type = 'file';
      input.onchange = (event) => {
        this.file = event.target.files[0].name;
        this.load(event.target.files[0]);
      };

      document.body.appendChild(input);
    }

    let event = new MouseEvent('click', {
      view: window,
      bubbles: true
    });

    let fileOpen = document.querySelector('#fileOpen');
    fileOpen.dispatchEvent(event);
  }


  async loadDefaultCity () {
    return new Promise((resolve) => {
      this.file = 'CAPEQUES.SC2'; //r3
      //this.file = 'BAYVIEW.SC2'; //r2, bridges
      //this.file = 'EGYPTFAL.SC2'; //r1
      //this.file = 'NEWCITY.SC2'; //r0
      //this.file = 'TOKYO.SC2'; // rails

      // primary test city
      this.file = 'TESTCITY.SC2';

      // scenario test cities
      //this.file = 'test/scenario/FLINT.SCN';
      //this.file = 'test/scenario/ATLANTA.SCN';
      //this.file = 'test/scenario/CHICAGO.SCN';

      // coordinate test city
      //this.file = 'test/coords/CQST.SC2';
      //this.file = 'test/tunnels/TUNNELS.SC2';

      // rotation test cities
      //this.file = 'test/rotation/CQ1R.SC2';
      //this.file = 'test/rotation/CQ2R.SC2';
      //this.file = 'test/rotation/CQ3R.SC2';
      //this.file = 'test/rotation/CQ4R.SC2';

      this.scene.load.binary(CONST.CITY, CONST.CITIES_PATH+ this.file);
      this.scene.load.start();

      this.scene.load.once(CONST.E_LOAD_COMPLETE, () => {
        this.parseCity().then((data) => {
          this.scene.importedData = data;
          resolve();
        });
      });


    });
  }


  async parseCity () {
    return new Promise((resolve, reject) => {
      let data = Buffer.from(this.scene.cache.binary.get(CONST.CITY));

      // sc2 file, first four bytes are ascii "FORM"
      if (data.readUInt32BE(0x00) == 0x464F524D)
        resolve(this.sc2.import(data));
      else
        reject(new Error('Invalid file format'));
    });
  }
}