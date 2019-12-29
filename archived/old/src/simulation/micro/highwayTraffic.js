import traffic from './traffic';

export default class highwayTraffic extends traffic {
  constructor (options) {
    super(options);

    this.lightThreshold = 30;
    this.heavyThreshold = 58;
    this.trafficDirection = null;
  }

  
  // determine traffic direction
  calculateTrafficDirection () {
    if (this.cell.highway.onramp)
      console.log('onramp');

    let cells = this.cell.surrounding();
    
    // north / south highways
    if (this.cell.highway.tile.direction == 'ns' && !this.cell.highway.onramp)
      if (!cells.e.highway && cells.w.highway && !cells.w.highway.onramp)
        this.trafficDirection = 'nb';
      else if (!cells.w.highway && cells.e.highway && !cells.e.highway.onramp)
        this.trafficDirection = 'sb';
      else if (cells.e.highway && cells.w.highway && !cells.w.highway.onramp)
        this.trafficDirection = 'nb';
      else if (cells.w.highway && cells.e.highway && !cells.e.highway.onramp)
        this.trafficDirection = 'sb';

    // east / west highways
    if (this.cell.highway.tile.direction == 'ew' && !this.cell.highway.onramp)
      if (!cells.s.highway && cells.n.highway && !cells.n.highway.onramp)
        this.trafficDirection = 'eb';
      else if (!cells.n.highway && cells.s.highway && !cells.s.highway.onramp)
        this.trafficDirection = 'wb';
      else if (cells.s.highway && cells.n.highway && !cells.n.highway.onramp)
        this.trafficDirection = 'eb';
      else if (cells.n.highway && cells.s.highway && !cells.s.highway.onramp)
        this.trafficDirection = 'wb';

    // north / south onramps
    if (this.cell.highway.onramp && cells.n.highway.tile.direction == 'ew')
      this.trafficDirection = 'wb';

    if (this.cell.highway.onramp && cells.w.highway.tile.direction == 'ns')
      this.trafficDirection = 'sb';


    if (['nb','wb'].includes(this.trafficDirection))
      this.cell.highway.reverseAnimation = false;
    else
      this.cell.highway.reverseAnimation = true;

    return this.cell.highway.reverseAnimation;
  }
}