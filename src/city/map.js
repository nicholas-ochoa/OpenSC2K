import cell from '../cell/cell';

class map {
  constructor (options) {
    this.scene = options.scene;
    this.common = this.scene.sys.game.common;
    this.city = options.city;

    this.loaded = false;
    this.width = options.width;
    this.height = options.height;
    this.cells = [];

    this.selectedCell = {
      x: 0,
      y: 0
    }

    this.sprites = {
      building: [],
      road: [],
      rail: [],
      highway: [],
      terrain: [],
      water: [],
      power: [],
      subway: [],
      pipe: [],
      zone: [],
      heightmap: []
    }

    for (let x = 0; x < this.width; x++) {
      for (let y = 0; y < this.height; y++) {
        if (!this.cells[x]) this.cells[x] = [];
        if (!this.cells[x][y]) this.cells[x][y] = [];
      }
    }
  }

  getCell (x, y) {
    if (!this.cells[x]) throw 'Invalid cell reference x: '+x+', y: '+y;
    if (!this.cells[x][y]) throw 'Invalid cell reference x: '+x+', y: '+y;

    return this.cells[x][y];
  }

  getSurroundingCells (cell) {
    let cells = {};
    let cellX = 0;
    let cellY = 0;

    for (let x = -1; x < 2; x++) {
      for (let y = -1; y < 2; y++) {
        cellX = cell.x + x;
        cellY = cell.y + y;

        if (x == -1 && y == -1) cells.sw = this.cells[cellX][cellY];
        if (x == -1 && y ==  0) cells.s = this.cells[cellX][cellY];
        if (x == -1 && y ==  1) cells.se = this.cells[cellX][cellY];

        if (x == 0 && y == -1) cells.w = this.cells[cellX][cellY];
        if (x == 0 && y ==  0) cells.c = this.cells[cellX][cellY];
        if (x == 0 && y ==  1) cells.e = this.cells[cellX][cellY];

        if (x == 1 && y == -1) cells.nw = this.cells[cellX][cellY];
        if (x == 1 && y ==  0) cells.n = this.cells[cellX][cellY];
        if (x == 1 && y ==  1) cells.ne = this.cells[cellX][cellY];
       
      }
    }

    return cells;
  }

  load () {
    let data = this.common.data;

    for (let i = 0; i < data.cells.length; i++) {
      let d = data.cells[i];
      let mapCell = new cell({
        scene: this.scene,
        city: this.city,
        map: this,
        x: d.x,
        y: d.y,
        z: d.z,
        cornersTopLeft: d.cornersTopLeft,
        cornersTopRight: d.cornersTopRight,
        cornersBottomLeft: d.cornersBottomLeft,
        cornersBottomRight: d.cornersBottomRight,
        conductive: d.conductive,
        powered: d.powered,
        piped: d.piped,
        watered: d.watered,
        rotate: d.rotate,
        landValueMask: d.landValueMask,
        saltWater: d.saltWater,
        waterCovered: d.waterCovered,
        missileSilo: d.missileSilo,
        waterLevel: d.waterLevel,
        surfaceWater: d.surfaceWater,
        tunnelLevel: d.tunnelLevel,
        altWaterCovered: d.altWaterCovered,
        terrainWaterLevel: d.terrainWaterLevel,
        importedData: d
      });

      if (d.tiles.terrain) mapCell.setTerrain(d.tiles.terrain);
      if (d.tiles.terrain) mapCell.setHeightmap(d.tiles.terrain);
      if (d.tiles.water) mapCell.setWater(d.tiles.water);
      if (d.tiles.road) mapCell.setRoad(d.tiles.road);
      if (d.tiles.power) mapCell.setPower(d.tiles.power);
      if (d.tiles.building) mapCell.setBuilding(d.tiles.building);
      if (d.tiles.zone) mapCell.setZone(d.tiles.zone);
      if (d.tiles.rail) mapCell.setRail(d.tiles.rail);
      if (d.tiles.highway) mapCell.setHighway(d.tiles.highway);
      //if (d.tiles.subway) mapCell.setSubway(d.tiles.subway);
      //if (d.tiles.pipe) mapCell.setPipe(d.tiles.pipe);

      if (!this.cells[mapCell.x]) this.cells[mapCell.x] = [];
      if (!this.cells[mapCell.x][mapCell.y]) this.cells[mapCell.x][mapCell.y] = [];
      this.cells[mapCell.x][mapCell.y] = mapCell;
    }

    this.loaded = true;
    this.common.data = [];
    this.calculateCellDepthSorting();
  }

  create () {
    if (!this.loaded) {
      this.scene.loadCity();
      return;
    }

    for (let x = 0; x < this.width; x++) {
      for (let y = 0; y < this.height; y++) {
        this.cells[x][y].create();
      }
    }
  }

  update () {
    //this.checkCellVisibility();
  }

  shutdown () {
    this.loaded = false;
    this.map.cells = [];
  }

  toggleLayerVisibility (type) {
    if (this.sprites[type].length == 0)
      return;

    let visible = this.sprites[type][0].visible ? false : true;
    let active = this.sprites[type][0].active ? false : true;

    this.sprites[type].forEach((sprite) => {
      sprite.setVisible(visible);
      sprite.setActive(active);
    });
  }


  checkCellVisibility () {
    let worldBounds = this.common.viewport.worldBounds.rect;

    for (let x = 0; x < this.width; x++) {
      for (let y = 0; y < this.height; y++) {
        let contains = Phaser.Geom.Rectangle.Contains(worldBounds, this.cells[x][y].position.center.x, this.cells[x][y].position.center.y);

        if (contains)
          this.cells[x][y].wake();
        else
          this.cells[x][y].sleep();
      }
    }
  }


  calculateCellDepthSorting () {
    var depth = 0;
    var c;
    var x;
    var y;

    // top half of map (includes center row)
    x = this.width;
    y = 0;

    for (c = 0; c <= this.width; c++) {
      for (x = (x - c); x < this.width; x++) {
        let mapCell = this.getCell(x, y);
        mapCell.setDepth(depth);
        mapCell.updatePosition();
        y += 1;
      }

      depth += 64;
      y = 0;
    }

    // bottom half of map (does not include center row)
    x = 0;
    y = this.height;

    for (c = (this.height - 1); c >= 0; c--) {
      for (y = (y - c); y < this.height; y++) {
        let mapCell = this.getCell(x, y);
        mapCell.setDepth(depth);
        mapCell.updatePosition();
        x += 1;
      }

      depth += 64;
      x = 0;
    }
  }
}

export default map;