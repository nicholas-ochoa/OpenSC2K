import { load } from './load';
import { register } from './register';
import City from 'City';
import Grid from 'Grid';

export async function create(this: City) {
  register();

  await load('assets/cities/CAPEQUES.SC2');

  this.grid = new Grid();

  await this.grid.create();
}
