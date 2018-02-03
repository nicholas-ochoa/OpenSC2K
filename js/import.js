game.import = {
  struct: undefined,

  alreadyDecompressedSegments: {
    'ALTM': true,
    'CNAM': true
  },


  xzonTypeMap: {
    '0000': 0,
    '0001': 1,
    '0010': 2,
    '0011': 3,
    '0100': 4,
    '0101': 5,
    '0110': 6,
    '0111': 7,
    '1000': 8,
    '1001': 9
  },

  xterSlopeMap: {
    //    T R B L           B L R T
    0x0: [0,0,0,0], //0x0: [0,0,0,0], 256

    0x1: [0,0,1,1], //0x1: [1,1,0,0], 260
    0x2: [1,0,0,1], //0x2: [0,1,0,1], 257
    0x3: [1,1,0,0], //0x3: [0,0,1,1], 258
    0x4: [0,1,1,0], //0x4: [1,0,1,0], 259

    0x5: [1,0,1,1], //0x5: [1,1,0,1], 264
    0x6: [1,1,0,1], //0x6: [0,1,1,1], 261
    0x7: [1,1,1,0], //0x7: [1,0,1,1], 262
    0x8: [0,1,1,1], //0x8: [1,1,1,0], 263

    0x9: [0,0,0,1], //0x9: [0,1,0,0], 268
    0xA: [1,0,0,0], //0xA: [0,0,0,1], 265
    0xB: [0,1,0,0], //0xB: [0,0,1,0], 266
    0xC: [0,0,1,0], //0xC: [1,0,0,0], 267

    0xD: [1,1,1,1]  //0xD: [1,1,1,1]  269
  },

  xterTerrainTileMap: {
    0x0: 256,

    0x1: 260,
    0x2: 257,
    0x3: 258,
    0x4: 259,
    0x5: 264,
    0x6: 261,
    0x7: 262,
    0x8: 263,
    0x9: 268,
    0xA: 265,
    0xB: 266,
    0xC: 267,
    
    0xD: 269
  },

  xterWaterMap: {
    0x0: [1,0,0,1], // left-right open canal
    0x1: [0,1,1,0], // top-bottom open canal
    0x2: [1,1,0,1], // right open bay
    0x3: [1,0,1,1], // left open bay
    0x4: [0,1,1,1], // top open bay
    0x5: [1,1,1,0]  // bottom open bay
  },

  waterLevels: {
    0x0: "dry",
    0x1: "submerged",
    0x2: "shore",
    0x3: "surface",
    0x4: "waterfall"
  },


  openFile: function() {
    game.app.dialog.showOpenDialog((fileNames) => {
      if (fileNames === undefined){
        return;
      }

      game.fs.readFile(fileNames[0], (err, data) => {
        if (err) {
          console.log('Error reading file: '+err.message);
          return;
        }

        if (!this.isSimCity2000SaveFile){
          console.log('File is not a valid SimCity 2000 SC2 Save File');
          return;
        }

        let bytes = new Uint8Array(data);
        this.parse(bytes);

      });
    });
  },

  isSimCity2000SaveFile: function(bytes) {
    // check IFF header
    if(bytes[0] !== 0x46 ||
       bytes[1] !== 0x4F ||
       bytes[2] !== 0x52 ||
       bytes[3] !== 0x4D) {
      return false;
    }

    // check sc2k header
    if(bytes[8] !== 0x53 ||
       bytes[9] !== 0x43 ||
       bytes[10] !== 0x44 ||
       bytes[11] !== 0x48) {
      return false;
    }

    return true;
  },


  parse: function(bytes, options) {
    let buffer = new Uint8Array(bytes);
    let fileHeader = buffer.subarray(0, 12);
    let rest = buffer.subarray(12);
    let segments = this.splitIntoSegments(rest);
    
    this.toVerboseFormat(segments);
    console.log(this.struct);

    this.loadCity();
  },



  loadCity: function() {
    console.log('Loading City into Database..');

    console.log('Imported City Rotation: '+this.struct.MISC.rotation);

    var city_id = game.data.db.prepare('select ifnull(max(id), 0) + 1 as id from city').get();
    let name = 'Test City';
    let cityStmt = game.data.db.prepare('insert into city (id, name, tiles_x, tiles_y, rotation, water_level) values (?, ?, ?, ?, ?, ?)');
    cityStmt.run([city_id.id, name, 128, 128, this.struct.MISC.rotation, this.struct.MISC.waterLevel]);

    sql = `
insert into map (
  x, y, z, city_id, terrain_tile_id, zone_tile_id, underground_tile_id, building_tile_id, building_corners,
  zone_type, water_level, surface_water, conductive, powered, piped, watered, land_value, water_covered,
  rotate, salt_water, subway, subway_station, subway_direction, pipes
) values (
  :x, :y, :z, :city_id, :terrain_tile_id, :zone_tile_id, :underground_tile_id, :building_tile_id, :building_corners,
  :zone_type, :water_level, :surface_water, :conductive, :powered, :piped, :watered, :land_value, :water_covered,
  :rotate, :salt_water, :subway, :subway_station, :subway_direction, :pipes
)
    `;

    let mapStmt = game.data.db.prepare(sql);

    for (let i = 0; i < this.struct.tiles.length; i++) {
      let tile = this.struct.tiles[i];
      let terrainTileId = this.xterTerrainTileMap[(tile.XTER.id > 13 ? tile.XTER.id - 14 : tile.XTER.id)];
      let zoneTileId = (tile.XZON.type > 0 ? 290 + tile.XZON.type : 0); //291 is the tileID start for zones

      let values = {
        x: tile.x,
        y: tile.y,
        z: tile.ALTM.altitude,
        city_id: city_id.id,
        terrain_tile_id: terrainTileId,
        zone_tile_id: zoneTileId,
        underground_tile_id: 0,
        building_tile_id: tile.XBLD.id,
        building_corners: tile.XZON.corners,
        zone_type: tile.XZON.type,
        water_level: tile.XTER.waterLevel,
        surface_water: tile.XTER.surfaceWater,
        conductive: game.util.boolToYn(tile.XBIT.conductive),
        powered: game.util.boolToYn(tile.XBIT.powered),
        piped: game.util.boolToYn(tile.XBIT.piped),
        watered: game.util.boolToYn(tile.XBIT.watered),
        land_value: game.util.boolToYn(tile.XBIT.landValue),
        water_covered: game.util.boolToYn(tile.XBIT.waterCovered),
        rotate: game.util.boolToYn(tile.XBIT.rotate),
        salt_water: game.util.boolToYn(tile.XBIT.saltWater),
        subway: game.util.boolToYn(tile.XUND.subway),
        subway_station: game.util.boolToYn(tile.XUND.subwayStation),
        subway_direction: game.util.boolToYn(tile.XUND.subwayLeftRight),
        pipes: game.util.boolToYn(tile.XUND.pipes)
      };

      mapStmt.run(values);
    }

    alert('City Loaded! Click "OK" to reload..');
    window.location.reload();
  },



  toVerboseFormat: function(segments) {
    var x = 0;
    var y = 0;

    this.struct = {};
    this.struct.tiles = [];

    for(let i = 0; i < 128 * 128; i++) {
      this.struct.tiles.push({});
    }

    for (let i = 0; i < this.struct.tiles.length; i++) {
      if (y == 128) {
        y = 0;
        x++;
      }

      this.struct.tiles[i].x = x;
      this.struct.tiles[i].y = y;

      y++;
    }

    Object.keys(segments).forEach((segmentTitle) => {
      let data = segments[segmentTitle];
      let handler = this.segmentHandlers[segmentTitle];

      if(handler) {
        handler(data, this.struct);
      }
    });
  },


  splitIntoSegments: function(rest) {
    let segments = {};

    while(rest.length > 0) {
      let segmentTitle = Array.prototype.map.call(rest.subarray(0, 4), x => String.fromCharCode(x)).join('');
      let lengthBytes = rest.subarray(4, 8);
      let segmentLength = new DataView(lengthBytes.buffer).getUint32(lengthBytes.byteOffset);
      let segmentContent = rest.subarray(8, 8 + segmentLength);

      if(!this.alreadyDecompressedSegments[segmentTitle]) {
        segmentContent = this.decompressSegment(segmentContent);
      }

      segments[segmentTitle] = segmentContent;
      rest = rest.subarray(8 + segmentLength);
    }

    return segments;
  },

  decompressSegment: function(bytes) {
    let output = [];
    let dataCount = 0;

    for(let i = 0; i < bytes.length; i++) {
      if(dataCount > 0) {
        output.push(bytes[i]);
        dataCount -= 1;
        continue;
      }

      if(bytes[i] < 128) {
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
  },


  binaryString: function (bin, bytes) {
    return bin.toString(2).padStart(8 * bytes, '0');
  },

  hexString: function (bin, bytes) {
    return bin.toString(16).padStart(2 * bytes, '0');
  },
  


  // NOTE: uses DataView instead of typed array, because we need non-aligned access to 16bit ints
  segmentHandlers: {
    'ALTM': (data, struct) => {
      let view = new DataView(data.buffer, data.byteOffset, data.byteLength);

      // read two bytes every loop
      for (let i = 0; i < data.byteLength / 2; i++) {
        let square = view.getUint16(i * 2);
        struct.tiles[i].ALTM = {};
        struct.tiles[i].ALTM.tunnelLevels = (square & 0xFF00); // bytes 0..7
        struct.tiles[i].ALTM.waterFlag = (square & 0x0080) !== 0; // bytes 8, bool
        struct.tiles[i].ALTM.globalWaterLevel = (square & 0x0060); // bytes 9..10
        struct.tiles[i].ALTM.altitude = (square & 0x001F); // bytes 11..15
        //struct.tiles[i].ALTM.raw = game.import.binaryString(square, 2); // save binary flags as string
      }
    },

    'CNAM': (data, struct) => {
      let view = new Uint8Array(data);
      let len = view[0] & 0x3F; // limit to 32
      let strDat = view.subarray(1, 1 + len);
    
      struct.cityName = Array.prototype.map.call(strDat, x => String.fromCharCode(x)).join('').replace(/[^\x00-\x7F]/g, "");;
    },
    
    'XBIT': (data, struct) => {
      let view = new Uint8Array(data);
    
      view.forEach((square, i) => {
        struct.tiles[i].XBIT = {};
        struct.tiles[i].XBIT.conductive = (square & 0x80) !== 0;
        struct.tiles[i].XBIT.powered = (square & 0x40) !== 0;
        struct.tiles[i].XBIT.piped = (square & 0x20) !== 0;
        struct.tiles[i].XBIT.watered = (square & 0x10) !== 0;
        struct.tiles[i].XBIT.landValue = (square & 0x08) !== 0;
        struct.tiles[i].XBIT.waterCovered = (square & 0x04) !== 0;
        struct.tiles[i].XBIT.rotate = (square & 0x02) !== 0;
        struct.tiles[i].XBIT.saltWater = (square & 0x01) !== 0;
        //struct.tiles[i].XBIT.raw = game.import.binaryString(square, 1);
      });
    },
    
    'XBLD': (data, struct) => {
      let view = new Uint8Array(data);

      view.forEach((square, i) => {
        struct.tiles[i].XBLD = {};
        struct.tiles[i].XBLD.id = square;
        struct.tiles[i].XBLD.idHex = game.import.hexString(square, 1);
      });
    },
    
    'XTER': (data, struct) => {
      let view = new Uint8Array(data);

      view.forEach((square, i) => {
        let terrain = {};

        // defaults
        terrain.slope = null;
        terrain.surfaceWater = null;
        terrain.waterLevel = null;
        terrain.waterLevelHex = 0x0;

        // dry land, underwater, surface water
        if(square < 0x3E) {
          terrain.slope = game.import.xterSlopeMap[(square & 0x0F)];
          //terrain.surfaceWater = game.import.xterSlopeMap[0];
          terrain.surfaceWater = (square & 0x0F);
          terrain.waterLevel = game.import.waterLevels[((square & 0xF0) >> 4)];
          terrain.waterLevelHex = (square & 0xF0) >> 4;

        // waterfall special case
        } else if(square === 0x3E) {
          terrain.slope = game.import.xterSlopeMap[0];
          //terrain.surfaceWater = game.import.xterSlopeMap[0];
          terrain.surfaceWater = (square & 0x0F);
          terrain.waterLevel = game.import.waterLevels[0x4];
          terrain.waterLevelHex = 0x4;

        // surface water cont.
        } else if(square >= 0x40) {
          terrain.slope = game.import.xterSlopeMap[0];
          //terrain.surfaceWater = game.import.xterWaterMap[(square & 0x0F)];
          terrain.surfaceWater = (square & 0x0F);
          terrain.waterLevel = game.import.waterLevels[0x3];
          terrain.waterLevelHex = 0x3;
        }

        terrain.id = (square & 0x0F);
        terrain.raw = game.import.binaryString(square, 1);

        struct.tiles[i].XTER = terrain;
      });
    },
    
    'XUND': (data, struct) => {
      let view = new Uint8Array(data);

      view.forEach((square, i) => {
        let underground = {};

        // defaults
        underground.subway = false;
        underground.pipes = false;
        underground.slope = null;
        underground.subwayLeftRight = null;
        underground.missileSilo = false;
        underground.subwayStation = false;

        // subway, pipes
        if(square < 0x1E) {
          underground.slope = game.import.xterSlopeMap[(square & 0x0F)];

          if((square & 0xF0) === 0x00)
            underground.subway = true;
          else if(((square & 0xF0) === 0x10) && (square < 0x1F))
            underground.pipes = true;

        // subway / pipe crossover
        } else if((square === 0x1F) || (square === 0x20)) {
          underground.subway = true;
          underground.pipes = true;
          underground.slope = game.import.xterSlopeMap[0x0];
          underground.subwayLeftRight = square === 0x1F;

        // missile silo underground portion
        } else if(square === 0x22) {
          underground.missileSilo = true;

        // subway station / subrail transition
        } else if(square === 0x23) {
          underground.subwayStation = true;
          underground.slope = game.import.xterSlopeMap[0x0];
        }

        struct.tiles[i].XUND = underground;
        struct.tiles[i].XUND.raw = game.import.binaryString(square, 1);
      });
    },
    

    'XZON': (data, struct) => {

      let view = new Uint8Array(data);

      view.forEach((square, i) => {
        let zone = {};

        zone.corners = game.import.binaryString(square, 1).substring(0, 4); //first 4 bytes
        //zone.corners = '['+zone.corners[0]+','+zone.corners[1]+','+zone.corners[2]+','+zone.corners[3]+']';
        zone.zoneType = game.import.binaryString(square, 1).substring(4, 8); //last 4 bytes
        zone.type = game.import.xzonTypeMap[zone.zoneType];

        struct.tiles[i].XZON = zone;
      });
    },
    
    // signs, microsim labels, xthg data / references
    'XTXT': (data, struct) => {
      let view = new Uint8Array(data);

      view.forEach((square, i) => {
        let txt = {};

        if(square === 0x00) {
          txt.sign = false;
          txt.microsimLabel = false;

        } else if (square >= 0x01 && square <= 0x32) {
          txt.sign = true;
          txt.microsimLabel = false;
          txt.xlabId = game.import.hexString(square, 1);

        } else if (square >= 0x33 && square <= 0xC9){
          txt.sign = false;
          txt.microsimLabel = true;
          txt.xlabId = game.import.hexString(square, 1);
        } else if (square >= 0xC9) {
          txt.sign = false;
          txt.microsimLabel = false;
          txt.xthgData = game.import.hexString(square, 1);
        }

        struct.tiles[i].XTXT = txt;
        struct.tiles[i].XTXT.raw = game.import.binaryString(square, 1);

      });
    },
    
    // user text / labels / signs
    'XLAB': (data, struct) => {
      // labels (1 byte len + 24 byte string)
      let view = new Uint8Array(data);
      let labels = [];

      for (let i = 0; i < 256; i++) {
        let labelPos = i * 25;
        let labelLength = Math.max(0, Math.min(view[labelPos], 24));
        let labelData = view.subarray(labelPos + 1, labelPos + 1 + labelLength);

        labels[i] = Array.prototype.map.call(labelData, x => String.fromCharCode(x)).join('');
      }

      struct.XLAB = labels;
    },
    
    // misc data and statistics
    'MISC': (data, struct) => {
      let view = new DataView(data.buffer, data.byteOffset, data.byteLength);
      let misc = {};

      misc.rotation    = view.getUint32(0x0008); // 0 = base, 1 = counter clockwise (CCW), 2 = 2xCCW, 3 = 3xCCW
      misc.yearFounded = view.getUint32(0x000c);
      misc.daysElapsed = view.getUint32(0x0010);
      misc.money       = view.getUint32(0x0014);
      misc.population  = view.getUint32(0x0050);
      misc.zoomLevel   = view.getUint32(0x1014);
      misc.cityCenterX = view.getUint32(0x1018);
      misc.cityCenterY = view.getUint32(0x101c);
      misc.waterLevel  = view.getUint32(0x0E40);

      struct.MISC = misc;
    }

    // TODO: XMIC, XTHG, XGRP, XPLC, XFIR, XPOP, XROG, XPLT, XVAL, XCRM, XTRF
  }

};