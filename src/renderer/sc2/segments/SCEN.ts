import { data } from '../data';

export function SCEN(bytes: Buffer) {
  const scen: any = {};

  scen.disaster = {
    type: bytes.readUInt16BE(0x04),
    x: bytes.readUInt8(0x06),
    y: bytes.readUInt8(0x07),
  };

  scen.timeLimitMonths = bytes.readUInt16BE(8);

  scen.populationGoals = {
    city: bytes.readUInt32BE(10),
    residential: bytes.readUInt32BE(14),
    commercial: bytes.readUInt32BE(18),
    industrial: bytes.readUInt32BE(22),
  };

  scen.fundGoal = bytes.readUInt32BE(26);
  scen.landValueGoal = bytes.readUInt32BE(30);
  scen.educationGoal = bytes.readUInt32BE(34);
  scen.pollutionLimit = bytes.readUInt32BE(38);
  scen.crimeLimit = bytes.readUInt32BE(42);
  scen.trafficLimit = bytes.readUInt32BE(46);

  scen.buildItem1 = bytes.readUInt8(50);
  scen.buildItem2 = bytes.readUInt8(51);

  if (bytes.byteLength > 52) {
    scen.item1Tiles = bytes.readUInt16BE(52);
    scen.item2Tiles = bytes.readUInt16BE(54);
  }

  data.segments.SCEN = scen;
}
