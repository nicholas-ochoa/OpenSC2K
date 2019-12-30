export default (data, map) => {
  let view = new DataView(data.buffer, data.byteOffset, data.byteLength);
  
  map._segmentData.XMIC = [];

  for (let i = 0; i < data.byteLength; i++) {
    let offset = i * 8;

    if (offset >= data.byteLength)
      break;

    let xmic = {};

    xmic.building = view.getUint8(offset);

    xmic.data1 = xmic.building == 0 ? 0 : view.getUint8(offset + 1);
    xmic.data2 = xmic.building == 0 ? 0 : view.getUint16(offset + 2);
    xmic.data3 = xmic.building == 0 ? 0 : view.getUint16(offset + 4);
    xmic.data4 = xmic.building == 0 ? 0 : view.getUint16(offset + 6);

    map._segmentData.XMIC.push(xmic);
  }
};