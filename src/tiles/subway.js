import tile from './tiles';

class subway extends tile {
  constructor (options) {
    super(options);

    this.type = 'subway';
    this.depth = -50;
  }

  checkTile () {
    if (!super.checkTile())
      return false;

    if (![319,320,321,322,323,324,325,326,327,328,329,330,331,332,
          333,349,350,465,466,108,109,110,111].includes(this.tileId))
      return false;

    return true;
  }

  create () {
    super.create();

    if (this.sprite)
      this.sprite.setVisible(false); // hidden by default
  }
}

export default subway;