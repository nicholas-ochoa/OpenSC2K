import Grid from 'Grid';
import { create } from './create';

export default class City {
  public create;
  public grid: Grid;

  public waterLevel: number;

  constructor() {

    this.create = create;
  }
}
