import tile from './tile';
import * as CONST from '../../constants';

export default class edge extends tile {
  constructor (options) {
    options.type = CONST.T_EDGE;
    options.layerDepth = CONST.DEPTH_EDGE;
    super(options);
  }


  check () {
    if (!super.check()) return false;

    if (this.cell.x != 127 && this.cell.y != 127) return false;

    return true;
  }


  hide (type) {
    if (this.sprite.length > 0) {
      this.sprite.forEach((sprite) => {
        if (!sprite.visible || (type && sprite.subtype != type)) return;

        sprite.setVisible(false);
      });
    }
  }


  show (type) {
    if (this.sprite.length > 0) {
      this.sprite.forEach((sprite) => {
        if (sprite.visible || (type && sprite.subtype != type)) return;

        sprite.setVisible(true);
      });
    }
  }


  calculatePosition () {
    this.x = this.cell.position.topLeft.x;
    this.y = this.cell.position.topLeft.y;

    if (this.cell.z < this.cell.scene.city.waterLevel && ([CONST.TERRAIN_SUBMERGED, CONST.TERRAIN_SHORE].includes(this.cell.water.type)))
      this.y -= this.cell.position.seaLevel;
  }


  create () {
    this.calculatePosition();

    let sprites = [];
    let waterDepth = this.cell.scene.city.waterLevel - this.cell.z;

    // water
    if (this.cell.water.type != CONST.TERRAIN_DRY) {
      for (let i = 0; i < waterDepth; i++) {
        let offset = Math.abs((CONST.LAYER_OFFSET * i) - this.cell.position.seaLevel);
        let sprite = this.cell.scene.add.sprite(this.x, this.y + offset, CONST.TILE_ATLAS).play(this.get(284).image);
        sprite.type = this.type;
        sprite.subtype = CONST.TERRAIN_WATER;
        sprite.cell = this.cell;
        sprite.setScale(CONST.SCALE);
        sprite.setOrigin(CONST.ORIGIN_X, CONST.ORIGIN_Y);
        sprite.setDepth(this.depth.cell + this.depth.layer + this.depth.tile + this.depth.additional + (i * 2));

        this.cell.tiles.addSprite(sprite, this.type);
        sprites.push(sprite);
      }
    }

    // bedrock
    for (let i = 0; i < this.cell.z; i++) {
      let offset = CONST.LAYER_OFFSET * (i + 1);

      if (this.cell.water.type != CONST.TERRAIN_DRY)
        offset = CONST.LAYER_OFFSET * (i + waterDepth + 1);

      let sprite = this.cell.scene.add.sprite(this.x, this.y + offset, CONST.TILE_ATLAS, this.get(269).textures[0]);
      sprite.type = this.type;
      sprite.subtype = CONST.TERRAIN_BEDROCK;
      sprite.cell = this.cell;
      sprite.setScale(CONST.SCALE);
      sprite.setOrigin(CONST.ORIGIN_X, CONST.ORIGIN_Y);
      sprite.setDepth(this.depth.cell + this.depth.layer + this.depth.tile + this.depth.additional + (this.cell.z - i * 2) - 32);

      this.cell.tiles.addSprite(sprite, this.type);
      sprites.push(sprite);
    }

    this.sprite = sprites;
  }
}