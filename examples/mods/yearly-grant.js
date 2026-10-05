// Yearly grant: the state pays the city a grant at the start of each year.
//
//   grant          shows the amount
//   grant 2500     sets the amount; the game keeps it in game.storage
//
// Uses: game.on('sim.year'), city.addFunds, game.storage, game.command.

const STORAGE_KEY = 'yearly-grant.amount';
const DEFAULT_AMOUNT = 1000;

game.on('sim.year', (event) => {
  const amount = game.storage.get(STORAGE_KEY, DEFAULT_AMOUNT);
  const funds = city.addFunds(amount);

  game.status(`The ${event.year} state grant of $${amount} arrived. Funds: $${funds}.`);
});

game.command('grant', 'Show or set the yearly grant: grant [amount].', (amount) => {
  if (amount === undefined) {
    return `The yearly grant is $${game.storage.get(STORAGE_KEY, DEFAULT_AMOUNT)}.`;
  }

  const value = Number(amount);

  if (!Number.isInteger(value) || value < 0) {
    throw new Error('The grant must be a whole number of dollars.');
  }

  game.storage.set(STORAGE_KEY, value);

  return `The yearly grant is now $${value}.`;
});

console.log('Yearly grant loaded. Type grant to see the amount.');
