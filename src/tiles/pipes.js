import tile from './tiles';

class pipe extends tile {
  constructor (options) {
    super(options);

    this.type = 'pipe';
    this.depth = this.depth - 0;
  }

  checkTile () {
    if (!super.checkTile())
      return false;

    if (![334,335,336,337,338,339,340,341,342,343,344,345,346,347,
          348,349,350,351,451,452,453,454,455,456,457,458,459,460,
          461,462,463,464,465,466,467].includes(this.tileId))
      return false;

    return true;
  }
}

export default pipe;