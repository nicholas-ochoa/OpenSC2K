import { alreadyDecompressedSegments } from './constants';
import segmentHandlers from './segmentHandlers'

class importCity {
  constructor (options) {
    this.scene = options.scene;
    this.common = this.scene.sys.game.common;
    this.struct = {};
    this.struct.tiles = [];
    this.data = {};
  }

  loadDefaultCity () {
    let city;

    city = 'CAPEQUES.SC2'; //r3
    //city = 'BAYVIEW.SC2'; //r2, bridges
    //city = 'EGYPTFAL.SC2'; //r1
    //city = 'NEWCITY.SC2'; //r0

    //city = 'TOKYO.SC2'; // rails

    let xhr = new XMLHttpRequest();
    xhr.open("GET", "/assets/cities/" + city);
    xhr.responseType = "blob";
    xhr.onload = () => {
      this.parseFile(xhr.response);
    }
    xhr.send();
  }

  createFileOpen () {
    let input = document.createElement('input');

    input.id = 'fileOpen';
    input.type = 'file';
    input.onchange = (event) => {
      this.parseFile(event.target.files[0]);
    }

    document.body.appendChild(input);
  }

  openFile () {
    if (!document.querySelector('#fileOpen'))
      this.createFileOpen();

    let event = new MouseEvent('click', {
      view: window,
      bubbles: true
    });

    let fileOpen = document.querySelector('#fileOpen');
    let fileOpenEvent = fileOpen.dispatchEvent(event);
  }

  parseFile (file) {
    let reader = new FileReader();

    reader.onload = (event) => {
      let bytes = new Uint8Array(event.target.result);

      if (!this.isSimCity2000SaveFile(bytes)) throw 'File is not a valid SimCity 2000 SC2 Save File';
      
      this.common.data = this.parse(bytes);
      this.scene.scene.start('load');
    }

    reader.readAsArrayBuffer(file);
  }

  isSimCity2000SaveFile (bytes) {
    // check IFF header
    if (bytes[0] !== 0x46 ||
       bytes[1] !== 0x4F ||
       bytes[2] !== 0x52 ||
       bytes[3] !== 0x4D) {
      return false;
    }

    // check sc2k header
    if (bytes[8] !== 0x53 ||
       bytes[9] !== 0x43 ||
       bytes[10] !== 0x44 ||
       bytes[11] !== 0x48) {
      return false;
    }

    return true;
  }


  parse (bytes, options) {
    let buffer = new Uint8Array(bytes);
    let fileHeader = buffer.subarray(0, 12);
    let rest = buffer.subarray(12);
    let segments = this.splitIntoSegments(rest);
    let handlers = new segmentHandlers();
    let x = 0;
    let y = 0;

    this.struct.tiles = [];

    for (let i = 0; i < 128 * 128; i++)
      this.struct.tiles.push({});

    for (let i = 0; i < this.struct.tiles.length; i++) {
      if (y == 128) {
        y = 0;
        x += 1;
      }

      this.struct.tiles[i].x = x;
      this.struct.tiles[i].y = y;

      y += 1;
    }

    Object.keys(segments).forEach((segmentTitle) => {
      let handler = handlers[segmentTitle];

      if (handler)
        handler(segments[segmentTitle], this.struct);
    });

    return this.parseStruct();
  }


  parseStruct () {
    let data = {
      info: {
        name: this.struct.cityName,
        rotation: this.struct.MISC.rotation,
        waterLevel: this.struct.MISC.waterLevel,
        yearFounded: this.struct.MISC.yearFounded,
        money: this.struct.MISC.money,
        population: this.struct.MISC.population,
        zoomLevel: this.struct.MISC.zoomLevel,
        cityCenter: { x: this.struct.MISC.cityCenterX, y: this.struct.MISC.cityCenterY },
        width: 128,
        height: 128
      },
      cells: []
    }

    for (let i = 0; i < this.struct.tiles.length; i++) {
      let tile = this.struct.tiles[i];

      let values = {
        x:                     tile.x,
        y:                     tile.y,
        z:                     tile.ALTM.altitude,

        data:                  tile,

        tiles: {
          terrain:             tile.XTER.terrain || null,
          heightmap:           tile.XTER.terrain || null,
          water:               tile.XTER.water || null,
          zone:                tile.XZON.zone || null,
          building:            tile.XBLD.building || null,
          road:                tile.XBLD.road || null,
          rail:                tile.XBLD.rail || null,
          power:               tile.XBLD.power || null,
          highway:             tile.XBLD.highway || null,
          subway:              tile.XUND.subway || null,
          pipes:               tile.XUND.pipes || null,
        },

        cornersTopLeft:        tile.XZON.topLeft,
        cornersTopRight:       tile.XZON.topRight,
        cornersBottomLeft:     tile.XZON.bottomLeft,
        cornersBottomRight:    tile.XZON.bottomRight,

        conductive:            tile.XBIT.conductive,
        powered:               tile.XBIT.powered,
        piped:                 tile.XBIT.piped,
        watered:               tile.XBIT.watered,
        rotate:                tile.XBIT.rotate,
        landValueMask:         tile.XBIT.landValueMask,
        saltWater:             tile.XBIT.saltWater,
        waterCovered:          tile.XBIT.waterCovered,
        missileSilo:           tile.XUND.missileSilo,

        waterLevel:            tile.XTER.waterLevel,
        surfaceWater:          tile.XTER.surfaceWater,

        tunnelLevel:           tile.ALTM.tunnelLevels,
        altWaterCovered:       tile.ALTM.waterCovered,
        terrainWaterLevel:     tile.ALTM.waterLevel,
      }

      data.cells.push(values);
    }
    
    return data;
  }


  splitIntoSegments (rest) {
    let segments = {};

    while (rest.length > 0) {
      let segmentTitle = Array.prototype.map.call(rest.subarray(0, 4), x => String.fromCharCode(x)).join('');
      let lengthBytes = rest.subarray(4, 8);
      let segmentLength = new DataView(lengthBytes.buffer).getUint32(lengthBytes.byteOffset);
      let segmentContent = rest.subarray(8, 8 + segmentLength);

      if (!alreadyDecompressedSegments[segmentTitle])
        segmentContent = this.decompressSegment(segmentContent);

      segments[segmentTitle] = segmentContent;
      rest = rest.subarray(8 + segmentLength);
    }

    return segments;
  }

  decompressSegment (bytes) {
    let output = [];
    let dataCount = 0;

    for (let i = 0; i < bytes.length; i++) {
      if (dataCount > 0) {
        output.push(bytes[i]);
        dataCount -= 1;
        continue;
      }

      if (bytes[i] < 128) {
        // data bytes
        dataCount = bytes[i];
      } else {
        // run-length encoded byte
        let repeatCount = bytes[i] - 127;
        let repeated = bytes[i + 1];

        for (let i = 0; i < repeatCount; i++) {
          output.push(repeated);
        }
        // skip the next byte
        i += 1;
      }
    }

    return Uint8Array.from(output);
  }
}

export default importCity;