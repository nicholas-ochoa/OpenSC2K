// Tax advisor: each month, changes the residential, commercial and
// industrial tax rates by one point toward the demand. High demand raises
// the rate; low demand lowers it. The rates stay from 5% to 12%.
//
//   advisor        shows whether the advisor is on
//   advisor on     turns it on (the default)
//   advisor off    turns it off
//
// Uses: game.on('sim.month'), city.demand, budget.taxes, budget.set.

const LOWEST = 5;
const HIGHEST = 12;
// demand above this raises the rate, and below its negative lowers it
const THRESHOLD = 500;
let active = true;

function step(rate, demand) {
  if (demand > THRESHOLD) {
    return Math.min(HIGHEST, rate + 1);
  }

  if (demand < -THRESHOLD) {
    return Math.max(LOWEST, rate - 1);
  }

  return rate;
}

export function advise() {
  const demand = city.demand;
  const taxes = budget.taxes;
  const next = {
    residential: step(taxes.residential, demand.residential),
    commercial: step(taxes.commercial, demand.commercial),
    industrial: step(taxes.industrial, demand.industrial),
  };

  if (Object.keys(next).some((key) => next[key] !== taxes[key])) {
    budget.set({ taxes: next });
    console.log(`Tax advisor: R ${next.residential}%, C ${next.commercial}%, I ${next.industrial}%.`);
  }

  return next;
}

game.on('sim.month', () => {
  if (active) {
    advise();
  }
});

game.command('advisor', 'Turn the tax advisor on or off: advisor [on|off].', (state) => {
  if (state === 'on' || state === 'off') {
    active = state === 'on';
  }

  return `The tax advisor is ${active ? 'on' : 'off'}.`;
});
