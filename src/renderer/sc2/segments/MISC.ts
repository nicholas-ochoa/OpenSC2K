import { data } from '../data';
import tiles from 'tiles';

export function MISC(bytes: Buffer) {
  // uncomment the console.log statement to work on this section
  // still very much a WIP
  // will optimize once all data structions are properties are identified properly

  let offset = 0;
  const misc: any = {};

  // 0 terrain edit, 1 city, 2 disaster
  misc.cityMode = bytes.readUInt32BE(offset += 4);
  // console.log('gameMode', misc.gameMode);

  // 0 through 3 corresponding to city rotation
  misc.rotation = bytes.readUInt32BE(offset += 4);
  // console.log('rotation', misc.rotation);

  // year the city was founded
  misc.baseYear = bytes.readUInt32BE(offset += 4);
  // console.log('baseYear', misc.baseYear);

  // days since city was founded.
  // 300 days per year, 12 months, 25 days per month
  misc.simCycle = bytes.readUInt32BE(offset += 4);
  // console.log('simCycle', misc.simCycle);

  // total money
  misc.totalFunds = bytes.readUInt32BE(offset += 4);
  // console.log('totalFunds', misc.totalFunds);

  // total number of bonds taken out
  // todo: does not work
  misc.totalBondCount = bytes.readUInt32BE(offset += 4);
  // console.log('totalBonds', misc.totalBonds);

  // starting difficulty
  misc.gameLevel = bytes.readUInt32BE(offset += 4);
  // console.log('gameLevel', misc.gameLevel);

  // reward tier obtained. 0 = none, 1 = mayor's mansion
  // 2 = city hall, 3 = statue, 4 = military
  // 5 = llama dome, 6 = arcos
  misc.cityStatus = bytes.readUInt32BE(offset += 4);
  // console.log('cityStatus', misc.cityStatus);

  // total city value (show bonds dialog)
  // multiply by 1,000 to get value shown in game
  misc.cityValue = bytes.readUInt32BE(offset += 4);
  // console.log('cityValue', misc.cityValue);

  // sum of all values in XVAL
  misc.landValue = bytes.readUInt32BE(offset += 4);
  // console.log('landValue', misc.landValue);

  // sum of all values in XCRM
  misc.crimeCount = bytes.readUInt32BE(offset += 4);
  // console.log('crimeCount', misc.crimeCount);

  // not a sum of XTRF values
  misc.trafficCount = bytes.readUInt32BE(offset += 4);
  // console.log('trafficCount', misc.trafficCount);

  // unknown
  misc.pollution = bytes.readUInt32BE(offset += 4);
  // console.log('pollution', misc.pollution);

  // unknown
  misc.cityFame = bytes.readUInt32BE(offset += 4);
  // console.log('cityFame', misc.cityFame);

  // unknown
  misc.advertising = bytes.readUInt32BE(offset += 4);
  // console.log('advertising', misc.advertising);

  // unknown
  misc.garbage = bytes.readUInt32BE(offset += 4);
  // console.log('garbage', misc.garbage);

  // percentage of population that is working
  misc.workerPercent = bytes.readUInt32BE(offset += 4);
  // console.log('workerPercent', misc.workerPercent);

  // work force life expectancy
  misc.workerHealth = bytes.readUInt32BE(offset += 4);
  // console.log('workerHealth', misc.workerHealth);

  // work force education quotient
  misc.workerEQ = bytes.readUInt32BE(offset += 4);
  // console.log('workerEQ', misc.workerEQ);

  // population of simnation
  // multiply by 1,000 to get value shown in game
  misc.nationalPopulation = bytes.readUInt32BE(offset += 4);
  // console.log('nationalPopulation', misc.nationalPopulation);

  // unknown
  misc.nationalValue = bytes.readUInt32BE(offset += 4);
  // console.log('nationalValue', misc.nationalValue);

  // unknown
  misc.nationalTax = bytes.readUInt32BE(offset += 4);
  // console.log('nationalTax', misc.nationalTax);

  // unknown
  misc.nationalTrend = bytes.readUInt32BE(offset += 4);
  // console.log('nationalTrend', misc.nationalTrend);

  // unknown, weather related
  misc.heat = bytes.readUInt32BE(offset += 4);
  // console.log('heat', misc.heat);

  // unknown, weather related
  misc.wind = bytes.readUInt32BE(offset += 4);
  // console.log('wind', misc.wind);

  // unknown, weather related
  misc.humid = bytes.readUInt32BE(offset += 4);
  // console.log('humid', misc.humid);

  // weather displayed in game on the status bar
  misc.weatherTrend = weatherTrends[bytes.readUInt32BE(offset += 4)];
  // console.log('weatherTrend', misc.weatherTrend);

  // currently active disaster
  misc.disaster = disasters[bytes.readUInt32BE(offset += 4)];
  // console.log('disaster', misc.disaster);

  // unknown
  misc.oldResidentialPopulation = bytes.readUInt32BE(offset += 4);
  // console.log('oldResidentialPopulation', misc.oldResidentialPopulation);

  // 0x000...0011111 where the last 5 bits represent:
  // 11111 = all, 00001 = mayor's only, 10000 = arco only
  misc.rewards = bytes.readUInt32BE(offset += 4);
  // console.log('rewards', misc.rewards);


  // graph data
  misc.graphs = {};
  misc.graphs.population = [];
  misc.graphs.health = [];
  misc.graphs.education = [];
  misc.graphs.industry = [];

  for (let i = 0; i < 20; i++) {
    // population graph
    misc.graphs.population[i] = {
      age: graphAgeRange[i],
      population: bytes.readUInt32BE(offset += 4),
    };

    // health - resident age graph, values unknown
    misc.graphs.health[i] = {
      age: graphAgeRange[i],
      value: bytes.readUInt32BE(offset += 4),
    };

    // education - resident age graph, values unknown
    misc.graphs.education[i] = {
      age: graphAgeRange[i],
      value: bytes.readUInt32BE(offset += 4),
    };
  }

  // console.log('graphs.population', misc.graphs.population);
  // console.log('graphs.health', misc.graphs.health);
  // console.log('graphs.education', misc.graphs.education);

  // ingame: city industry dialog
  // ratios: range 0 to 99?
  // tax rates: 0 to 10?
  // demand: 0 to 512?
  for (let i = 0; i < 11; i++) {
    const row = {};

    row.type = cityIndustries[i];
    row.ratios = bytes.readUInt32BE(offset += 4);
    row.taxRates = bytes.readUInt32BE(offset += 4);
    row.demand = bytes.readUInt32BE(offset += 4);

    misc.graphs.industry[i] = row;
  }

  // console.log('graphs.industry', misc.graphs.industry);

  // total counts of each tile type, index
  // by tile id from XBLD range 0 to 255
  misc.tileCounts = [];

  for (let i = 0; i < 256; i++) {
    misc.tileCounts[i] = {
      id: i,
      type: tiles.data[i]?.type,
      description: tiles.data[i]?.description,
      count: bytes.readUInt32BE(offset += 4),
    };
  }

  // console.log('tileCounts', misc.tileCounts);

  // population for each zone type
  // 0x00: populated tile count
  // 0x01: ^^^ part of this somehow?
  // 0x02: residential tile count
  // 0x03: ^^^ part of this somehow?
  // 0x04: commercial tile count
  // 0x05: ^^^ part of this somehow?
  // 0x06: industrial tile count
  // 0x07: ^^^ part of this somehow?
  misc.zonePop = [];

  for (let i = 0; i < 8; i++) {
    misc.zonePop[i] = bytes.readUInt32BE(offset += 4);
  }

  // console.log('zonePop', misc.zonePop);

  // bond rates
  misc.bondRate = [];

  for (let i = 0; i < 50; i++) {
    misc.bondRate[i] = bytes.readInt32BE(offset += 4);
  }

  // console.log('bondRate', misc.bondRate);

  // 4x4 of neighbors
  // lower left, upper left, upper right, bottom right
  misc.neighbors = [];

  for (let i = 0; i < 4; i++) {
    misc.neighbors[i] = {};
    misc.neighbors[i].index = bytes.readUInt32BE(offset += 4); // index into a name lookup table?
    misc.neighbors[i].population = bytes.readUInt32BE(offset += 4);
    misc.neighbors[i].value = bytes.readUInt32BE(offset += 4);
    misc.neighbors[i].fame = bytes.readUInt32BE(offset += 4);
  }

  // console.log('neighbors', misc.neighbors);

  misc.unknown = bytes.readUInt32BE(offset += 4);
  // console.log('unknown', misc.unknown);

  misc.rci = {};

  // signed 32b int range -1999 to 2000
  misc.rci.residential = bytes.readInt32BE(offset += 4);
  // console.log('rci.residential', misc.rci.residential);

  // signed 32b int range -1999 to 2000
  misc.rci.commercial = bytes.readInt32BE(offset += 4);
  // console.log('rci.commercial', misc.rci.commercial);

  // signed 32b int range -1999 to 2000
  misc.rci.industrial = bytes.readInt32BE(offset += 4);
  // console.log('rci.industrial', misc.rci.industrial);

  misc.unknown = bytes.readUInt32BE(offset += 4);
  // console.log('unknown', misc.unknown);

  misc.unknown = bytes.readUInt32BE(offset += 4);
  // console.log('unknown', misc.unknown);

  misc.unknown = bytes.readUInt32BE(offset += 4);
  // console.log('unknown', misc.unknown);

  misc.unknown = bytes.readUInt32BE(offset += 4);
  // console.log('unknown', misc.unknown);

  misc.unknown = bytes.readUInt32BE(offset += 4);
  // console.log('unknown', misc.unknown);


  misc.inventions = {};

  misc.inventions.gasPower = bytes.readUInt32BE(offset += 4);
  // console.log('inventions.gasPower', misc.inventions.gasPower);

  misc.inventions.nuclearPower = bytes.readUInt32BE(offset += 4);
  // console.log('inventions.nuclearPower', misc.inventions.nuclearPower);

  misc.inventions.solarPower = bytes.readUInt32BE(offset += 4);
  // console.log('inventions.solarPower', misc.inventions.solarPower);

  misc.inventions.windPower = bytes.readUInt32BE(offset += 4);
  // console.log('inventions.windPower', misc.inventions.windPower);

  misc.inventions.microwavePower = bytes.readUInt32BE(offset += 4);
  // console.log('inventions.microwavePower', misc.inventions.microwavePower);

  misc.inventions.fusionPower = bytes.readUInt32BE(offset += 4);
  // console.log('inventions.fusionPower', misc.inventions.fusionPower);

  misc.inventions.airport = bytes.readUInt32BE(offset += 4);
  // console.log('inventions.airport', misc.inventions.airport);

  misc.inventions.highways = bytes.readUInt32BE(offset += 4);
  // console.log('inventions.highways', misc.inventions.highways);

  misc.inventions.buses = bytes.readUInt32BE(offset += 4);
  // console.log('inventions.buses', misc.inventions.buses);

  misc.inventions.subways = bytes.readUInt32BE(offset += 4);
  // console.log('inventions.subways', misc.inventions.subways);

  misc.inventions.waterTreatment = bytes.readUInt32BE(offset += 4);
  // console.log('inventions.waterTreatment', misc.inventions.waterTreatment);

  misc.inventions.desalinisation = bytes.readUInt32BE(offset += 4);
  // console.log('inventions.desalinisation', misc.inventions.desalinisation);

  misc.inventions.plymouth = bytes.readUInt32BE(offset += 4);
  // console.log('inventions.plymouth', misc.inventions.plymouth);

  misc.inventions.forest = bytes.readUInt32BE(offset += 4);
  // console.log('inventions.forest', misc.inventions.forest);

  misc.inventions.darco = bytes.readUInt32BE(offset += 4);
  // console.log('inventions.darco', misc.inventions.darco);

  misc.inventions.launch = bytes.readUInt32BE(offset += 4);
  // console.log('inventions.launch', misc.inventions.launch);

  misc.inventions.highways2 = bytes.readUInt32BE(offset += 4);
  // console.log('inventions.highways2', misc.inventions.highways2);


  misc.budget = {};
  misc.budget.propertyTax = {};

  misc.budget.propertyTax.current = {};
  misc.budget.propertyTax.current.population = bytes.readUInt32BE(offset += 4);
  misc.budget.propertyTax.current.taxRate = bytes.readUInt32BE(offset += 4); // range 0 to 20
  misc.budget.propertyTax.current.unknown = bytes.readUInt32BE(offset += 4);

  for (let i = 0; i < 12; i++) {
    if (!misc.budget.propertyTax[months[i]]) {
      misc.budget.propertyTax[months[i]] = {};
    }

    misc.budget.propertyTax[months[i]].taxRate = bytes.readUInt32BE(offset += 4);
    misc.budget.propertyTax[months[i]].population = bytes.readUInt32BE(offset += 4);
  }

  // console.log('budget.propertyTax', misc.budget.propertyTax);

  // todo: left off here

  misc.budget.residentialTaxRate = [];

  for (let i = 0; i < 27; i++) {
    misc.budget.residentialTaxRate[i] = bytes.readUInt32BE(offset += 4);
  }

  // console.log('budget.residentialTaxRate', misc.budget.residentialTaxRate);

  misc.budget.commercialTaxRate = [];

  for (let i = 0; i < 27; i++) {
    misc.budget.commercialTaxRate[i] = bytes.readUInt32BE(offset += 4);
  }

  // console.log('budget.commercialTaxRate', misc.budget.commercialTaxRate);

  misc.budget.industrialTaxRate = [];

  for (let i = 0; i < 27; i++) {
    misc.budget.industrialTaxRate[i] = bytes.readUInt32BE(offset += 4);
  }

  // console.log('budget.industrialTaxRate', misc.budget.industrialTaxRate);

  misc.budget.ordinances = [];

  for (let i = 0; i < 27; i++) {
    misc.budget.ordinances[i] = bytes.readUInt32BE(offset += 4);
  }

  // console.log('budget.ordinances', misc.budget.ordinances);

  misc.budget.bonds = [];

  for (let i = 0; i < 27; i++) {
    misc.budget.bonds[i] = bytes.readUInt32BE(offset += 4);
  }

  // console.log('budget.bonds', misc.budget.bonds);

  // city services info
  misc.cityServicesBudget = [];

  for (let i = 0; i < 27; i++) {
    misc.cityServicesBudget[i] = bytes.readUInt32BE(offset += 4);
  }

  // console.log('cityServicesBudget', misc.cityServicesBudget);

  misc.budget.police = [];

  for (let i = 0; i < 27; i++) {
    misc.budget.police[i] = bytes.readUInt32BE(offset += 4);
  }

  // console.log('budget.police', misc.budget.police);

  misc.budget.fire = [];

  for (let i = 0; i < 27; i++) {
    misc.budget.fire[i] = bytes.readUInt32BE(offset += 4);
  }

  // console.log('budget.fire', misc.budget.fire);

  misc.budget.health = [];

  for (let i = 0; i < 27; i++) {
    misc.budget.health[i] = bytes.readUInt32BE(offset += 4);
  }

  // console.log('budget.health', misc.budget.health);

  misc.budget.schools = [];

  for (let i = 0; i < 27; i++) {
    misc.budget.schools[i] = bytes.readUInt32BE(offset += 4);
  }

  // console.log('budget.schools', misc.budget.schools);

  misc.budget.colleges = [];

  for (let i = 0; i < 27; i++) {
    misc.budget.colleges[i] = bytes.readUInt32BE(offset += 4);
  }

  // console.log('budget.colleges', misc.budget.colleges);

  misc.budget.roads = [];

  for (let i = 0; i < 27; i++) {
    misc.budget.roads[i] = bytes.readUInt32BE(offset += 4);
  }

  // console.log('budget.roads', misc.budget.roads);

  misc.budget.highways = [];

  for (let i = 0; i < 27; i++) {
    misc.budget.highways[i] = bytes.readUInt32BE(offset += 4);
  }

  // console.log('budget.highways', misc.budget.highways);

  misc.budget.bridges = [];

  for (let i = 0; i < 27; i++) {
    misc.budget.bridges[i] = bytes.readUInt32BE(offset += 4);
  }

  // console.log('budget.bridges', misc.budget.bridges);

  misc.budget.rail = [];

  for (let i = 0; i < 27; i++) {
    misc.budget.rail[i] = bytes.readUInt32BE(offset += 4);
  }

  // console.log('budget.rail', misc.budget.rail);

  misc.budget.subway = [];

  for (let i = 0; i < 27; i++) {
    misc.budget.subway[i] = bytes.readUInt32BE(offset += 4);
  }

  // console.log('budget.subway', misc.budget.subway);

  misc.budget.tunnel = [];

  for (let i = 0; i < 27; i++) {
    misc.budget.tunnel[i] = bytes.readUInt32BE(offset += 4);
  }

  // console.log('budget.tunnel', misc.budget.tunnel);

  misc.yearEnd = bytes.readUInt32BE(offset += 4);
  // console.log('yearEnd', misc.yearEnd);

  misc.globalSeaLevel = bytes.readUInt32BE(offset += 4);
  // console.log('globalSeaLevel', misc.globalSeaLevel);

  misc.terrainCoast = bytes.readUInt32BE(offset += 4);
  // console.log('terrainCoast', misc.terrainCoast);

  misc.terrainRiver = bytes.readUInt32BE(offset += 4);
  // console.log('terrainRiver', misc.terrainRiver);

  misc.military = bytes.readUInt32BE(offset += 4);
  // console.log('military', misc.military);


  misc.newspaperList = [];

  for (let i = 0; i < 21; i++) {
    misc.newspaperList[i] = bytes.readUInt32BE(offset += 4);
  }

  // console.log('newspaperList', misc.newspaperList);

  misc.ordinances = bytes.readUInt32BE(offset += 4);
  // console.log('ordinances', misc.ordinances);

  misc.unemployed = bytes.readUInt32BE(offset += 4);
  // console.log('unemployed', misc.unemployed);


  misc.militaryCount = [];

  for (let i = 0; i < 8; i++) {
    misc.militaryCount[i] = bytes.readUInt32BE(offset += 4);
  }

  // console.log('militaryCount', misc.militaryCount);

  misc.subwayCount = bytes.readUInt32BE(offset += 4);
  // console.log('subwayCount', misc.subwayCount);

  misc.gameSpeed = bytes.readUInt32BE(offset += 4);
  // console.log('gameSpeed', misc.gameSpeed);


  misc.options = {};
  misc.options.autoBudget = bytes.readUInt32BE(offset += 4);
  // console.log('options.autoBudget', misc.options.autoBudget);

  misc.options.autoGoto = bytes.readUInt32BE(offset += 4);
  // console.log('options.autoGoto', misc.options.autoGoto);

  misc.options.userSoundOn = bytes.readUInt32BE(offset += 4);
  // console.log('options.userSoundOn', misc.options.userSoundOn);

  misc.options.userMusicOn = bytes.readUInt32BE(offset += 4);
  // console.log('options.userMusicOn', misc.options.userMusicOn);

  misc.options.noDisasters = bytes.readUInt32BE(offset += 4);
  // console.log('options.noDisasters', misc.options.noDisasters);

  misc.options.paperDeliver = bytes.readUInt32BE(offset += 4);
  // console.log('options.paperDeliver', misc.options.paperDeliver);

  misc.options.paperExtra = bytes.readUInt32BE(offset += 4);
  // console.log('options.paperExtra', misc.options.paperExtra);

  misc.options.paperChoice = bytes.readUInt32BE(offset += 4);
  // console.log('options.paperChoice', misc.options.paperChoice);

  misc.unknown1 = bytes.readUInt32BE(offset += 4);
  // console.log('unknown1', misc.unknown1);


  misc.camera = {};
  misc.camera.zoom = bytes.readUInt32BE(offset += 4);
  // console.log('camera.zoom', misc.camera.zoom);

  misc.camera.cityCenterX = bytes.readUInt32BE(offset += 4);
  // console.log('camera.cityCenterX', misc.camera.cityCenterX);

  misc.camera.cityCenterY = bytes.readUInt32BE(offset += 4);
  // console.log('camera.cityCenterY', misc.camera.cityCenterY);

  misc.globalArcoPopulation = bytes.readUInt32BE(offset += 4);
  // console.log('globalArcoPopulation', misc.globalArcoPopulation);

  misc.connectTiles = bytes.readUInt32BE(offset += 4);
  // console.log('connectTiles', misc.connectTiles);

  misc.teamsActive = bytes.readUInt32BE(offset += 4);
  // console.log('teamsActive', misc.teamsActive);

  misc.totalPopulation = bytes.readUInt32BE(offset += 4);
  // console.log('totalPopulation', misc.totalPopulation);

  misc.industryBonus = bytes.readUInt32BE(offset += 4);
  // console.log('industryBonus', misc.industryBonus);

  misc.polluteBonus = bytes.readUInt32BE(offset += 4);
  // console.log('polluteBonus', misc.polluteBonus);

  misc.oldArrest = bytes.readUInt32BE(offset += 4);
  // console.log('oldArrest', misc.oldArrest);

  misc.policeBonus = bytes.readUInt32BE(offset += 4);
  // console.log('policeBonus', misc.policeBonus);

  misc.disasterObject = bytes.readUInt32BE(offset += 4);
  // console.log('disasterObject', misc.disasterObject);

  misc.currentDisaster = bytes.readUInt32BE(offset += 4);
  // console.log('currentDisaster', misc.currentDisaster);

  misc.disasterActive = bytes.readUInt32BE(offset += 4);
  // console.log('disasterActive', misc.disasterActive);

  misc.gotoDisaster = bytes.readUInt32BE(offset += 4);
  // console.log('gotoDisaster', misc.gotoDisaster);

  misc.sewerBonus = bytes.readUInt32BE(offset += 4);
  // console.log('sewerBonus', misc.sewerBonus);


  data.segments.MISC = misc;
}

const gameMode = {
  0x00: 'terrainEdit',
  0x01: 'city',
  0x02: 'disaster',
};

const offeredMilitary = {
  0x00: false,
  0x01: true,
};

const militaryType = {
  0x02: 'army',
  0x03: 'air',
  0x04: 'naval',
  0x05: 'missile',
};

const gameSpeed = {
  0x01: 'Paused',
  0x02: 'Turtle',
  0x03: 'Llama',
  0x04: 'Cheetah',
  0x05: 'African Swallow',
};

const weatherTrends = {
  0x00: 'Cold',
  0x01: 'Clear',
  0x02: 'Hot',
  0x03: 'Foggy',
  0x04: 'Chilly',
  0x05: 'Overcast',
  0x06: 'Snow',
  0x07: 'Rain',
  0x08: 'Windy',
  0x09: 'Blizzard',
  0x0a: 'Hurricane',
  0x0b: 'Tornado',
};

const disasters = {
  0x00: 'None',
  0x01: 'Fire',
  0x02: 'Flood',
  0x03: 'Riot',
  0x04: 'Toxic Spill',
  0x05: 'Air Crash',
  0x06: 'Quake',
  0x07: 'Tornado',
  0x08: 'Monster',
  0x09: 'Meltdown',
  0x0a: 'Microwave',
  0x0b: 'Volcano',
  0x0c: 'Firestorm',
  0x0d: 'Mass Riots',
  0x0e: 'Mass Floods',
  0x0f: 'Pollution Accident',
  0x10: 'Hurricane',
  0x11: 'Helicopter Crash',
  0x12: 'Plane Crash',
};

const cityIndustries = {
  0x00: 'Steel / Mining',
  0x01: 'Textiles',
  0x02: 'Petrochemical',
  0x03: 'Food',
  0x04: 'Construction',
  0x05: 'Automotive',
  0x06: 'Aerospace',
  0x07: 'Finance',
  0x08: 'Media',
  0x09: 'Electronics',
  0x0a: 'Tourism',
};

const graphAgeRange = {
  0x00: 0,
  0x01: 5,
  0x02: 10,
  0x03: 15,
  0x04: 20,
  0x05: 25,
  0x06: 30,
  0x07: 35,
  0x08: 40,
  0x09: 45,
  0x0a: 50,
  0x0b: 55,
  0x0c: 60,
  0x0d: 65,
  0x0e: 70,
  0x0f: 75,
  0x10: 80,
  0x11: 85,
  0x12: 90,
  0x13: 95,
};

const months = {
  0x00: 'January',
  0x01: 'February',
  0x02: 'March',
  0x03: 'April',
  0x04: 'May',
  0x05: 'June',
  0x06: 'July',
  0x07: 'August',
  0x08: 'September',
  0x09: 'October',
  0x0a: 'November',
  0x0b: 'December',
};
