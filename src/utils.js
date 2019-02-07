//
//
//
function wrap (value, min, max) {
  if (value > max)
    value = min;

  if (value < min)
    value = max;

  return value;
}


//
//
//
function isNumberBetween (value, min, max) {
  return value >= min && value <= max;
}


//
// adapted from https://github.com/lovasoa/graham-fast
// licensed under the MIT license
//
function polygonUnion(poly1, poly2) {
  let points = [];

  for (let i = 0; i < poly1.length; i++)
    points.push([poly1[i].x, poly1[i].y]);

  for (let i = 0; i < poly2.length; i++)
    points.push([poly2[i].x, poly2[i].y]);

  // The enveloppe is the points themselves
  if (points.length <= 3)
    return points;
  
  // Find the pivot
  let pivot = points[0];

  for (let i = 0; i < points.length; i++)
    if (points[i][1] < pivot[1] || (points[i][1] === pivot[1] && points[i][0] < pivot[0]))
      pivot = points[i];

  // Attribute an angle to the points
  for (let i = 0; i < points.length; i++)
    points[i]._graham_angle = Math.atan2(points[i][1] - pivot[1], points[i][0] - pivot[0]);

  points.sort(function(a, b){
    return a._graham_angle === b._graham_angle ? a[0] - b[0] : a._graham_angle - b._graham_angle;
  });


  // Adding points to the result if they "turn left"
  let result = [points[0]];
  let len = 1;

  for (let i = 1; i < points.length; i++) {
    let a = result[len-2];
    let b = result[len-1];
    let c = points[i];

    while ((len === 1 && b[0] === c[0] && b[1] === c[1]) || (len > 1 && (b[0]-a[0]) * (c[1]-a[1]) <= (b[1]-a[1]) * (c[0]-a[0]))) {
      len--;
      b = a;
      a = result[len-2];
    }

    result[len++] = c;
  }

  result.length = len;
  
  // create new polygon object
  let polygon = [];

  for (let i = 0; i < result.length; i++)
    polygon.push({ x: result[i][0], y: result[i][1] });

  return polygon;
}

export { wrap, isNumberBetween, polygonUnion };