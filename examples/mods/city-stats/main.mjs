// City statistics: records the population, the funds and the demand at the
// start of each month, and shows them as a table.
//
//   stats          the last 12 months
//   stats 24       the last 24 months
//   stats clear    removes the history
//
// A module: it imports its helpers from ./format.mjs. The history stays in
// game.storage, thus it is there after the game restarts.
// Each recorded month goes to the other mods as a city-stats.recorded event.
// Uses: game.on('sim.month'), city.info, game.storage, game.emit, game.command, ES modules.

import { money, table } from './format.mjs';

const STORAGE_KEY = 'city-stats.history';
// the most months that the history keeps
const LIMIT = 240;

function history() {
  return game.storage.get(STORAGE_KEY, []);
}

function record() {
  const info = city.info();
  const rows = history();
  rows.push({
    date: `${info.date.year}-${String(info.date.month).padStart(2, '0')}`,
    city: info.name,
    population: info.population,
    funds: info.funds,
    demand: info.demand,
  });
  game.storage.set(STORAGE_KEY, rows.slice(-LIMIT));

  // other mods, such as monthly-report, receive a copy of the row
  game.emit('city-stats.recorded', rows[rows.length - 1]);
}

game.on('sim.month', record);

game.command('stats', 'Show the monthly city statistics: stats [months], or stats clear.', (argument = '12') => {
  if (argument === 'clear') {
    game.storage.remove(STORAGE_KEY);

    return 'The statistics history is empty.';
  }

  const rows = history().slice(-Number(argument));

  if (rows.length === 0) {
    return 'No months were recorded yet. Let the simulation run into a new month.';
  }

  return table(
    ['Month', 'Population', 'Funds', 'R', 'C', 'I'],
    rows.map((row) => [row.date, row.population.toLocaleString('en-US'), money(row.funds), row.demand.residential, row.demand.commercial,
      row.demand.industrial]),
  );
});

export { record };
