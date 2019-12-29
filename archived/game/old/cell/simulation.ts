import traffic from '../simulation/micro/traffic';
import highwayTraffic from '../simulation/micro/highwayTraffic';

export default class simulation {
  constructor (options) {
    this.cell        = options.cell;
    this.simulations = {};
  }

  create () {
    if (this.cell.road)
      this.simulators.traffic = new traffic({ cell: this.cell });

    if (this.cell.highway)
      this.simulators.highwayTraffic = new highwayTraffic({ cell: this.cell });

    Object.keys(this.simulators).forEach((sim) => {
      this.simulations[sim].create();
    });
  }

  update () {
    Object.keys(this.simulations).forEach((sim) => {
      this.simulations[sim].update();
    });
  }
}