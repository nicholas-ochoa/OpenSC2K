import jszip from 'jszip';
import fileSaver from 'file-saver';

class saveCity {
  constructor (options) {
    this.scene = options.scene;
    this.common = this.scene.sys.game.common;
    this.city = this.scene.city;
  }

  export () {
    this.data = {
      info: {
        name: this.city.name,
        rotation: this.city.rotation,
        waterLevel: this.city.waterLevel,
        width: this.city.width,
        height: this.city.height,
      },
      cells: []
    };
    this.createCellList();
    this.downloadSave();
  }

  createCellList () {
    for (let x = 0; x < this.city.width; x++) {
      for (let y = 0; y < this.city.height; y++) {
        let mapCell = this.city.map.getCell(x, y);
        let cell = {
          x: mapCell.x,
          y: mapCell.y,
          z: mapCell.z,
          importedData: mapCell.importedData,
          properties: mapCell.properties,
          tiles: {
            building: mapCell.getBuildingTileId(),
            zone: mapCell.getZoneTileId(),
            water: mapCell.getWaterTileId(),
            road: mapCell.getRoadTileId(),
            rail: mapCell.getRailTileId(),
            power: mapCell.getPowerTileId(),
            highway: mapCell.getHighwayTileId(),
            terrain: mapCell.getTerrainTileId(),
            heightmap: mapCell.getHeightmapTileId(),
            subway: mapCell.getSubwayTileId(),
            pipes: mapCell.getPipesTileId(),
          }
        };

        this.data.cells.push(cell);
      }
    }
  }

  downloadSave () {
    let json = JSON.stringify(this.data);
    let zip = new jszip();
    let options = {
      type: 'blob',
      compression: 'DEFLATE',
      compressionOptions: {
        level: 9
      }
    };

    zip.file('data.json', json);
    zip.generateAsync(options).then((content) => {
      fileSaver.saveAs(content, this.data.info.name + '.opensc2k');
    });
  }
}

export default saveCity;