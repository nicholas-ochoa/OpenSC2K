import tile from './tiles';

class zone extends tile {
  constructor (options) {
    super(options);

    this.type = 'zone';
    this.depth = -10;
  }

  checkTile () {
    if (!super.checkTile())
      return false;

    if (![291,292,293,294,295,296,297,298,299].includes(this.tileId))
      return false;

    return true;
  }

  create () {
    if (this.cell.hasBuilding())
      return false;
      
    super.create();
  }
}

export default zone;