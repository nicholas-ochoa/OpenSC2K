import tile from './tile';
import * as CONST from '../../constants';

export default class pipe extends tile {
  constructor (options) {
    options.type = CONST.T_PIPE;
    options.layerDepth = CONST.DEPTH_PIPE;
    super(options);
  }

  check () {
    if (!super.check()) return false;

    if (![334,335,336,337,338,339,340,341,342,343,344,345,346,347,
      348,349,350,351,451,452,453,454,455,456,457,458,459,460,
      461,462,463,464,465,466,467].includes(this.id))
      return false;

    return true;
  }

  create () {
    super.create();

    if (this.sprite) this.sprite.setVisible(false); // hidden by default
  }
}