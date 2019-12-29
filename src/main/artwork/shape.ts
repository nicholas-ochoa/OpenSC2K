import { polygonUnion } from 'utils';
import tiles from 'tiles';

// converts x/y data array to a Phaser polygon
export function shape(hitbox) {
  const polygon = [];

  if (hitbox.reference) {
    hitbox = tiles.data[hitbox.reference].hitbox ?? tiles.data[hitbox.reference].heightmap;
  }

  // merge all sides of the shape into a single array of points
  let shape = [].concat(
    hitbox.lower ? hitbox.lower : [],
    hitbox.upper ? hitbox.upper : [],
    hitbox.south ? hitbox.south : [],
    hitbox.east ? hitbox.east : [],
    hitbox.west ? hitbox.west : [],
    hitbox.southEast ? hitbox.southEast : [],
    hitbox.southWest ? hitbox.southWest : [],
    hitbox.northEast ? hitbox.northEast : [],
    hitbox.northWest ? hitbox.northWest : [],
    hitbox.rockTop ? hitbox.rockTop : [],
    hitbox.rockSouthWest ? hitbox.rockSouthWest : [],
    hitbox.rockSouthEast ? hitbox.rockSouthEast : []
  );

  // combine into a single polygon with an exterior wall
  shape = polygonUnion(shape, shape);

  for (let i = 0; i < shape.length; i++) {
    polygon.push([shape[i].x, shape[i].y]);
  }

  return polygon;
}
