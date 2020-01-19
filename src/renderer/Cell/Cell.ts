import City from 'City';
import Position from './Position';

export default class {
  #data;
  public city: City;
  public position: Position;
  //public surrounding: Surrounding;

  constructor(options) {
    this.#data = options.data;

    this.position = new Position({ cell: this, data: this.#data });
    //this.surrounding = new Surrounding({ cell: this });
  }
}
