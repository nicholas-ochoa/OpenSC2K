import 'source-map-support/register';
import tiles from 'tiles';
import palette from 'palette';
import artwork from 'artwork';
import sc2 from 'sc2';
import { config } from 'utils';

config.load();
tiles.load();
palette.load();
artwork.load();
sc2.load();
