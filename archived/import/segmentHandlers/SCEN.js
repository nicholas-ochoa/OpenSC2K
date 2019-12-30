export default (data, map) => {
  let scen = {};

  scen.disaster = {
    disasterType: new DataView(data.slice(4, 6).buffer).getUint16(0),
    disasterX:    new DataView(data.slice(6, 7).buffer).getUint8(0),
    disasterY:    new DataView(data.slice(7, 8).buffer).getUint8(0),
  };

  scen.timeLimitMonths = new DataView(data.slice(8, 10).buffer).getUint16(0);

  scen.populationGoals = {
    city:        new DataView(data.slice(10, 14).buffer).getUint32(0),
    residential: new DataView(data.slice(14, 18).buffer).getUint32(0),
    commercial:  new DataView(data.slice(18, 22).buffer).getUint32(0),
    industrial:  new DataView(data.slice(22, 26).buffer).getUint32(0),
  };

  scen.fundGoal        = new DataView(data.slice(26, 30).buffer).getUint32(0);
  scen.landValueGoal   = new DataView(data.slice(30, 34).buffer).getUint32(0);
  scen.educationGoal   = new DataView(data.slice(34, 38).buffer).getUint32(0);
  scen.pollutionLimit  = new DataView(data.slice(38, 42).buffer).getUint32(0);
  scen.crimeLimit      = new DataView(data.slice(42, 46).buffer).getUint32(0);
  scen.trafficLimit    = new DataView(data.slice(46, 50).buffer).getUint32(0);

  scen.buildItem1      = new DataView(data.slice(50, 51).buffer).getUint8(0);
  scen.buildItem2      = new DataView(data.slice(51, 52).buffer).getUint8(0);

  if (data.byteLength > 52) {
    scen.item1Tiles      = new DataView(data.slice(52, 54).buffer).getUint16(0);
    scen.item2Tiles      = new DataView(data.slice(54, 56).buffer).getUint16(0);
  }

  scen.raw = data;

  map._segmentData.SCEN = scen;
};