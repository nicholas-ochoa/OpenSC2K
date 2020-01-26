import { data } from '../data';

export function SCEN(bytes: Buffer) {
  const scen: any = {};
  // let offset = 0;

  // scen.disaster = {
  //   type: bytes.readUInt16BE(offset += 2),
  //   x: bytes.readUInt8(offset += 1),
  //   y: bytes.readUInt8(offset += 1),
  // };

  // scen.timeLimitMonths = bytes.readUInt16BE(offset += 2);

  // scen.populationGoals = {
  //   city: bytes.readUInt32BE(offset += 4),
  //   residential: bytes.readUInt32BE(offset += 4),
  //   commercial: bytes.readUInt32BE(offset += 4),
  //   industrial: bytes.readUInt32BE(offset += 4),
  // };

  // scen.fundGoal = bytes.readUInt32BE(offset += 4);
  // scen.landValueGoal = bytes.readUInt32BE(offset += 4);
  // scen.educationGoal = bytes.readUInt32BE(offset += 4);
  // scen.pollutionLimit = bytes.readUInt32BE(offset += 4);
  // scen.crimeLimit = bytes.readUInt32BE(offset += 4);
  // scen.trafficLimit = bytes.readUInt32BE(offset += 4);

  // scen.buildItem1 = bytes.readUInt8(offset += 1);
  // scen.buildItem2 = bytes.readUInt8(offset += 1);

  // if (bytes.byteLength > 52) {
  //   scen.item1Tiles = bytes.readUInt16BE(offset += 2);
  //   scen.item2Tiles = bytes.readUInt16BE(offset += 2);
  // }

  data.segments.SCEN = scen;
}
