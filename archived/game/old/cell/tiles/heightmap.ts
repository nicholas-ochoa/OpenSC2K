import tile from './tile';
import Phaser from 'phaser';
import * as CONST from '../../constants';

export default class heightmap extends tile {
  constructor (options) {
    options.type = CONST.T_HEIGHTMAP;
    options.layerDepth = CONST.DEPTH_HEIGHTMAP;
    super(options);
    
    this.polygon = [];
  }

  get (id) {
    let tile = super.get(id);

    if (tile.heightmap && tile.heightmap.reference) {
      tile = super.get(tile.heightmap.reference);
      this.id = tile.id;
    }

    return tile;
  }

  check () {
    if (!super.check())
      return false;

    if (![256,257,258,259,260,261,262,263,264,265,266,267,268,269].includes(this.id)) return false;

    return true;
  }

  position () {
    this.x = this.cell.position.bottom.x - (this.tile.width / 2);
    this.y = this.cell.position.bottom.y - (this.tile.height) - CONST.TILE_HEIGHT;
  }

  hide () {
    this.polygon.forEach((face) => {
      face.setVisible(false);
    });
  }

  show () {
    this.polygon.forEach((face) => {
      face.setVisible(true);
    });
  }

  create () {
    if (!this.props.draw || !this.cell.scene.tiles[this.id].heightmap) return;

    let heightmap = this.cell.scene.tiles[this.id].heightmap;
    
    this.position();

    // colors
    let baseColor      = Phaser.Display.Color.ObjectToColor(this.color(this.cell.z));
    let baseColorUpper = Phaser.Display.Color.ObjectToColor(this.color(this.cell.z + 1));
    let alpha          = 1;

    let strokeColor = baseColor.clone().darken(60).color;

    let lower     = baseColor.clone().color;
    let upper     = baseColorUpper.clone().color;

    let south     = baseColor.clone().darken(10).color;
    let east      = baseColor.clone().darken(20).color;
    let west      = baseColor.clone().darken(30).color;

    let southEast = baseColor.clone().lighten(10).color;
    let southWest = baseColor.clone().darken(25).color;
    let northEast = baseColor.clone().darken(40).color;
    let northWest = baseColor.clone().darken(40).color;

    // rock faces
    let rockTop       = baseColor.clone().color;
    let rockSouthWest = baseColor.clone().darken(50).color;
    let rockSouthEast = baseColor.clone().darken(50).color;

    // polygons
    if (heightmap.upper)         this.polygon.push(this.cell.scene.add.polygon(this.x, this.y, heightmap.upper,         upper,         alpha));
    if (heightmap.lower)         this.polygon.push(this.cell.scene.add.polygon(this.x, this.y, heightmap.lower,         lower,         alpha));
    if (heightmap.south)         this.polygon.push(this.cell.scene.add.polygon(this.x, this.y, heightmap.south,         south,         alpha));
    if (heightmap.east)          this.polygon.push(this.cell.scene.add.polygon(this.x, this.y, heightmap.east,          east,          alpha));
    if (heightmap.west)          this.polygon.push(this.cell.scene.add.polygon(this.x, this.y, heightmap.west,          west,          alpha));
    if (heightmap.southEast)     this.polygon.push(this.cell.scene.add.polygon(this.x, this.y, heightmap.southEast,     southEast,     alpha));
    if (heightmap.southWest)     this.polygon.push(this.cell.scene.add.polygon(this.x, this.y, heightmap.southWest,     southWest,     alpha));
    if (heightmap.northEast)     this.polygon.push(this.cell.scene.add.polygon(this.x, this.y, heightmap.northEast,     northEast,     alpha));
    if (heightmap.northWest)     this.polygon.push(this.cell.scene.add.polygon(this.x, this.y, heightmap.northWest,     northWest,     alpha));
    if (heightmap.rockTop)       this.polygon.push(this.cell.scene.add.polygon(this.x, this.y, heightmap.rockTop,       rockTop,       alpha));
    if (heightmap.rockSouthWest) this.polygon.push(this.cell.scene.add.polygon(this.x, this.y, heightmap.rockSouthWest, rockSouthWest, alpha));
    if (heightmap.rockSouthEast) this.polygon.push(this.cell.scene.add.polygon(this.x, this.y, heightmap.rockSouthEast, rockSouthEast, alpha));

    // polygon attributes
    this.polygon.forEach((face) => {
      face.setStrokeStyle(1, strokeColor, alpha);
      face.setScale(CONST.SCALE);
      face.setOrigin(0,0);
      face.setDepth(this.depth);
      face.setVisible(false);
    });
  }


  color (height) {
    if (height > 31)
      height = 31;

    if (height < 0)
      height = 0;

    let terrain = [];
    terrain[0]  = { r: 0,   g: 4,   b: 255, a: 1 };
    terrain[1]  = { r: 0,   g: 37,  b: 255, a: 1 };
    terrain[2]  = { r: 0,   g: 68,  b: 255, a: 1 };
    terrain[3]  = { r: 0,   g: 99,  b: 255, a: 1 };
    terrain[4]  = { r: 0,   g: 131, b: 255, a: 1 };
    terrain[5]  = { r: 0,   g: 163, b: 255, a: 1 };
    terrain[6]  = { r: 0,   g: 195, b: 255, a: 1 };
    terrain[7]  = { r: 3,   g: 227, b: 255, a: 1 };
    terrain[8]  = { r: 0,   g: 255, b: 251, a: 1 };
    terrain[9]  = { r: 9,   g: 255, b: 219, a: 1 };
    terrain[10] = { r: 11,  g: 255, b: 187, a: 1 };
    terrain[11] = { r: 12,  g: 255, b: 155, a: 1 };
    terrain[12] = { r: 14,  g: 255, b: 123, a: 1 };
    terrain[13] = { r: 14,  g: 255, b: 91,  a: 1 };
    terrain[14] = { r: 16,  g: 255, b: 58,  a: 1 };
    terrain[15] = { r: 16,  g: 255, b: 25,  a: 1 };
    terrain[16] = { r: 19,  g: 255, b: 0,   a: 1 };
    terrain[17] = { r: 41,  g: 255, b: 0,   a: 1 };
    terrain[18] = { r: 70,  g: 255, b: 0,   a: 1 };
    terrain[19] = { r: 101, g: 255, b: 0,   a: 1 };
    terrain[20] = { r: 132, g: 255, b: 0,   a: 1 };
    terrain[21] = { r: 164, g: 255, b: 0,   a: 1 };
    terrain[22] = { r: 195, g: 255, b: 0,   a: 1 };
    terrain[23] = { r: 227, g: 255, b: 0,   a: 1 };
    terrain[24] = { r: 255, g: 251, b: 0,   a: 1 };
    terrain[25] = { r: 255, g: 219, b: 0,   a: 1 };
    terrain[26] = { r: 255, g: 187, b: 0,   a: 1 };
    terrain[27] = { r: 255, g: 155, b: 0,   a: 1 };
    terrain[28] = { r: 255, g: 123, b: 0,   a: 1 };
    terrain[29] = { r: 255, g: 91,  b: 0,   a: 1 };
    terrain[30] = { r: 255, g: 59,  b: 0,   a: 1 };
    terrain[31] = { r: 255, g: 26,  b: 0,   a: 1 };
    
    return terrain[height];
  }
}