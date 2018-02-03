game.data = {
  tilePath: 'images/tiles/',
  database: undefined,
  db: undefined,

  cityId: undefined,
  cityName: undefined,
  cityRotation: undefined,

  cityLoaded: false,

  tiles: new Array(),
  terrain: new Array(),
  buildings: new Array(),
  map: new Array(),

  totalImages: 0,
  loadedImages: 0,
  ready: false,

  load: function() {
    var database = require('better-sqlite3');
    this.db = new database('./db/database.db');
    this.db.pragma('journal_mode = WAL');

    this.loadTiles();
    this.loadMap();
    this.maintenance();
  },


  loadingMessage: function() {
    game.graphics.primaryContext.font = '24px Verdana';
    game.graphics.primaryContext.fillStyle = 'rgba(255, 255, 255, 1)';
    game.graphics.primaryContext.textAlign = 'center';
    game.graphics.primaryContext.fillText('Loading resources..', document.documentElement.clientWidth / 2, game.graphics.primaryContext.canvas.height / 2);
    game.graphics.primaryContext.textAlign = 'left';
  },


  maintenance: function() {
    let result = this.db.exec(`vacuum main`);
  },


  clear: function() {
    let result = this.db.exec(`delete from map`);
    let result = this.db.exec(`delete from city`);
    let result = this.db.exec(`vacuum main`);
  },


  loadTiles: function() {
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
        flip_v:          rows[i].flip_v
      };
    };
  },


  checkImageLoad: function(){
    if (this.totalImages === this.loadedImages)
      this.ready = true;
    else
      this.ready = false;
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

    console.log('Map Rotation: '+game.mapRotation);
    console.log('City Rotation: '+this.cityRotation);
    game.waterLevel = city.water_level;

    if (this.cityRotation == 0)
      game.corners = ['1000','0100','0010','0001'];
    else if (this.cityRotation == 1)
      game.corners = ['0001','1000','0100','0010'];
    else if (this.cityRotation == 2)
      game.corners = ['0010','0001','1000','0100'];
    else if (this.cityRotation == 3)
      game.corners = ['0100','0010','0001','1000'];

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
  }
}