import tile from './tiles';

class terrain extends tile {
  constructor (options) {
    super(options);

    this.type = 'terrain';
    this.depth = -32;
  }

  checkTile () {
    if (!super.checkTile())
      return false;

    if (![256,257,258,259,260,261,262,263,264,265,266,267,268,269].includes(this.tileId))
      return false;

    if (this.cell.getProperty('waterLevel') != 'dry')
      return false;

    return true;
  }

  create () {
    if (this.cell.hasBuilding() && !this.cell.building.tile.requiresTerrainLayer)
      return false;
      
    super.create();
  }
}

export default terrain;