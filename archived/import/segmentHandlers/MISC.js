export default (data, map) => {

  // uncomment the console.log statement to work on this section
  // still very much a WIP
  // will optimize once all data structions are properties are identified properly

  function log(...a) {
    //console.log(...a);
  }

  let misc = {};
  let offset = 0;

  misc.firstEntry                  = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                   log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'firstEntry',                 misc.firstEntry);
  misc.gameMode                    = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                   log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'gameMode',                   misc.gameMode);
  misc.rotation                    = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                   log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'rotation',                   misc.rotation);
  misc.baseYear                    = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                   log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'baseYear',                   misc.baseYear);
  misc.simCycle                    = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                   log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'simCycle',                   misc.simCycle);
  misc.totalFunds                  = new DataView(data.slice(offset, offset+=4).buffer).getInt32(0);                    log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'totalFunds',                 misc.totalFunds);
  misc.totalBonds                  = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                   log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'totalBonds',                 misc.totalBonds);
  misc.gameLevel                   = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                   log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'gameLevel',                  misc.gameLevel);
  misc.cityStatus                  = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                   log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'cityStatus',                 misc.cityStatus);
  misc.cityValue                   = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                   log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'cityValue',                  misc.cityValue);
  misc.landValue                   = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                   log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'landValue',                  misc.landValue);
  misc.crimeCount                  = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                   log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'crimeCount',                 misc.crimeCount);
  misc.trafficCount                = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                   log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'trafficCount',               misc.trafficCount);
  misc.pollution                   = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                   log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'pollution',                  misc.pollution);
  misc.cityFame                    = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                   log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'cityFame',                   misc.cityFame);
  misc.advertising                 = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                   log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'advertising',                misc.advertising);
  misc.garbage                     = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                   log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'garbage',                    misc.garbage);
  misc.workerPercent               = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                   log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'workerPercent',              misc.workerPercent);
  misc.workerHealth                = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                   log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'workerHealth',               misc.workerHealth);
  misc.workerEQ                    = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                   log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'workerEQ',                   misc.workerEQ);
  misc.nationalPopulation          = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                   log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'nationalPopulation',         misc.nationalPopulation);
  misc.nationalValue               = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                   log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'nationalValue',              misc.nationalValue);
  misc.nationalTax                 = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                   log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'nationalTax',                misc.nationalTax);
  misc.nationalTrend               = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                   log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'nationalTrend',              misc.nationalTrend);
  misc.heat                        = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                   log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'heat',                       misc.heat);
  misc.wind                        = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                   log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'wind',                       misc.wind);
  misc.humid                       = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                   log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'humid',                      misc.humid);
  misc.weatherTrend                = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                   log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'weatherTrend',               misc.weatherTrend);
  misc.newDisaster                 = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                   log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'newDisaster',                misc.newDisaster);
  misc.oldResidentialPopulation    = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                   log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'oldResidentialPopulation',   misc.oldResidentialPopulation);
  misc.rewards                     = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                   log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'rewards',                    misc.rewards);


  // graph data
  misc.graphs = {};
  misc.graphs.population = [];
  misc.graphs.health = [];
  misc.graphs.education = [];
  misc.graphs.industry = [];

  for (let i = 0; i < 20; i++) {
    misc.graphs.population[i] = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                        log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'graphs.population['+i+']',        misc.graphs.population[i] );
    misc.graphs.health[i]     = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                        log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'graphs.health['+i+']',            misc.graphs.health[i]     );
    misc.graphs.education[i]  = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                        log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'graphs.education['+i+']',         misc.graphs.education[i]  );
  }

  for (let i = 0; i < 33; i++) {
    misc.graphs.industry[i] = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                          log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'graphs.industry['+i+']',          misc.graphs.industry[i] );
  }


  // counts of each tile ID
  misc.tileCounts = [];

  for (let i = 0; i < 256; i++) {
    misc.tileCounts[i] = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                               log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'tileCounts['+i+']',               misc.tileCounts[i] );
  }

  // population for each zone type
  misc.zonePop = [];

  for (let i = 0; i < 8; i++) {
    misc.zonePop[i] = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                                  log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'zonePop['+i+']',                  misc.zonePop[i] );
  }

  // bond rates
  misc.bondRate = [];

  for (let i = 0; i < 50; i++) {
    misc.bondRate[i] = new DataView(data.slice(offset, offset+=4).buffer).getInt32(0);                                  log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'bondRate['+i+']',                 misc.bondRate[i] );
  }


  // 4x4 of neighbors
  // lower left, upper left, upper right, bottom right
  misc.neighbors = [];

  for (let i = 0; i < 4; i++) {
    misc.neighbors[i] = {};
    misc.neighbors[i].name       = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                     log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'neighbors['+i+'].name',           misc.neighbors[i].name);
    misc.neighbors[i].population = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                     log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'neighbors['+i+'].population',     misc.neighbors[i].population);
    misc.neighbors[i].value      = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                     log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'neighbors['+i+'].value',          misc.neighbors[i].value);
    misc.neighbors[i].fame       = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                     log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'neighbors['+i+'].fame',           misc.neighbors[i].fame);
  }

  misc.rci = {};
  misc.rci.residential = new DataView(data.slice(offset, offset+=4).buffer).getInt32(0);                                log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'rci.residential',            misc.rci.residential);
  misc.rci.commercial  = new DataView(data.slice(offset, offset+=4).buffer).getInt32(0);                                log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'rci.commercial',             misc.rci.commercial);
  misc.rci.industrial  = new DataView(data.slice(offset, offset+=4).buffer).getInt32(0);                                log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'rci.industrial',             misc.rci.industrial);

  misc.unknown0       = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                                log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'unknown0',         misc.unknown0);
  misc.unknown1       = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                                log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'unknown1',         misc.unknown1);
  misc.unknown2       = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                                log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'unknown2',         misc.unknown2);
  misc.unknown3       = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                                log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'unknown3',         misc.unknown3);
  misc.unknown4       = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                                log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'unknown4',         misc.unknown4);

  misc.inventions = {};
  misc.inventions.gasPower       = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                     log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'inventions.gasPower',         misc.inventions.gasPower);
  misc.inventions.nuclearPower   = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                     log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'inventions.nuclearPower',     misc.inventions.nuclearPower);
  misc.inventions.solarPower     = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                     log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'inventions.solarPower',       misc.inventions.solarPower);
  misc.inventions.windPower      = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                     log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'inventions.windPower',        misc.inventions.windPower);
  misc.inventions.microwavePower = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                     log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'inventions.microwavePower',   misc.inventions.microwavePower);
  misc.inventions.fusionPower    = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                     log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'inventions.fusionPower',      misc.inventions.fusionPower);
  misc.inventions.airport        = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                     log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'inventions.airport',          misc.inventions.airport);
  misc.inventions.highways       = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                     log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'inventions.highways',         misc.inventions.highways);
  misc.inventions.buses          = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                     log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'inventions.buses',            misc.inventions.buses);
  misc.inventions.subways        = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                     log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'inventions.subways',          misc.inventions.subways);
  misc.inventions.waterTreatment = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                     log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'inventions.waterTreatment',   misc.inventions.waterTreatment);
  misc.inventions.desalinisation = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                     log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'inventions.desalinisation',   misc.inventions.desalinisation);
  misc.inventions.plymouth       = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                     log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'inventions.plymouth',         misc.inventions.plymouth);
  misc.inventions.forest         = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                     log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'inventions.forest',           misc.inventions.forest);
  misc.inventions.darco          = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                     log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'inventions.darco',            misc.inventions.darco);
  misc.inventions.launch         = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                     log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'inventions.launch',           misc.inventions.launch);
  misc.inventions.highways2      = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                     log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'inventions.highways2',        misc.inventions.highways2);


                                                                                                                        log('current offset: 0x'+offset.toString(16).padStart(4, '0'));
                                                                                                                        log('budget start');
                                                                                                                        log('===');

  misc.budget = {};
  misc.budget.propertyTax = [];

  for (let i = 0; i < 27; i++) {
    misc.budget.propertyTax[i] = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                       log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'budget.propertyTax['+i+']',              misc.budget.propertyTax[i] );
  }


  offset = 0x077c;
  misc.budget.residentialTaxRate = [];

  for (let i = 0; i < 27; i++) {
    misc.budget.residentialTaxRate[i] = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'budget.residentialTaxRate['+i+']',               misc.budget.residentialTaxRate[i] );
  }

  offset = 0x07e8;
  misc.budget.commercialTaxRate = [];

  for (let i = 0; i < 27; i++) {
    misc.budget.commercialTaxRate[i] = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                 log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'budget.commercialTaxRate['+i+']',               misc.budget.commercialTaxRate[i] );
  }

  offset = 0x0854;
  misc.budget.industrialTaxRate = [];

  for (let i = 0; i < 27; i++) {
    misc.budget.industrialTaxRate[i] = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                 log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'budget.industrialTaxRate['+i+']',               misc.budget.industrialTaxRate[i] );
  }
  

  offset = 0x08c0;
  misc.budget.ordinances = [];

  for (let i = 0; i < 27; i++) {
    misc.budget.ordinances[i] = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                        log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'budget.ordinances['+i+']',               misc.budget.ordinances[i] );
  }


  offset = 0x0930;
  misc.budget.bonds = [];

  for (let i = 0; i < 27; i++) {
    misc.budget.bonds[i] = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                             log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'budget.bonds['+i+']',           misc.budget.bonds[i] );
  }


  // city services info
  misc.cityServicesBudget = [];

  for (let i = 0; i < 27; i++) {
    misc.cityServicesBudget[i] = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                       log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'cityServicesBudget['+i+']',       misc.cityServicesBudget[i] );
  }


  offset = 0x0998;
  misc.budget.police = [];

  for (let i = 0; i < 27; i++) {
    misc.budget.police[i] = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                            log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'budget.police['+i+']',       misc.budget.police[i] );
  }

  offset = 0x0a04;
  misc.budget.fire = [];

  for (let i = 0; i < 27; i++) {
    misc.budget.fire[i] = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                              log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'budget.fire['+i+']',       misc.budget.fire[i] );
  }

  offset = 0x0a70;
  misc.budget.health = [];

  for (let i = 0; i < 27; i++) {
    misc.budget.health[i] = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                            log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'budget.health['+i+']',       misc.budget.health[i] );
  }

  offset = 0x0adc;
  misc.budget.schools = [];

  for (let i = 0; i < 27; i++) {
    misc.budget.schools[i] = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                           log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'budget.schools['+i+']',       misc.budget.schools[i] );
  }

  offset = 0x0b48;
  misc.budget.colleges = [];

  for (let i = 0; i < 27; i++) {
    misc.budget.colleges[i] = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                          log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'budget.colleges['+i+']',       misc.budget.colleges[i] );
  }

  offset = 0x0bb4;
  misc.budget.roads = [];

  for (let i = 0; i < 27; i++) {
    misc.budget.roads[i] = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                             log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'budget.roads['+i+']',       misc.budget.roads[i] );
  }

  offset = 0x0c20;
  misc.budget.highways = [];

  for (let i = 0; i < 27; i++) {
    misc.budget.highways[i] = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                          log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'budget.highways['+i+']',       misc.budget.highways[i] );
  }

  offset = 0x0c8c;
  misc.budget.bridges = [];

  for (let i = 0; i < 27; i++) {
    misc.budget.bridges[i] = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                           log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'budget.bridges['+i+']',       misc.budget.bridges[i] );
  }

  offset = 0x0cf8;
  misc.budget.rail = [];

  for (let i = 0; i < 27; i++) {
    misc.budget.rail[i] = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                              log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'budget.rail['+i+']',       misc.budget.rail[i] );
  }

  offset = 0x0d64;
  misc.budget.subway = [];

  for (let i = 0; i < 27; i++) {
    misc.budget.subway[i] = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                            log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'budget.subway['+i+']',       misc.budget.subway[i] );
  }

  offset = 0x0dd0;
  misc.budget.tunnel = [];

  for (let i = 0; i < 27; i++) {
    misc.budget.tunnel[i] = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                            log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'budget.tunnel['+i+']',       misc.budget.tunnel[i] );
  }


 
                                                                                                                        log('budget end');
                                                                                                                        log('current offset: 0x'+offset.toString(16).padStart(4, '0'));
                                                                                                                        log('===');
  offset = 0x0e3c;

  misc.yearEnd        = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                                log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'yearEnd',                     misc.yearEnd);
  misc.globalSeaLevel = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                                log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'globalSeaLevel',              misc.globalSeaLevel);
  misc.terrainCoast   = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                                log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'terrainCoast',                misc.terrainCoast);
  misc.terrainRiver   = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                                log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'terrainRiver',                misc.terrainRiver);
  misc.military = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                                      log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'military',                    misc.military);
  

  misc.newspaperList = [];
  for (let i = 0; i < 21; i++) {
    misc.newspaperList[i] = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                            log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'newspaperList['+i+']',                    misc.newspaperList[i]);
  }
  
  offset = 0x0fa0;
                                                                                                                        log('===');
  misc.ordinances    = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                                 log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'ordinances',                  misc.ordinances);
  misc.unemployed    = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                                 log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'unemployed',                  misc.unemployed);

  misc.militaryCount = [];

  for (let i = 0; i < 8; i++) {
    misc.militaryCount[i] = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                            log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'militaryCount['+i+']',               misc.militaryCount[i]);
  }
  
  offset = 0x0fe8;
                                                                                                                        log('===');
  misc.subwayCount   = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                                 log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'subwayCount',                 misc.subwayCount);
  misc.gameSpeed     = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                                 log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'gameSpeed',                   misc.gameSpeed);

  misc.options = {};
  misc.options.autoBudget   = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                          log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'options.autoBudget',        misc.options.autoBudget);
  misc.options.autoGoto     = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                          log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'options.autoGoto',        misc.options.autoGoto);
  misc.options.userSoundOn  = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                          log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'options.userSoundOn',        misc.options.userSoundOn);
  misc.options.userMusicOn  = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                          log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'options.userMusicOn',        misc.options.userMusicOn);
  misc.options.noDisasters  = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                          log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'options.noDisasters',        misc.options.noDisasters);
  misc.options.paperDeliver = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                          log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'options.paperDeliver',        misc.options.paperDeliver);
  misc.options.paperExtra   = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                          log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'options.paperExtra',        misc.options.paperExtra);
  misc.options.paperChoice  = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                          log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'options.paperChoice',        misc.options.paperChoice);

  misc.unknown1 = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                                      log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'unknown1',                     misc.unknown1 );

  misc.camera = {};
  misc.camera.zoom        = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                            log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'camera.zoom',          misc.camera.zoom);
  misc.camera.cityCenterX = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                            log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'camera.cityCenterX',          misc.camera.cityCenterX);
  misc.camera.cityCenterY = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                            log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'camera.cityCenterY',          misc.camera.cityCenterY);

  misc.globalArcoPopulation   = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                        log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'globalArcoPopulation',         misc.globalArcoPopulation);
  misc.connectTiles           = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                        log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'connectTiles',                 misc.connectTiles);
  misc.teamsActive            = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                        log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'teamsActive',                  misc.teamsActive);
  misc.totalPopulation        = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                        log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'totalPopulation',              misc.totalPopulation);
  misc.industryBonus          = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                        log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'industryBonus',                misc.industryBonus);
  misc.polluteBonus           = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                        log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'polluteBonus',                 misc.polluteBonus);
  misc.oldArrest              = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                        log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'oldArrest',                    misc.oldArrest);
  misc.policeBonus            = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                        log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'policeBonus',                  misc.policeBonus);
  misc.disasterObject         = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                        log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'disasterObject',               misc.disasterObject);
  misc.currentDisaster        = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                        log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'currentDisaster',              misc.currentDisaster);
  misc.disasterActive         = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                        log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'disasterActive',                 misc.disasterActive);
  misc.gotoDisaster           = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                        log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'gotoDisaster',                 misc.gotoDisaster);
  misc.sewerBonus             = new DataView(data.slice(offset, offset+=4).buffer).getUint32(0);                        log('offset: 0x'+(offset-4).toString(16).padStart(4, '0'), 'sewerBonus',                   misc.sewerBonus);

  misc.raw = data;

  map._segmentData.MISC = misc;
};

let gameMode = {
  0x00: 'terrainEdit',
  0x01: 'city',
  0x02: 'disaster',
};

let offeredMilitary = {
  0x00: false,
  0x01: true,
};

let militaryType = {
  0x02: 'army',
  0x03: 'air',
  0x04: 'naval',
  0x05: 'missile',
};

let gameSpeed = {
  0x01: 'Paused',
  0x02: 'Turtle',
  0x03: 'Llama',
  0x04: 'Cheetah',
  0x05: 'African Swallow',
};

let weatherTrends = {
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
  0x0A: 'Hurricane',
  0x0B: 'Tornado',
};

let disasters = {
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
  0x0A: 'Microwave',
  0x0B: 'Volcano',
  0x0C: 'Firestorm',
  0x0D: 'Mass Riots',
  0x0E: 'Mass Floods',
  0x0F: 'Pollution Accident',
  0x10: 'Hurricane',
  0x11: 'Helicopter Crash',
  0x12: 'Plane Crash',
};