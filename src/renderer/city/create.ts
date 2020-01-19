import { load } from './load';
import { register } from './register';
import City from 'City';
import Grid from 'Grid';

export async function create(this: City) {
  register();

  await load('assets/cities/capequest.sc2');
  //await load('assets/cities/CHICAGO.SCN');

  this.grid = new Grid();

  await this.grid.create();
}
