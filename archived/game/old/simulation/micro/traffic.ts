import simulation from './simulation';

export default class traffic extends simulation {
  constructor (options) {
    super(options);

    this.current = 0;
    this.average = 0;
    this.maximum = 0;

    this.lightThreshold = 86;
    this.heavyThreshold = 172;
  }

  create () {
    if (this.cell.data._XTRF > 0)
      this.current = this.cell.data._XTRF;
    else
      this.current = 0;
  }

  getTrafficDensity () {
    if (this.current < this.lightThreshold)
      return null;

    if (this.current >= this.lightThreshold && this.current < this.heavyThreshold)
      return 'light';

    if (this.current >= this.heavyThreshold)
      return 'heavy';
  }
}