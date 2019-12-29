// resize a bitmap data array using nearest neighbor algorithm
export function resize(data: any, sourceSize: number, destSize: number) {
  const resizedData: any = [];

  for (let i = 0; i < destSize; i++) {
    for (let j = 0; j < destSize; j++) {
      const x = Math.floor((j * sourceSize) / destSize);
      const y = Math.floor((i * sourceSize) / destSize);

      resizedData[i * destSize + j] = data[y * sourceSize + x];
    }
  }

  return resizedData;
}
