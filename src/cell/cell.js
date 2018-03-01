import Phaser from 'phaser';
import building from '../tiles/building'
import terrain from '../tiles/terrain'
import water from '../tiles/water'
import zone from '../tiles/zone'
import road from '../tiles/road'
import rail from '../tiles/rail'
import highway from '../tiles/highway'
import power from '../tiles/power'
import pipes from '../tiles/pipes'
import subway from '../tiles/subway'
import heightmap from '../tiles/heightmap'

class cell {
  constructor (options) {
    this.scene = options.scene;
    this.common = this.scene.sys.game.common;
    
    this.x = options.x || 0;
    this.y = options.y || 0;
    this.z = options.z || 0;

    this.calculatePosition();

    this.depth = options.depth || 0;

    this.initialized = false;
    this.interaction = null;
    this.sleeping    = false;

    this.building   = null;
    this.zone       = null;
    this.water      = null;
    this.road       = null;
    this.rail       = null;
    this.power      = null;
    this.highway    = null;
    this.terrain    = null;
    this.heightmap  = null;
    this.subway     = null;
    this.pipes      = null;

    this.tiles = [];
    this.sprites = [];

    this.properties = {
      network:             false,
      conductive:          options.conductive          || false,
      powered:             options.powered             || false,
      piped:               options.piped               || false,
      watered:             options.watered             || false,
      rotate:              options.rotate              || false,
      landValueMask:       options.landValueMask       || false,
      saltWater:           options.saltWater           || false,
      waterCovered:        options.waterCovered        || false,
      missileSilo:         options.missileSilo         || false,
      cornersTopLeft:      options.cornersTopLeft      || false,
      cornersTopRight:     options.cornersTopRight     || false,
      cornersBottomLeft:   options.cornersBottomLeft   || false,
      cornersBottomRight:  options.cornersBottomRight  || false,
      waterLevel:          options.waterLevel          || 'dry',
      altWaterCovered:     options.altWaterCovered     || false,
      terrainWaterLevel:   options.terrainWaterLevel   || null,
    }

    return this;
  }

  getProperty (property) {
    if (this.properties[property] === undefined) throw 'Invalid cell property';
    
    return this.properties[property];
  }

  setProperty (property, value) {
    if (this.properties[property] === undefined) throw 'Invalid cell property';
    
    this.properties[property] = value;
  }

  updatePosition () {
    this.calculatePosition();

    // todo: code to look at each tile sprite and move it
  }

  calculatePosition () {
    let offsetX = this.x * (this.common.tileWidth / 2) + (this.y * (this.common.tileWidth / 2));
    let offsetY = this.y * (this.common.tileHeight / 2) - (this.x * (this.common.tileHeight / 2));
    let offsetZ = (this.z > 1 ? (this.common.layerOffset * this.z) + this.common.layerOffset : 0);

    this.position = {
      top: {
        x: offsetX + (this.common.tileWidth / 2),
        y: offsetY - offsetZ
      },
      right: {
        x: offsetX + this.common.tileWidth,
        y: (offsetY - offsetZ) + this.common.tileHeight - (this.common.tileHeight / 2)
      },
      bottom: {
        x: offsetX + (this.common.tileWidth / 2),
        y: (offsetY - offsetZ) + this.common.tileHeight
      },
      left: {
        x: offsetX,
        y: (offsetY - offsetZ) + this.common.tileHeight - (this.common.tileHeight / 2)
      },
      center: {
        x: offsetX + (this.common.tileWidth / 2),
        y: (offsetY - offsetZ) - (this.common.tileHeight / 2)
      }
    }
  }

  create () {
    //if (this.heightmap) this.heightmap.create();
    if (this.water) this.water.create();
    if (this.terrain) this.terrain.create();
    if (this.road) this.road.create();
    if (this.power) this.power.create();
    if (this.rail) this.rail.create();
    if (this.zone) this.zone.create();
    if (this.building) this.building.create();
    if (this.highway) this.highway.create();
    //if (this.subway) this.subway.create();
    //if (this.pipes) this.pipes.create();

    this.setInteraction();

    this.initialized = true;
  }

  setDepth (depth) {
    this.depth = depth;

    // todo: code to look at each sprite and set depth
  }

  sleep () {
    this.sleeping = true;
    this.sprites.forEach((sprite) => {
      sprite.setVisible(false);
      sprite.setActive(false);
    });

    this.hitbox.setActive(false);
  }

  wake () {
    this.sleeping = false;
    this.sprites.forEach((sprite) => {
      sprite.setVisible(true);
      sprite.setActive(true);
    });

    this.hitbox.setActive(true);
  }

  addSprite (sprite) {
    this.sprites.push(sprite);
  }

  getSprites () {
    return this.sprites;
  }

  getTopSprite () {
    return this.sprites[0];
  }

  clearSprites () {
    this.sprites = [];
  }

  addTile (tile) {
    this.tiles.push(tile);
  }

  getTiles () {
    return this.tiles;
  }

  getTopTile () {
    return this.tiles[0];
  }

  clearTiles () {
    this.tiles = [];
  }

  setInteraction () {
    let debugOutline = false;
    let debugHitbox = false;

    let x = 0;
    let y = 0;
    let offset = 0;
    let sprites;
    let hitbox;
    let tile;

    if
      (this.water && this.properties.waterLevel != 'dry') tile = this.water;
    else if
      (this.terrain && this.properties.waterLevel == 'dry') tile = this.terrain;
    else if
      (!this.water && !this.terrain && this.road) tile = this.road;
    else
      return;

    if (!tile.tile)
      return;

    if ((this.properties.waterLevel == 'submerged' || this.properties.waterLevel == 'shore') && this.z < this.scene.city.waterLevel)
      offset = ((this.scene.city.waterLevel - this.z) * this.common.layerOffset);

    if (tile.tileId != 256 && tile.type == 'terrain')
      offset += this.common.layerOffset;

    x = this.position.right.x - (this.common.tileWidth / 2) << 0;
    y = this.position.bottom.y - (this.common.tileHeight) - offset << 0;

    if (debugHitbox || debugOutline)
      hitbox = this.scene.add.graphics({ x: x, y: y });
    else
      hitbox = this.scene.add.zone(x, y, this.common.tileWidth, this.common.tileHeight);

    hitbox.on('pointerover', function (event, pointX, pointY) {
      sprites = this.cell.getSprites();

      sprites.forEach((sprite) => {
        sprite.setTint(0xaa0000);
      });
    });

    hitbox.on('pointerout', function (event) {
      sprites = this.cell.getSprites();

      sprites.forEach((sprite) => {
        sprite.clearTint();
      });
    });

    hitbox.on('pointermove', function (event, pointX, pointY) {
      return;
    });

    hitbox.on('pointerdown', function (event, pointX, pointY, camera) {
      console.log(this.cell);
    });

    hitbox.setInteractive(tile.tile.hitbox, Phaser.Geom.Polygon.Contains);
    hitbox.setDepth(this.depth + 1);
    hitbox.cell = this;
    
    if (debugOutline)
      tile.drawOutline(hitbox);

    if (debugHitbox)
      tile.drawOutline(hitbox, 'hitbox');

    this.hitbox = hitbox;
  }


  getTerrainTileId () {
    if (!this.terrain)
      return 0;

    return this.terrain.tileId;
  }


  getTerrain () {
    if (!this.terrain)
      return;

    return this.terrain;
  }


  setTerrain (tileId) {
    this.terrain = new terrain({
      scene: this.scene,
      tileId: tileId,
      cell: this
    });
  }


  getWaterTileId () {
    if (!this.water)
      return 0;

    return this.water.tileId;
  }


  getWater () {
    if (!this.water)
      return;

    return this.water;
  }


  setWater (tileId) {
    this.properties.waterCovered = true;

    this.water = new water({
      scene: this.scene,
      tileId: tileId,
      cell: this
    });
  }


  getZoneTileId () {
    if (!this.zone)
      return 0;

    return this.zone.tileId;
  }


  getZone () {
    if (!this.zone)
      return;

    return this.zone;
  }


  setZone (tileId) {
    this.zone = new zone({
      scene: this.scene,
      tileId: tileId,
      cell: this
    });
  }


  getRoadTileId () {
    if (!this.road)
      return 0;

    return this.road.tileId;
  }


  getRoad () {
    if (!this.road)
      return;

    return this.road;
  }


  setRoad (tileId) {
    this.properties.network = true;

    this.road = new road({
      scene: this.scene,
      tileId: tileId,
      cell: this
    });
  }


  getRailTileId () {
    if (!this.rail)
      return 0;

    return this.rail.tileId;
  }


  getRail () {
    if (!this.rail)
      return;

    return this.rail;
  }


  setRail (tileId) {
    this.properties.network = true;

    this.rail = new rail({
      scene: this.scene,
      tileId: tileId,
      cell: this
    });
    
  }


  getPowerTileId () {
    if (!this.power)
      return 0;

    return this.power.tileId;
  }


  getPower () {
    if (!this.power)
      return;

    return this.power;
  }


  setPower (tileId) {
    // mark cell as power conductive
    this.properties.conductive = true;

    this.power = new power({
      scene: this.scene,
      tileId: tileId,
      cell: this
    });

  }


  getHighwayTileId () {
    if (!this.highway)
      return 0;

    return this.highway.tileId;
  }


  getHighway () {
    if (!this.highway)
      return;

    return this.highway;
  }


  setHighway (tileId) {
    this.properties.network = true;

    this.highway = new highway({
      scene: this.scene,
      tileId: tileId,
      cell: this
    });
  }


  getHeightmapTileId () {
    if (!this.heightmap)
      return 0;

    return this.heightmap.tileId;
  }


  getHeightmap () {
    if (!this.heightmap)
      return;

    return this.heightmap;
  }


  setHeightmap (tileId) {
    this.heightmap = new heightmap({
      scene: this.scene,
      tileId: tileId,
      cell: this
    });
  }


  getSubwayTileId () {
    if (!this.subway)
      return 0;

    return this.subway.tileId;
  }


  getSubway () {
    if (!this.subway)
      return;

    return this.subway;
  }


  setSubway (tileId) {
    this.properties.subway = true;

    if ([108,109,110,111].includes(tileId))
      this.properties.subwayStation = true;

    this.subway = new subway({
      scene: this.scene,
      tileId: tileId,
      cell: this
    });
  }


  getPipesTileId () {
    if (!this.pipes)
      return 0;

    return this.pipes.tileId;
  }


  getPipes () {
    if (!this.pipes)
      return;

    return this.pipes;
  }


  setPipes (tileId) {
    this.properties.piped = true;

    this.pipes = new pipes({
      scene: this.scene,
      tileId: tileId,
      cell: this
    });
  }


  getBuildingTileId () {
    if (!this.building)
      return 0;

    return this.building.tileId;
  }


  getBuilding () {
    if (!this.building)
      return;

    return this.building;
  }


  setBuilding (tileId) {
    this.building = new building({
      scene: this.scene,
      tileId: tileId,
      cell: this
    });
  }

}

export default cell;