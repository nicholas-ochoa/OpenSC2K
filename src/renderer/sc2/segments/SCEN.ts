import { data } from '../data';

export function SCEN(bytes: any) {
  const scen: any = {};

  scen.disaster = {
    type: new DataView(bytes.slice(4, 6).buffer).getUint16(0),
    x: new DataView(bytes.slice(6, 7).buffer).getUint8(0),
    y: new DataView(bytes.slice(7, 8).buffer).getUint8(0),
  };

  scen.timeLimitMonths = new DataView(bytes.slice(8, 10).buffer).getUint16(0);

  scen.populationGoals = {
    city: new DataView(bytes.slice(10, 14).buffer).getUint32(0),
    residential: new DataView(bytes.slice(14, 18).buffer).getUint32(0),
    commercial: new DataView(bytes.slice(18, 22).buffer).getUint32(0),
    industrial: new DataView(bytes.slice(22, 26).buffer).getUint32(0),
  };

  scen.fundGoal = new DataView(bytes.slice(26, 30).buffer).getUint32(0);
  scen.landValueGoal = new DataView(bytes.slice(30, 34).buffer).getUint32(0);
  scen.educationGoal = new DataView(bytes.slice(34, 38).buffer).getUint32(0);
  scen.pollutionLimit = new DataView(bytes.slice(38, 42).buffer).getUint32(0);
  scen.crimeLimit = new DataView(bytes.slice(42, 46).buffer).getUint32(0);
  scen.trafficLimit = new DataView(bytes.slice(46, 50).buffer).getUint32(0);

  scen.buildItem1 = new DataView(bytes.slice(50, 51).buffer).getUint8(0);
  scen.buildItem2 = new DataView(bytes.slice(51, 52).buffer).getUint8(0);

  if (bytes.byteLength > 52) {
    scen.item1Tiles = new DataView(bytes.slice(52, 54).buffer).getUint16(0);
    scen.item2Tiles = new DataView(bytes.slice(54, 56).buffer).getUint16(0);
  }

  scen.raw = data;

  data.segments.SCEN = scen;
}
