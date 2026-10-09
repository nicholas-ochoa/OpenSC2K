// Disaster response: pauses the game when a disaster starts, tells the
// player, and reports the cost when the disaster ends.
//
// Uses: disaster.started and disaster.ended, sim.speed, ui.alert, city.funds.

let response = null;

game.on('disaster.started', (event) => {
  response = { name: event.name, funds: city.funds, speed: sim.speed, started: city.date };
  sim.pause();
  ui.alert(`A ${event.name.toLowerCase()} started. The game is paused.\nSelect a speed to continue.`, 'Emergency');
});

game.on('disaster.ended', (event) => {
  if (!response) {
    return;
  }

  const spent = response.funds - city.funds;
  console.log(`${event.name} ended. Funds changed by $${-spent} since it started.`);
  game.status(`The ${event.name.toLowerCase()} is over.`);
  response = null;
});
