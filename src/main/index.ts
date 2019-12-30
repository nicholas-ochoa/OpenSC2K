import 'source-map-support/register';
import config from 'config';
import tiles from 'tiles';
import palette from 'palette';
import artwork from 'artwork';
import 'startup';

config.load();
tiles.load();
palette.load();
artwork.load();
