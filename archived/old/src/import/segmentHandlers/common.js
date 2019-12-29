//
// resize a bitmap data array using nearest neighbor algorithm
//
function resize(data, sourceSize, destSize) {
  let resizedData = [];

  for (let i = 0; i < destSize; i++) {
    for (let j = 0; j < destSize; j++) {
      let x = Math.floor(j * sourceSize / destSize);
      let y = Math.floor(i * sourceSize / destSize);

      resizedData[(i * destSize + j)] = data[(y * sourceSize + x)];
    }
  }

  return resizedData;
}


//
// converts byte array to an ascii string
//
function bytesToAscii(bytes) {
  return Array.prototype.map.call(bytes, x => String.fromCharCode(x)).join('');
}


//
// converts numeric values to a base2 string of specified length
//
function bin2str(bin, length) {
  return bin.toString(2).padStart(length, '0');
}

export { resize, bytesToAscii, bin2str };