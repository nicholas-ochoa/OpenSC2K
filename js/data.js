game.data = {
  db: undefined,

  cityId: undefined,
  cityName: undefined,
  cityRotation: undefined,
  cityLoaded: false,

  tiles: new Array(),
  map: new Array(),


  load: function() {
    var database = require('better-sqlite3');
    this.db = new database('./db/database.db');
    this.db.pragma('journal_mode = WAL');
    this.db.checkpoint();

    this.loadTiles();
    this.loadMap();
    this.maintenance();
  },



  maintenance: function() {
    var result = this.db.exec(`vacuum main`);
    this.db.checkpoint();
  },


  clear: function() {
    var result = this.db.exec(`delete from map`);
    var result = this.db.exec(`delete from city`);
    var result = this.db.exec(`vacuum main`);
    console.log('Database tables `map` and `city` have been truncated');
  },


  loadTiles: function() {
    console.log('Loading Tiles..');
    var rows = this.db.prepare(`select * from tiles order by id asc`).all();
  
    for (i = 0; i < rows.length; i++) {
      this.tiles[rows[i].id] = {
        id:              rows[i].id,
        name:            rows[i].name,
        description:     rows[i].description,
        type:            rows[i].type,
        size:            rows[i].lot_size,
        frames:          rows[i].frames,
        width:           undefined,
        height:          undefined,
        image:           new Array(),
        slopes:          game.util.toJson(rows[i].slopes),
        polygon:         game.util.toJson(rows[i].polygon),
        lines:           game.util.toJson(rows[i].lines),
        rotate_0:        rows[i].rotate_0,
        rotate_1:        rows[i].rotate_1,
        rotate_2:        rows[i].rotate_2,
        rotate_3:        rows[i].rotate_3,
        flip_h:          rows[i].flip_h,
        flip_alt_tile:   rows[i].flip_alt_tile
      };
    };

    console.log('Tiles Loaded');
  },



  loadMap: function() {
    var city = this.db.prepare(`select * from city where id = (select max(id) from city)`).get();

    if (city === undefined){
      game.graphics.primaryContext.font = '24px Verdana';
      game.graphics.primaryContext.fillStyle = 'rgba(255, 255, 255, 1)';
      game.graphics.primaryContext.textAlign = 'center';
      game.graphics.primaryContext.fillText('Could not load city!', document.documentElement.clientWidth / 2, game.graphics.primaryContext.canvas.height / 2);
      return;
    }

    console.log('Loading City: '+city.id);

    this.cityId = city.id;
    this.cityName = city.name;
    this.cityRotation = city.rotation;

    console.log(' - Map Rotation: '+game.mapRotation+', Saved City Rotation: '+this.cityRotation);

    game.waterLevel = city.water_level;

    //
    // params that change depending on the imported city rotation
    //
    if (this.cityRotation == 0){
      game.corners = ['1000','0100','0010','0001'];
      game.rotationModifier = 0;

    }else if (this.cityRotation == 1){
      game.corners = ['0001','1000','0100','0010'];
      game.rotationModifier = 1;

    }else if (this.cityRotation == 2){
      game.corners = ['0010','0001','1000','0100'];
      game.rotationModifier = 2;

    }else if (this.cityRotation == 3){
      game.corners = ['0100','0010','0001','1000'];
      game.rotationModifier = 3;

    }

    var rows = this.db.prepare(`select * from map where city_id = ? and x < ? and y < ? order by x asc, y asc`).all(city.id, game.maxMapSize, game.maxMapSize);

    for (i = 0; i < rows.length; i++) {
      if (typeof this.map[rows[i].x] === 'undefined')
        this.map[rows[i].x] = new Array;

      if (typeof this.map[rows[i].x][rows[i].y] === 'undefined')
        this.map[rows[i].x][rows[i].y] = new Array;


      this.map[rows[i].x][rows[i].y] = {
        x:                  rows[i].x,
        y:                  rows[i].y,
        z:                  rows[i].z,
        original_x:         rows[i].x,
        original_y:         rows[i].y,
        tiles:              {
          terrain: rows[i].terrain_tile_id,
          building: rows[i].building_tile_id,
          zone: rows[i].zone_tile_id,
          underground: rows[i].underground_tile_id
        },
        water_level:        rows[i].water_level,
        corners:            rows[i].building_corners,
        rotate:             rows[i].rotate
      };
    };

    this.cityLoaded = true;
    console.log('City Loaded');
  }
}