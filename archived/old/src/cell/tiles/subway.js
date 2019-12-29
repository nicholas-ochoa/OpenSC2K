import tile from './tile';

export default class subway extends tile {
  constructor (options) {
    options.type = CONST.T_SUBWAY;
    options.layerDepth = CONST.DEPTH_SUBWAY;
    super(options);
  }

  check () {
    if (!super.check())
      return false;

    if (![319,320,321,322,323,324,325,326,327,328,329,330,331,332,333,349,350,352,353].includes(this.id))
      return false;

    return true;
  }

  position () {
    this.x = this.cell.position.topLeft.x - (this.tile.width / 2) << 0;
    this.y = this.cell.position.topLeft.y - (this.tile.height) - this.offset << 0;
  }
  
  create () {
    super.create();

    if (this.sprite)
      this.sprite.setVisible(false); // hidden by default
  }
}