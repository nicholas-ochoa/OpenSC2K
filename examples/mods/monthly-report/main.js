// Monthly report: writes each month that the City Statistics mod records to
// reports/<city>.csv in the folder of this mod. A spreadsheet can open the file.
//
//   report         shows the last lines of the report of the open city
//
// The mods share no variables: this mod receives the months as
// city-stats.recorded events. info.json names city-stats as a dependency,
// thus the game starts city-stats first, and stops this mod when
// city-stats stops.
// Uses: game.on with the event of another mod, mod.files, game.command.

const HEADER = 'month,population,funds,residential,commercial,industrial\n';

// a file name from the city name, without the characters that a file name cannot have
function reportPath(cityName) {
  const name = String(cityName || 'city').replace(/[^\w -]+/g, '_').trim() || 'city';

  return `reports/${name}.csv`;
}

game.on('city-stats.recorded', (event) => {
  const path = reportPath(event.city);

  if (!mod.files.exists(path)) {
    mod.files.writeText(path, HEADER);
  }

  const demand = event.demand;
  mod.files.appendText(path, `${event.date},${event.population},${event.funds},${demand.residential},${demand.commercial},`
    + `${demand.industrial}\n`);
});

game.command('report', 'Show the last lines of the monthly report of the open city.', () => {
  const path = reportPath(city.name);

  if (!mod.files.exists(path)) {
    return `No report yet. It starts at the next month, in ${path} of the ${mod.name} folder.`;
  }

  const lines = mod.files.readText(path).trimEnd().split('\n');

  return [lines[0], ...lines.slice(1).slice(-12)].join('\n');
});
