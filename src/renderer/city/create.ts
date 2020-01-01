import { load } from './load';
import { register } from './register';
import sc2 from 'sc2';

export async function create() {
  register();

  await load('assets/cities/CAPEQUES.SC2');

  console.log(sc2.data);
}
