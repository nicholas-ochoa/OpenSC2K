import { data } from '../data';
import tiles from 'tiles';

export function MISC(bytes: Buffer) {
  // uncomment the console.log(hex(), ...), statement to display offsets in the console
  // still very much a WIP, will optimize once all data structions are properties are identified properly

  let offset = 0;
  const misc: any = {};

  function hex() {
    return '0x' + offset.toString(16).padStart(4, '0').toUpperCase();
  }

  // 0 terrain edit, 1 city, 2 disaster
  misc.cityMode = gameMode[bytes.readUInt32BE(offset += 4)];
  // console.log(hex(), 'gameMode', misc.gameMode);

  // 0 through 3 corresponding to city rotation
  misc.rotation = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'rotation', misc.rotation);

  // year the city was founded
  misc.baseYear = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'baseYear', misc.baseYear);

  // days since city was founded.
  // 300 days per year, 12 months, 25 days per month
  misc.simCycle = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'simCycle', misc.simCycle);

  // total money
  misc.totalFunds = bytes.readInt32BE(offset += 4);
  // console.log(hex(), 'totalFunds', misc.totalFunds);

  // total number of bonds taken out
  // todo: does not work
  misc.totalBondCount = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'totalBonds', misc.totalBondCount);

  // starting difficulty
  misc.gameLevel = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'gameLevel', misc.gameLevel);

  // reward tier obtained. 0 = none, 1 = mayor's mansion
  // 2 = city hall, 3 = statue, 4 = military
  // 5 = llama dome, 6 = arcos
  misc.cityStatus = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'cityStatus', misc.cityStatus);

  // total city value (show bonds dialog)
  // multiply by 1,000 to get value shown in game
  misc.cityValue = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'cityValue', misc.cityValue);

  // sum of all values in XVAL
  misc.landValue = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'landValue', misc.landValue);

  // sum of all values in XCRM
  misc.crimeCount = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'crimeCount', misc.crimeCount);

  // not a sum of XTRF values
  misc.trafficCount = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'trafficCount', misc.trafficCount);

  // unknown
  misc.pollution = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'pollution', misc.pollution);

  // unknown
  misc.cityFame = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'cityFame', misc.cityFame);

  // unknown
  misc.advertising = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'advertising', misc.advertising);

  // unknown
  misc.garbage = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'garbage', misc.garbage);

  // percentage of population that is working
  misc.workerPercent = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'workerPercent', misc.workerPercent);

  // work force life expectancy
  misc.workerHealth = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'workerHealth', misc.workerHealth);

  // work force education quotient
  misc.workerEQ = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'workerEQ', misc.workerEQ);

  // population of simnation
  // multiply by 1,000 to get value shown in game
  misc.nationalPopulation = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'nationalPopulation', misc.nationalPopulation);

  // unknown
  misc.nationalValue = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'nationalValue', misc.nationalValue);

  // unknown
  misc.nationalTax = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'nationalTax', misc.nationalTax);

  // unknown
  misc.nationalTrend = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'nationalTrend', misc.nationalTrend);

  // unknown, weather related
  misc.heat = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'heat', misc.heat);

  // unknown, weather related
  misc.wind = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'wind', misc.wind);

  // unknown, weather related
  misc.humid = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'humid', misc.humid);

  // weather displayed in game on the status bar
  misc.weatherTrend = weatherTrends[bytes.readUInt32BE(offset += 4)];
  // console.log(hex(), 'weatherTrend', misc.weatherTrend);

  // currently active disaster
  misc.disaster = disasters[bytes.readUInt32BE(offset += 4)];
  // console.log(hex(), 'disaster', misc.disaster);

  // unknown
  misc.oldResidentialPopulation = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'oldResidentialPopulation', misc.oldResidentialPopulation);

  // 0x000...0011111 where the last 5 bits represent:
  // 11111 = all, 00001 = mayor's only, 10000 = arco only
  misc.rewards = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'rewards', misc.rewards);

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

    // console.log(hex(), `graphs.population[${i}].age`, misc.graphs.population[i].age);
    // console.log(hex(), `graphs.population[${i}].population`, misc.graphs.population[i].population);

    // health - resident age graph, values unknown
    misc.graphs.health[i] = {
      age: graphAgeRange[i],
      value: bytes.readUInt32BE(offset += 4),
    };

    // console.log(hex(), `graphs.health[${i}].age`, misc.graphs.health[i].age);
    // console.log(hex(), `graphs.health[${i}].value`, misc.graphs.health[i].value);

    // education - resident age graph, values unknown
    misc.graphs.education[i] = {
      age: graphAgeRange[i],
      value: bytes.readUInt32BE(offset += 4),
    };

    // console.log(hex(), `graphs.education[${i}].age`, misc.graphs.education[i].age);
    // console.log(hex(), `graphs.education[${i}].value`, misc.graphs.education[i].value);
  }

  // ingame: city industry dialog
  // ratios: range 0 to 99?
  // tax rates: 0 to 10?
  // demand: 0 to 512?
  for (let i = 0; i < 11; i++) {
    misc.graphs.industry[i] = {};

    misc.graphs.industry[i].type = cityIndustries[i];
    // console.log(hex(), `graphs.industry[${i}].type`, misc.graphs.industry[i].type);

    misc.graphs.industry[i].ratios = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `graphs.industry[${i}].ratios`, misc.graphs.industry[i].ratios);

    misc.graphs.industry[i].taxRates = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `graphs.industry[${i}].taxRates`, misc.graphs.industry[i].taxRates);

    misc.graphs.industry[i].demand = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `graphs.industry[${i}].demand`, misc.graphs.industry[i].demand);
  }

  // total counts of each tile type, index
  // by tile id from XBLD range 0 to 255
  // this counts number of TILES not number
  // of objects. for example, the llama dome is
  // 4x4 and shows up as tile count of 16 if a
  // single structure is placed on the map
  misc.tileCounts = [];

  for (let i = 0; i < 256; i++) {
    misc.tileCounts[i] = {
      id: i,
      type: tiles.data[i]?.type,
      description: tiles.data[i]?.description,
      count: bytes.readUInt32BE(offset += 4),
    };

    // console.log(hex(), `tileCounts[${i}].id`, misc.tileCounts[i].id);
    // console.log(hex(), `tileCounts[${i}].type`, misc.tileCounts[i].type);
    // console.log(hex(), `tileCounts[${i}].description`, misc.tileCounts[i].description);
    // console.log(hex(), `tileCounts[${i}].count`, misc.tileCounts[i].count);
  }

  misc.zonePop = [];

  // populated tile counts
  // mapped to zone types? (table below)
  for (let i = 0; i < 8; i++) {
    misc.zonePop[zoneMap[i]] = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `zonePop[${zoneMap[i]}]`, misc.zonePop[zoneMap[i]]);
  }

  // bond rates
  misc.bondRate = [];
  for (let i = 0; i < 50; i++) {
    misc.bondRate[i] = bytes.readInt32BE(offset += 4);
  }

  // console.log(hex(), 'bondRate', misc.bondRate);

  // 4x4 of neighbors
  // lower left, upper left, upper right, bottom right
  misc.neighbors = [];

  for (let i = 0; i < 4; i++) {
    misc.neighbors[i] = {};
    misc.neighbors[i].index = bytes.readUInt32BE(offset += 4); // index into a name lookup table?
    // console.log(hex(), `neighbors[${i}].index`, misc.neighbors[i].index);

    misc.neighbors[i].population = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `neighbors[${i}].population`, misc.neighbors[i].population);

    misc.neighbors[i].value = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `neighbors[${i}].value`, misc.neighbors[i].value);

    misc.neighbors[i].fame = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `neighbors[${i}].fame`, misc.neighbors[i].fame);
  }

  misc.rci = {};

  // signed 32b int range -1999 to 2000
  misc.rci.residential = bytes.readInt32BE(offset += 4);
  // console.log(hex(), 'rci.residential', misc.rci.residential);

  // signed 32b int range -1999 to 2000
  misc.rci.commercial = bytes.readInt32BE(offset += 4);
  // console.log(hex(), 'rci.commercial', misc.rci.commercial);

  // signed 32b int range -1999 to 2000
  misc.rci.industrial = bytes.readInt32BE(offset += 4);
  // console.log(hex(), 'rci.industrial', misc.rci.industrial);

  misc.unknown = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'unknown', misc.unknown);

  misc.unknown = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'unknown', misc.unknown);

  misc.unknown = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'unknown', misc.unknown);

  misc.unknown = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'unknown', misc.unknown);

  misc.unknown = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'unknown', misc.unknown);

  // the year a technology was invented
  // defaults to 0 if a city was saved after
  // the tech was invented
  misc.inventions = {};

  misc.inventions.gasPower = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'inventions.gasPower', misc.inventions.gasPower);

  misc.inventions.nuclearPower = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'inventions.nuclearPower', misc.inventions.nuclearPower);

  misc.inventions.solarPower = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'inventions.solarPower', misc.inventions.solarPower);

  misc.inventions.windPower = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'inventions.windPower', misc.inventions.windPower);

  misc.inventions.microwavePower = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'inventions.microwavePower', misc.inventions.microwavePower);

  misc.inventions.fusionPower = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'inventions.fusionPower', misc.inventions.fusionPower);

  misc.inventions.airport = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'inventions.airport', misc.inventions.airport);

  misc.inventions.highways = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'inventions.highways', misc.inventions.highways);

  misc.inventions.buses = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'inventions.buses', misc.inventions.buses);

  misc.inventions.subways = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'inventions.subways', misc.inventions.subways);

  misc.inventions.waterTreatment = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'inventions.waterTreatment', misc.inventions.waterTreatment);

  misc.inventions.desalinisation = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'inventions.desalinisation', misc.inventions.desalinisation);

  misc.inventions.plymouth = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'inventions.plymouth', misc.inventions.plymouth);

  misc.inventions.forest = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'inventions.forest', misc.inventions.forest);

  misc.inventions.darco = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'inventions.darco', misc.inventions.darco);

  misc.inventions.launch = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'inventions.launch', misc.inventions.launch);

  misc.inventions.highways2 = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'inventions.highways2', misc.inventions.highways2);

  misc.budget = {};

  misc.budget.residentialTaxRate = {};
  misc.budget.residentialTaxRate.current = {};

  misc.budget.residentialTaxRate.current.population = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.residentialTaxRate.current.population', misc.budget.residentialTaxRate.current.population);

  misc.budget.residentialTaxRate.current.taxRate = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.residentialTaxRate.current.taxRate', misc.budget.residentialTaxRate.current.taxRate);

  misc.budget.residentialTaxRate.current.unknown = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.residentialTaxRate.current.unknown', misc.budget.residentialTaxRate.current.unknown);

  for (let i = 0; i < 12; i++) {
    if (!misc.budget.residentialTaxRate[months[i]]) {
      misc.budget.residentialTaxRate[months[i]] = {};
    }

    misc.budget.residentialTaxRate[months[i]].population = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), 'budget.residentialTaxRate[' + months[i] + '].population', misc.budget.residentialTaxRate[months[i]].population);

    misc.budget.residentialTaxRate[months[i]].taxRate = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), 'budget.residentialTaxRate[' + months[i] + '].taxRate', misc.budget.residentialTaxRate[months[i]].taxRate);
  }

  misc.budget.commercialTaxRate = {};
  misc.budget.commercialTaxRate.current = {};

  misc.budget.commercialTaxRate.current.population = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.commercialTaxRate.current.population', misc.budget.commercialTaxRate.current.population);

  misc.budget.commercialTaxRate.current.taxRate = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.commercialTaxRate.current.taxRate', misc.budget.commercialTaxRate.current.taxRate);

  misc.budget.commercialTaxRate.current.unknown = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.commercialTaxRate.current.unknown', misc.budget.commercialTaxRate.current.unknown);

  for (let i = 0; i < 12; i++) {
    if (!misc.budget.commercialTaxRate[months[i]]) {
      misc.budget.commercialTaxRate[months[i]] = {};
    }

    misc.budget.commercialTaxRate[months[i]].population = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), 'budget.commercialTaxRate[' + months[i] + '].population', misc.budget.commercialTaxRate[months[i]].population);

    misc.budget.commercialTaxRate[months[i]].taxRate = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), 'budget.commercialTaxRate[' + months[i] + '].taxRate', misc.budget.commercialTaxRate[months[i]].taxRate);
  }

  misc.budget.industrialTaxRate = {};
  misc.budget.industrialTaxRate.current = {};

  misc.budget.industrialTaxRate.current.population = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.industrialTaxRate.current.population', misc.budget.industrialTaxRate.current.population);

  misc.budget.industrialTaxRate.current.taxRate = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.industrialTaxRate.current.taxRate', misc.budget.industrialTaxRate.current.taxRate);

  misc.budget.industrialTaxRate.current.unknown = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.industrialTaxRate.current.unknown', misc.budget.industrialTaxRate.current.unknown);

  for (let i = 0; i < 12; i++) {
    if (!misc.budget.industrialTaxRate[months[i]]) {
      misc.budget.industrialTaxRate[months[i]] = {};
    }

    misc.budget.industrialTaxRate[months[i]].population = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), 'budget.industrialTaxRate[' + months[i] + '].population', misc.budget.industrialTaxRate[months[i]].population);

    misc.budget.industrialTaxRate[months[i]].taxRate = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), 'budget.industrialTaxRate[' + months[i] + '].taxRate', misc.budget.industrialTaxRate[months[i]].taxRate);
  }

  misc.budget.ordinances = {};
  misc.budget.ordinances.current = {};

  // unknown, budget ordinances?

  // unknown
  misc.budget.ordinances.current.population = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.ordinances.current.population', misc.budget.ordinances.current.population);

  // unknown, tax rate?
  misc.budget.ordinances.current.taxRate = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.ordinances.current.taxRate', misc.budget.ordinances.current.taxRate);

  // unknown
  misc.budget.ordinances.current.unknown = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.ordinances.current.unknown', misc.budget.ordinances.current.unknown);


  for (let i = 0; i < 12; i++) {
    if (!misc.budget.ordinances[months[i]]) {
      misc.budget.ordinances[months[i]] = {};
    }

    // unknown
    misc.budget.ordinances[months[i]].population = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `budget.ordinances[${months[i]}].population`, misc.budget.ordinances[months[i]].population);

    // unknown, tax rate?
    misc.budget.ordinances[months[i]].taxRate = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `budget.ordinances[${months[i]}].taxRate`, misc.budget.ordinances[months[i]].taxRate);
  }

  misc.budget.bonds = [];

  // budget - bonds screen
  // unknown
  for (let i = 0; i < 27; i++) {
    misc.budget.bonds[i] = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `budget.bonds[${i}]`, misc.budget.bonds[i]);
  }

  misc.budget.police = {};

  misc.budget.police.tileCount = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.police.tileCount', misc.budget.police.tileCount);

  misc.budget.police.currentFundingRate = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.police.currentFundingRate', misc.budget.police.currentFundingRate);

  misc.budget.police.unknown = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.police.unknown', misc.budget.police.unknown);

  for (let i = 0; i < 12; i++) {
    if (!misc.budget.police[months[i]]) {
      misc.budget.police[months[i]] = {};
    }

    misc.budget.police[months[i]].tileCount = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `budget.police[${months[i]}].tileCount`, misc.budget.police[months[i]].tileCount);

    misc.budget.police[months[i]].funding = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `budget.police[${months[i]}].funding`, misc.budget.police[months[i]].funding);
  }

  misc.budget.fire = {};

  misc.budget.fire.tileCount = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.fire.tileCount', misc.budget.fire.tileCount);

  misc.budget.fire.currentFundingRate = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.fire.currentFundingRate', misc.budget.fire.currentFundingRate);

  misc.budget.fire.unknown = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.fire.unknown', misc.budget.fire.unknown);

  for (let i = 0; i < 12; i++) {
    if (!misc.budget.fire[months[i]]) {
      misc.budget.fire[months[i]] = {};
    }

    misc.budget.fire[months[i]].tileCount = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `budget.fire[${months[i]}].tileCount`, misc.budget.fire[months[i]].tileCount);

    misc.budget.fire[months[i]].funding = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `budget.fire[${months[i]}].funding`, misc.budget.fire[months[i]].funding);
  }

  misc.budget.health = {};

  misc.budget.health.tileCount = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.health.tileCount', misc.budget.health.tileCount);

  misc.budget.health.currentFundingRate = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.health.currentFundingRate', misc.budget.health.currentFundingRate);

  misc.budget.health.unknown = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.health.unknown', misc.budget.health.unknown);

  for (let i = 0; i < 12; i++) {
    if (!misc.budget.health[months[i]]) {
      misc.budget.health[months[i]] = {};
    }

    misc.budget.health[months[i]].tileCount = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `budget.health[${months[i]}].tileCount`, misc.budget.health[months[i]].tileCount);

    misc.budget.health[months[i]].funding = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `budget.health[${months[i]}].funding`, misc.budget.health[months[i]].funding);
  }

  misc.budget.schools = {};

  misc.budget.schools.tileCount = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.schools.tileCount', misc.budget.schools.tileCount);

  misc.budget.schools.currentFundingRate = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.schools.currentFundingRate', misc.budget.schools.currentFundingRate);

  misc.budget.schools.unknown = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.schools.unknown', misc.budget.schools.unknown);

  for (let i = 0; i < 12; i++) {
    if (!misc.budget.schools[months[i]]) {
      misc.budget.schools[months[i]] = {};
    }

    misc.budget.schools[months[i]].tileCount = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `budget.schools[${months[i]}].tileCount`, misc.budget.schools[months[i]].tileCount);

    misc.budget.schools[months[i]].funding = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `budget.schools[${months[i]}].funding`, misc.budget.schools[months[i]].funding);
  }

  misc.budget.colleges = {};

  misc.budget.colleges.tileCount = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.colleges.tileCount', misc.budget.colleges.tileCount);

  misc.budget.colleges.currentFundingRate = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.colleges.currentFundingRate', misc.budget.colleges.currentFundingRate);

  misc.budget.colleges.unknown = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.colleges.unknown', misc.budget.colleges.unknown);

  for (let i = 0; i < 12; i++) {
    if (!misc.budget.colleges[months[i]]) {
      misc.budget.colleges[months[i]] = {};
    }

    misc.budget.colleges[months[i]].tileCount = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `budget.colleges[${months[i]}].tileCount`, misc.budget.colleges[months[i]].tileCount);

    misc.budget.colleges[months[i]].funding = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `budget.colleges[${months[i]}].funding`, misc.budget.colleges[months[i]].funding);
  }

  misc.budget.roads = {};

  misc.budget.roads.tileCount = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.roads.tileCount', misc.budget.roads.tileCount);

  misc.budget.roads.currentFundingRate = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.roads.currentFundingRate', misc.budget.roads.currentFundingRate);

  misc.budget.roads.unknown = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.roads.unknown', misc.budget.roads.unknown);

  for (let i = 0; i < 12; i++) {
    if (!misc.budget.roads[months[i]]) {
      misc.budget.roads[months[i]] = {};
    }

    misc.budget.roads[months[i]].tileCount = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `budget.roads[${months[i]}].tileCount`, misc.budget.roads[months[i]].tileCount);

    misc.budget.roads[months[i]].funding = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `budget.roads[${months[i]}].funding`, misc.budget.roads[months[i]].funding);
  }

  misc.budget.highways = {};

  misc.budget.highways.tileCount = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.highways.tileCount', misc.budget.highways.tileCount);

  misc.budget.highways.currentFundingRate = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.highways.currentFundingRate', misc.budget.highways.currentFundingRate);

  misc.budget.highways.unknown = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.highways.unknown', misc.budget.highways.unknown);

  for (let i = 0; i < 12; i++) {
    if (!misc.budget.highways[months[i]]) {
      misc.budget.highways[months[i]] = {};
    }

    misc.budget.highways[months[i]].tileCount = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `budget.highways[${months[i]}].tileCount`, misc.budget.highways[months[i]].tileCount);

    misc.budget.highways[months[i]].funding = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `budget.highways[${months[i]}].funding`, misc.budget.highways[months[i]].funding);
  }

  misc.budget.bridges = {};

  misc.budget.bridges.tileCount = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.bridges.tileCount', misc.budget.bridges.tileCount);

  misc.budget.bridges.currentFundingRate = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.bridges.currentFundingRate', misc.budget.bridges.currentFundingRate);

  misc.budget.bridges.unknown = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.bridges.unknown', misc.budget.bridges.unknown);

  for (let i = 0; i < 12; i++) {
    if (!misc.budget.bridges[months[i]]) {
      misc.budget.bridges[months[i]] = {};
    }

    misc.budget.bridges[months[i]].tileCount = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `budget.bridges[${months[i]}].tileCount`, misc.budget.bridges[months[i]].tileCount);

    misc.budget.bridges[months[i]].funding = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `budget.bridges[${months[i]}].funding`, misc.budget.bridges[months[i]].funding);
  }

  misc.budget.rail = {};

  misc.budget.rail.tileCount = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.rail.tileCount', misc.budget.rail.tileCount);

  misc.budget.rail.currentFundingRate = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.rail.currentFundingRate', misc.budget.rail.currentFundingRate);

  misc.budget.rail.unknown = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.rail.unknown', misc.budget.rail.unknown);

  for (let i = 0; i < 12; i++) {
    if (!misc.budget.rail[months[i]]) {
      misc.budget.rail[months[i]] = {};
    }

    misc.budget.rail[months[i]].tileCount = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `budget.rail[${months[i]}].tileCount`, misc.budget.rail[months[i]].tileCount);

    misc.budget.rail[months[i]].funding = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `budget.rail[${months[i]}].funding`, misc.budget.rail[months[i]].funding);
  }

  misc.budget.subway = {};

  misc.budget.subway.tileCount = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.subway.tileCount', misc.budget.subway.tileCount);

  misc.budget.subway.currentFundingRate = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.subway.currentFundingRate', misc.budget.subway.currentFundingRate);

  misc.budget.subway.unknown = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.subway.unknown', misc.budget.subway.unknown);

  for (let i = 0; i < 12; i++) {
    if (!misc.budget.subway[months[i]]) {
      misc.budget.subway[months[i]] = {};
    }

    misc.budget.subway[months[i]].tileCount = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `budget.subway[${months[i]}].tileCount`, misc.budget.subway[months[i]].tileCount);

    misc.budget.subway[months[i]].funding = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `budget.subway[${months[i]}].funding`, misc.budget.subway[months[i]].funding);
  }

  misc.budget.tunnel = {};

  misc.budget.tunnel.tileCount = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.tunnel.tileCount', misc.budget.tunnel.tileCount);

  misc.budget.tunnel.currentFundingRate = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.tunnel.currentFundingRate', misc.budget.tunnel.currentFundingRate);

  misc.budget.tunnel.unknown = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'budget.tunnel.unknown', misc.budget.tunnel.unknown);

  for (let i = 0; i < 12; i++) {
    if (!misc.budget.tunnel[months[i]]) {
      misc.budget.tunnel[months[i]] = {};
    }

    misc.budget.tunnel[months[i]].tileCount = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `budget.tunnel[${months[i]}].tileCount`, misc.budget.tunnel[months[i]].tileCount);

    misc.budget.tunnel[months[i]].funding = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `budget.tunnel[${months[i]}].funding`, misc.budget.tunnel[months[i]].funding);
  }

  // unknown, year end
  misc.yearEnd = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'yearEnd', misc.yearEnd);

  // water table level
  misc.seaLevel = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'seaLevel', misc.seaLevel);

  // was this city generated with coastal terrain?
  misc.terrainCoast = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'terrainCoast', misc.terrainCoast);

  // was this city generated with river terrain?
  misc.terrainRiver = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'terrainRiver', misc.terrainRiver);

  // military base offered / denied - or type of base (table below)
  misc.military = militaryBase[bytes.readUInt32BE(offset += 4)];
  // console.log(hex(), 'military', misc.military);


  misc.newspaperList = [];

  // newspaper list, unknown
  // 6x5B struct
  // 9x6B struct
  for (let i = 0; i < 21; i++) {
    misc.newspaperList[i] = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `newspaperList[${i}]`, misc.newspaperList[i]);
  }

  // unknown values
  // appears to be a group of 9 fields
  // related to the next 9 groups of 6 fields?
  for (let i = 0; i < 9; i++) {
    misc.unknown = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `field ${i}: unknown`, misc.unknown);
  }

  // related to the 9 fields above? appears to be grouped together
  for (let i = 0; i < 9; i++) {
    misc.unknown = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `group ${i}: unknown`, misc.unknown);

    misc.unknown = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `group ${i}: unknown`, misc.unknown);

    misc.unknown = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `group ${i}: unknown`, misc.unknown);

    misc.unknown = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `group ${i}: unknown`, misc.unknown);

    misc.unknown = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `group ${i}: unknown`, misc.unknown);

    misc.unknown = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `group ${i}: unknown`, misc.unknown);
  }

  // ordinance flags (bit flags)
  misc.ordinances = {
    finance: {},
    safetyAndHealth: {},
    education: {},
    promotional: {},
    other: {},
  };

  const ordinances = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'ordinances', misc.ordinances, misc.ordinances.toString(2).padStart('0', 32));

  misc.ordinances.finance.salesTax = (ordinances & 0b00000000000000000001) !== 0;
  misc.ordinances.finance.incomeTax = (ordinances & 0b00000000000000000010) !== 0;
  misc.ordinances.finance.legalizedGambling = (ordinances & 0b00000000000000000100) !== 0;
  misc.ordinances.finance.parkingFines = (ordinances & 0b00000000000000001000) !== 0;

  misc.ordinances.safetyAndHealth.volunteerFireDept = (ordinances & 0b00000000000000010000) !== 0;
  misc.ordinances.safetyAndHealth.publicSmokingBan = (ordinances & 0b00000000000000100000) !== 0;
  misc.ordinances.safetyAndHealth.freeClinics = (ordinances & 0b00000000000001000000) !== 0;
  misc.ordinances.safetyAndHealth.juniorSports = (ordinances & 0b00000000000010000000) !== 0;

  misc.ordinances.education.proReadingCampaign = (ordinances & 0b00000000000100000000) !== 0;
  misc.ordinances.education.antiDrugCampaign = (ordinances & 0b00000000001000000000) !== 0;
  misc.ordinances.education.cprTraining = (ordinances & 0b00000000010000000000) !== 0;
  misc.ordinances.education.neighborhoodWatch = (ordinances & 0b00000000100000000000) !== 0;

  misc.ordinances.promotional.touristAdvertising = (ordinances & 0b00000001000000000000) !== 0;
  misc.ordinances.promotional.businessAdvertising = (ordinances & 0b00000010000000000000) !== 0;
  misc.ordinances.promotional.cityBeautification = (ordinances & 0b00000100000000000000) !== 0;
  misc.ordinances.promotional.annualCarnival = (ordinances & 0b00001000000000000000) !== 0;

  misc.ordinances.other.energyConservation = (ordinances & 0b00010000000000000000) !== 0;
  misc.ordinances.other.nuclearFreeZone = (ordinances & 0b00100000000000000000) !== 0;
  misc.ordinances.other.homelessShelter = (ordinances & 0b01000000000000000000) !== 0;
  misc.ordinances.other.pollutionControls = (ordinances & 0b10000000000000000000) !== 0;

  // unknown
  misc.unemployed = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'unemployed', misc.unemployed);


  misc.militaryCount = [];

  // unknown, count of military tiles?
  for (let i = 0; i < 16; i++) {
    misc.militaryCount[i] = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `militaryCount[${i}]`, misc.militaryCount[i]);
  }

  // unknown, count of underground subway tiles?
  misc.subwayCount = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'subwayCount', misc.subwayCount);

  // game speed, table below
  misc.gameSpeed = gameSpeed[bytes.readUInt32BE(offset += 4)];
  // console.log(hex(), 'gameSpeed', misc.gameSpeed);

  misc.options = {};

  // is automatic budget enabled?
  misc.options.AutoBudget = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'options.AutoBudget', misc.options.AutoBudget);

  // is auto goto event enabled?
  misc.options.autoGoto = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'options.autoGoto', misc.options.autoGoto);

  // are sound effects enabled?
  misc.options.soundEffects = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'options.soundEffects', misc.options.soundEffects);

  // is music enabled?
  misc.options.music = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'options.music', misc.options.music);

  // is no disasters enabled?
  misc.noDisasters = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'noDisasters', misc.noDisasters);

  // is newspaper delivery enabled?
  misc.newspaperDelivery = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'newspaperDelivery', misc.newspaperDelivery);

  // newspaper selected for delivery
  misc.newspaperSelection = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'newspaperSelection', misc.newspaperSelection);

  // unknown
  misc.unknown = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'unknown', misc.unknown);

  // unknown
  misc.unknown = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'unknown', misc.unknown);

  // unknown, something to do with zoom and position of map
  misc.cameraZoomUnknown = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'cameraZoomUnknown', misc.cameraZoomUnknown);

  // center of view coordinates
  misc.cameraPositionX = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'cameraPositionX', misc.cameraPositionX);

  // center of view coordinates
  misc.cameraPositionY = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'cameraPositionY', misc.cameraPositionY);

  // total city population from arcos
  misc.arcoPopulation = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'arcoPopulation', misc.arcoPopulation);

  // count of tiles that are connected to neighbor cities
  misc.connectionTiles = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'connectionTiles', misc.connectionTiles);

  // count of active sports teams from stadiums
  misc.sportsTeams = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'sportsTeams', misc.sportsTeams);

  // total city population (not include arcos)
  misc.normalPopulation = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'normalPopulation', misc.normalPopulation);

  // unknown
  misc.industryBonus = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'industryBonus', misc.industryBonus);

  // unknown, signed?
  misc.pollutionBonus = bytes.readInt32BE(offset += 4);
  // console.log(hex(), 'pollutionBonus', misc.pollutionBonus);

  // sum of all police station microsim arrests
  misc.oldArrest = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'oldArrest', misc.oldArrest);

  // unknown
  misc.policeBonus = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'policeBonus', misc.policeBonus);

  // unknown, signed?
  misc.disaster = bytes.readInt32BE(offset += 4);
  // console.log(hex(), 'disaster', misc.disaster);

  // unknown
  misc.unknown = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'unknown', misc.unknown);

  // 1 = disaster happening, 0 = normal
  misc.disasterActive = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'disasterActive', misc.disasterActive);

  // unknown: go disaster
  misc.goDisaster = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'goDisaster', misc.goDisaster);

  // unknown, water pipes?
  misc.sewerBonus = bytes.readUInt32BE(offset += 4);
  // console.log(hex(), 'sewerBonus', misc.sewerBonus);

  // unknown, all zero bytes beyond this point
  for (let i = 0; i < 155; i++) {
    misc.unknown = bytes.readUInt32BE(offset += 4);
    // console.log(hex(), `unknown[${i}]`, misc.unknown);
  }

  // console.log(hex(), 'end');

  data.segments.MISC = misc;
}

const gameMode = {
  0x00: 'terrainEdit',
  0x01: 'city',
  0x02: 'disaster',
};

const militaryBase = {
  0x00: 'not offered',
  0x01: 'offered base, no suitable location / refused',
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

const zoneMap = {
  0x00: 'none',
  0x01: 'lightResidential',
  0x02: 'denseResidential',
  0x03: 'lightCommercial',
  0x04: 'denseCommercial',
  0x05: 'lightIndustrial',
  0x06: 'denseIndustrial',
  0x07: 'military',
  0x08: 'airport',
  0x09: 'seaport',
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
