import Phaser from 'phaser';
import tileData from './tiles/data';
import utils from './common/utils';
import common from './common/common';
import localforage from 'localforage';
import saveCity from './city/saveCity';
import importCity from './import/importCity';

class load extends Phaser.Scene {
  constructor () {
    super({ key: 'load' });

    this.initialized = false;
  }


  preload () {
    if (!this.sys.game.common)
      this.sys.game.common = common();

    this.common = this.sys.game.common;

    //this.sys.game.storage = localforage.createInstance({
    //  name: "OpenSC2K"
    //});

    this.load.atlas(this.sys.game.common.tilemap, 'assets/tiles/tilemap_0.png', 'assets/tiles/tilemap_0.json');
  }


  create () {
    if (this.initialized) {
      this.reload();
      return;
    }

    this.loadTiles();
    this.initialized = true;
    this.common.load = this;
    this.scene.switch('title');
  }


  reload () {
    this.scene.start('world');
  }


  saveCity () {
    let exp = new saveCity({ scene: this });
    exp.export();
  }


  loadCity () {
    let imp = new importCity({ scene: this });
    imp.openFile();
  }
  

  loadTiles () {
    for (let i = 0; i < tileData.length; i++) {
      let firstTexture;
      let textures = [];
      let tile = {};
      let data = tileData[i];

      if (!['terrain', 'water', 'road', 'power', 'rail', 'zone', 'building', 'highway'].includes(data.type))
        continue;

      if (data.frames === 0)
        textures[0] = data.image + '_0';
      else
        for (let f = 0; f < data.frames; f++)
          textures[f] = data.image + '_' + f;

      // grab the first frame to get width/height
      firstTexture = this.textures.getFrame(this.sys.game.common.tilemap, textures[0]);

      tile = {
        id:                     data.id,
        animated:               (data.frames > 0 ? true : false),
        animationDelay:         data.animationDelay || 0,
        bridge:                 data.bridge,
        canRotate:              data.canRotate || false,
        depthModifier:          data.depthModifier || 0,
        description:            data.description,
        flip:                   data.flip,
        flipMode:               data.flipMode,
        frames:                 data.frames,
        height:                 (firstTexture.height * this.sys.game.common.scale),
        imageName:              data.image,
        lines:                  data.lines,
        logic:                  data.logic || false,
        name:                   data.name,
        hitbox:                 data.hitbox || new Phaser.Geom.Polygon([new Phaser.Geom.Point(0, 0), new Phaser.Geom.Point(32, 16), new Phaser.Geom.Point(0, 32), new Phaser.Geom.Point(-32, 16), new Phaser.Geom.Point(0, 0)]),
        outline:                data.outline || new Phaser.Geom.Polygon([new Phaser.Geom.Point(0, 0), new Phaser.Geom.Point(32, 16), new Phaser.Geom.Point(0, 32), new Phaser.Geom.Point(-32, 16), new Phaser.Geom.Point(0, 0)]),
        requiresTerrainLayer:   data.requiresTerrainLayer,
        rotate:                 data.rotate,
        size:                   data.size,
        subtype:                data.subtype,
        textures:               textures,
        tunnel:                 data.tunnel,
        type:                   data.type,
        width:                  (firstTexture.width * this.sys.game.common.scale),
      }

      if (tile.animated) {
        // delay water tiles so they're not in perfect sync
        // with all other animations
        // todo: might make this a per-tile setting instead
        this.anims.create({
          key: data.image,
          frames: this.anims.generateFrameNames(this.sys.game.common.tilemap, { prefix: data.image+'_', end: data.frames }),
          repeat: -1,
          frameRate: 2,
          delay: tile.animationDelay
        });
      }

      this.sys.game.common.tiles[data.id] = tile;
    }
  }
}

export default load;