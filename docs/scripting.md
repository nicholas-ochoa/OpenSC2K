# Scripting

OpenSC2K runs JavaScript for mods and developer tools. The runtime is
[QuickJS-ng](https://github.com/quickjs-ng/quickjs) 0.17.0, an ES2023 engine, in
the native `scripting` library (see [Native scripting](native-scripting.md)).
Scripts can read and change the city, use the player tools, control the
simulation, and react to game events. Chrome DevTools can connect to the runtime.
A mod is a folder with an `info.json` file that the game loads at start; see
[Mods](mods.md).

This API is new. Names and fields can change.

- [Run scripts](#run-scripts)
- [Chrome DevTools](#chrome-devtools)
- [Example mods](#example-mods)
- [Mods](mods.md): the mod folder, info.json, the sandbox, `mod.files`, the Mods tab
- [Rules for scripts](#rules-for-scripts)
- [Globals](#globals)
- [game](#game): events, console commands, storage, status bar
- [city](#city): city values, tiles, data maps, graphs, signs, name
- [budget](#budget): taxes, funding, ordinances, bonds
- [sim](#sim): speed, steps, dates, disasters
- [tools](#tools): select and use the player tools
- [view](#view): camera, zoom, rotation, view modes
- [ui](#ui): message windows, sounds
- [Events](#events)
- [Values between scripts and the game](#values-between-scripts-and-the-game)
- [Add a game function](#add-a-game-function)

## Run scripts

**Console.** Open the Console with Cmd+Shift+J (Ctrl+Shift+J on Windows and
Linux) or Windows > Console. Input that is not a console command runs as
JavaScript, and the console shows its value. Declarations stay for the next
input. Top-level `await` is permitted. Shift+Enter starts a new line.

```text
> city.population
187569
> const site = city.tile(64, 64)
> site.data.pollution
12
> await new Promise((done) => setTimeout(() => done('later'), 500))
"later"
```

**Script files.** In debug mode, select **Debug > Run Script File**, then select a
`.js` or `.mjs` file. Or type `run <path>` in the Console. A relative path starts in
the `scripts` folder of the user data folder.

A file with `import` or `export`, or an `.mjs` file, runs as an ES module. It can
import other files by a relative path:

```js
import { money } from './lib/format.mjs';
```

**Console commands of the runtime**

| Command | Effect |
| --- | --- |
| `run <path>` | Runs a script file. |
| `reset` | Stops all scripts: their listeners, timers and console commands. The mods load again. Also **Debug > Reset Script Runtime**. |
| `scripts` | Shows the listeners, timers, commands and memory of each runtime. |
| `inspect [port]`, `inspect off` | Starts or stops the DevTools inspector. See [Chrome DevTools](#chrome-devtools). |
| `inspect <mod id> [port]`, `inspect <mod id> off` | Starts or stops the DevTools inspector of a mod. Port 0, the default, selects a free port. |
| `mods`, `mods enable <id>`, `mods disable <id>`, `mods reload` | Lists, turns on, turns off or reloads the mods. See [Mods](mods.md). |

The console runtime starts at its first use. All console input and script files
share its global scope. A script stays active until a reset: its listeners,
timers and commands continue after the file ran. Mods do not run in this
runtime; see [Mods](mods.md).

## Chrome DevTools

Chrome DevTools can connect to the script runtime, as to Node.js:

1. Start the inspector. Type `inspect` in the Console, select
   **Debug > Script Inspector**, or start the game with `--inspect` (port 9229)
   or `--inspect=PORT`.
2. In Chrome, open `chrome://inspect`. OpenSC2K shows under **Remote Target**.
   Select **inspect**. Or open the DevTools page that the `inspect` command
   prints: `devtools://devtools/bundled/js_app.html?experiments=true&v8only=true&ws=127.0.0.1:9229/opensc2k`.

DevTools then gives:

- **Console.** Evaluation with top-level `await`, objects that you can expand,
  previews, autocompletion, and `console` output with links to the source lines.
  Uncaught errors show with their stacks. The game console output also shows,
  with its warnings and errors. A new DevTools window first gets the last 200 lines.
- **Sources.** Each script file and module that ran, with its source.
- **Memory.** The heap size of the runtime.

This is not a full debugger yet. QuickJS-ng has no API for breakpoints, so
breakpoints, pausing and stepping do not work. The Debugger methods for them
answer with an error.

The inspector listens on 127.0.0.1 only, and it refuses requests with another
Host header. One DevTools window can connect at a time; a new one replaces the
old one. While you type, DevTools evaluates only names and property reads, thus
eager evaluation cannot change the game. A reset of the runtime keeps the same
address, and DevTools can reconnect.

## Example mods

The folder `examples/mods` holds example mods. Copy a mod folder into the
`mods` folder of the data folder; see [Install a mod](mods.md#install-a-mod).

| Mod | It shows |
| --- | --- |
| `yearly-grant` | A yearly event, funds, `game.storage`, a console command with an argument. |
| `disaster-response` | Disaster events, pausing, a message window. |
| `city-stats` | An ES module with a helper import, monthly records in storage, a text table, an event for other mods. |
| `monthly-report` | A dependency, the event of another mod, CSV files with `mod.files`. |
| `protected-zones` | A cancelable tool event that protects areas from the bulldozer, signs. |
| `road-grid` | Building with `tools.select` and `tools.apply`. |
| `tax-advisor` | Monthly tax changes from the demand with the `budget` API. |

## Rules for scripts

- **Time.** One call from the game into scripts can take 5 seconds at most. A
  longer script stops with `InternalError: interrupted`. This applies to console
  input, a file, each event, timer and command.
- **Memory.** Each runtime can use 256 MiB.
- **Thread.** Scripts run on the main thread, between simulation ticks. A change
  that a script makes to the city stops the simulation tick that runs at that time.
  The simulation then runs the tick again with the change.
- **Errors.** An uncaught error in a listener, a timer or a promise shows in the
  Console with its stack. It does not stop the other listeners.
- **Access.** There is no file, network or process access, except `game.storage`
  and the import of module files. A mod can use files and import modules only in
  its own folder; see [The sandbox](mods.md#the-sandbox).
- **Runtimes.** Console input and script files share the console runtime. Each
  mod has its own runtime. Runtimes share no variables; they talk through
  `game.emit` events.
- **Game rules.** The tool, budget and disaster functions follow the game rules,
  costs and prompts, as the player's actions do. Some functions are cheats, as in
  the Debug window: `city.funds = ...`, `city.addFunds`, `sim.startDisaster`,
  `sim.endDisaster`, `sim.noDisasters`. A save keeps their changes.
- **No city.** The functions of `city`, `budget`, `sim`, `tools` and `view` throw
  an Error when no city is loaded. `city.loaded` tells if a city is open.

## Globals

| Name | Use |
| --- | --- |
| `console` | `log`, `info`, `debug`, `warn`, `error`, `trace`, `dir`, `assert`, `count`, `countReset`, `time`, `timeEnd`. The output goes to the game Console and to DevTools. |
| `setTimeout(callback, ms, ...arguments)`, `setInterval`, `clearTimeout`, `clearInterval` | Timers in real time. They run once each frame at most, also while the game is paused. |
| `inspect(value, { depth })` | The text that the console shows for a value. |
| `game`, `city`, `budget`, `sim`, `tools`, `view`, `ui` | The game API. |

The standard JavaScript built-ins are available: `Promise`, `Map`, `Set`, `JSON`,
`Math`, `Date`, typed arrays, `WeakRef` and the others of ES2023.

```js
// console output in the game Console and in DevTools
console.info('Mod loaded.', game.version);
console.warn('Funds are low:', city.funds);
console.error(new Error('This shows with its stack.'));
console.debug({ tile: city.tile(10, 10) });
console.dir(city.info(), { depth: 0 });
console.trace('Where was this called from?');
console.assert(city.size >= 128, 'This mod needs a map of 128 tiles or more.');

// counters and timings
console.count('visits'); // visits: 1
console.count('visits'); // visits: 2
console.countReset('visits');
console.time('scan');
let water = 0;

for (let x = 0; x < city.size; x++) {
  water += city.tile(x, 0).water ? 1 : 0;
}

console.timeEnd('scan'); // scan: 3 ms

// timers
const reminder = setTimeout(() => game.status('Remember to save.'), 60000);
clearTimeout(reminder);
const clock = setInterval(() => console.log(city.date), 1000);
setTimeout(() => clearInterval(clock), 5000);

// the console text of a value, as a string
const text = inspect({ outer: { inner: { deepest: 1 } } }, { depth: 0 });
console.log(text); // { outer: [Object] }
```

## game

| Member | Use |
| --- | --- |
| `game.on(type, listener, { once })` | Calls `listener(event)` for each event of the type. `'*'` listens to all events. Returns a function that removes the listener. |
| `game.once(type, listener)` | Listens to the next event of the type only. |
| `game.off(type, listener)` | Removes a listener. Returns true when it was there. |
| `game.listenerCount(type)` | The number of listeners of the type. |
| `game.emit(type, detail)` | Sends an event to the script listeners of the console and of each mod. Each runtime gets a copy of `detail`, with `source`: the id of the sending mod, or `console`. A mod cannot send a game event. Use it to connect mods. |
| `game.mods` | The info of each mod that runs: `[{ id, name, version, ... }]`. |
| `game.command(name, description, handler)` | Adds a console command. `handler(...words)` returns the text to show, a value, or a promise. A script cannot replace a game command. |
| `game.status(text)` | Shows a message on the status bar. |
| `game.storage.get(key, fallback)` | A stored value, or the fallback. |
| `game.storage.set(key, value)` | Stores a JSON value. It stays after the game closes. |
| `game.storage.remove(key)`, `game.storage.keys()` | Removes a value; lists the keys. |
| `game.version` | `{ game, godot, quickjs }`. |
| `game.events` | The event types and their descriptions. |

The console scripts share one storage file, `scripts/storage.json` in the user
data folder. Each mod has its own values, in `storage.json` in its folder.

```js
// a listener for one event, removed after five days
let days = 0;
const stop = game.on('sim.day', (event) => {
  days += 1;
  console.log(`Day ${event.day} of month ${event.month}`);

  if (days === 5) {
    stop();
  }
});

// a console command: "bonus 500"
game.command('bonus', 'Add funds: bonus <amount>.', (amount) => `Funds: ${city.addFunds(Number(amount))}`);

// a value that stays after the game closes
const launches = game.storage.get('my-mod.launches', 0) + 1;
game.storage.set('my-mod.launches', launches);

// mods can talk through their own events
game.on('my-mod.ready', (event) => console.log('ready', event.version));
game.emit('my-mod.ready', { version: 2 });
```

```js
// listeners that you remove again
function onDay(event) {
  console.log(`Day ${event.day}`);
}

game.on('sim.day', onDay);
console.log(game.listenerCount('sim.day')); // 1
game.off('sim.day', onDay);

// the versions and the event types
console.log(`OpenSC2K ${game.version.game}, Godot ${game.version.godot}, QuickJS-ng ${game.version.quickjs}`);

for (const [type, description] of Object.entries(game.events)) {
  console.log(`${type}: ${description}`);
}

// remove all stored values of one mod
for (const key of game.storage.keys()) {
  if (key.startsWith('my-mod.')) {
    game.storage.remove(key);
  }
}
```

## city

| Member | Use |
| --- | --- |
| `city.loaded` | True when a city is open. |
| `city.info()` | `{ name, mayor, size, funds, population, foundingYear, difficulty, scenario, path, date, demand }`. |
| `city.name`, `city.mayor`, `city.size`, `city.population` | Single values. `size` is the number of tiles on each map edge. |
| `city.date` | `{ year, month, day, age }`. A month has 25 days. `age` counts the days from the founding. |
| `city.demand` | `{ residential, commercial, industrial }`, from -2000 to 2000. |
| `city.funds` | Get or set the funds. |
| `city.addFunds(amount)` | Adds a positive or negative amount. Returns the new funds. |
| `city.tile(x, y)` | The stored values of a tile, or `null` outside the map. See below. |
| `city.data(name, x, y)` | The value of a data map at a tile. |
| `city.dataMap(name)` | A whole data map: `{ name, size, scale, values, at(x, y) }`. |
| `city.dataMaps` | The data map names: `traffic`, `pollution`, `landValue`, `crime`, `police`, `fire`, `populationDensity`, `growth`. |
| `city.graph(name, period)` | A graph history, oldest value first. `period` is `'year'` (12 values, the default), `'decade'` (20) or `'century'` (20). |
| `city.graphs` | The graph names, as the Graphs window shows them: `City Size`, `Residents`, `Commerce`, `Industry`, `Traffic`, `Pollution`, `Value`, `Crime`, `Power %`, `Water %`, `Health`, `Education`, `Unemployment`, `GNP`, `Nat'n Pop.`, `Fed Rate`. |
| `city.rename(name)` | Gives the city a new name. Returns the name. |
| `city.sign(x, y)` | The text of the sign on a tile, or `null`. |
| `city.setSign(x, y, text)` | Places or changes a sign, as the Sign tool does. An empty text removes it. Undo reverses it. |
| `city.things()` | The moving objects: `{ id, type, name, x, y, state }`. |
| `city.save()` | Saves the city to its file. A new city must be saved once from the File menu first. |

A point can be `(x, y)`, `({ x, y })` or `([x, y])`. Tile coordinates go from 0
to `city.size - 1`.

`city.tile(x, y)` gives `{ x, y, altitude, waterAltitude, terrain, building, zone,
underground, overlay, water, saltWater, powered, powerable, watered, piped,
traffic, data }`. `terrain`, `building`, `zone` and `underground` are the stored
IDs of the XTER, XBLD, XZON and XUND maps. `data` holds the value of each data map.

A data map can have fewer cells than the map has tiles. Then one cell covers
`scale` by `scale` tiles: `size` is the number of cells on each edge, and the
value of cell `(gx, gy)` is `values[gx * size + gy]`. `at(x, y)` reads the cell
of a tile.

```js
// the most polluted tile
const pollution = city.dataMap('pollution');
let worst = { value: -1 };

for (let x = 0; x < city.size; x += pollution.scale) {
  for (let y = 0; y < city.size; y += pollution.scale) {
    const value = pollution.at(x, y);

    if (value > worst.value) {
      worst = { x, y, value };
    }
  }
}

view.centerOn(worst.x, worst.y);

// the population trend of the last 12 months
const residents = city.graph('Residents');
console.log(`Residents changed by ${residents.at(-1) - residents[0]} this year`);

// a sign on each powered tile with no building, in one row
for (let x = 0; x < city.size; x++) {
  const tile = city.tile(x, 40);

  if (tile.powered && tile.building === 0) {
    city.setSign(x, 40, 'Free lot');
  }
}
```

```js
// the city values
if (!city.loaded) {
  throw new Error('Open a city first.');
}

const info = city.info();
console.log(`${city.name}, mayor ${city.mayor}, founded ${info.foundingYear}: ${city.population} people`);
console.log(`Date: ${city.date.month}/${city.date.day}/${city.date.year}, ${city.date.age} days old`);

// the demand of each zone type
const demand = city.demand;

if (demand.residential > demand.commercial && demand.residential > demand.industrial) {
  game.status('People want to move here: zone more homes.');
}

// every data map at the view center
const center = view.center;

for (const name of city.dataMaps) {
  console.log(`${name}: ${city.data(name, center.x, center.y)}`);
}

// the newest value of every graph
for (const name of city.graphs) {
  console.log(`${name}: ${city.graph(name).at(-1)}`);
}

// the name and the signs
city.rename(`${city.name} Heights`);

if (city.sign(20, 20) === null) {
  city.setSign(20, 20, 'Welcome');
}

// the moving objects, such as trains and helicopters
const trains = city.things().filter((thing) => thing.name === 'Train engine');
console.log(`${trains.length} trains run now`);

// save the city to its file, when it has one
if (city.info().path) {
  city.save();
}
```

## budget

| Member | Use |
| --- | --- |
| `budget.info()` | `{ taxes, funding, autoBudget, bonds }`. |
| `budget.taxes` | `{ residential, commercial, industrial }`, tax rates in percent. |
| `budget.funding` | `{ police, fire, health, school, college, road, highway, bridge, rail, subway, tunnel }`, in percent. |
| `budget.set(changes)` | Changes the named values: `{ taxes, funding, autoBudget }`. Tax rates go from 0 to 22, funding from 0 to 100. Returns `budget.info()`. |
| `budget.ordinances()` | Each ordinance: `{ key, name, category, enabled, cost }`. `cost` is the yearly amount; a tax ordinance has income. |
| `budget.setOrdinance(key, enabled)` | Enables or disables an ordinance by its key or its name. Returns the new state. |
| `budget.issueBond()` | Issues a $10,000 bond, as the Budget window does after confirmation. Returns `{ bonds, rate, funds }`. It throws when the council refuses the bond. |
| `budget.repayBond()` | Repays the oldest bond. |

The ordinance keys are `salesTax`, `incomeTax`, `legalizedGambling`,
`parkingFines`, `volunteerFire`, `publicSmokingBan`, `freeClinics`, `juniorSports`,
`proReading`, `antiDrug`, `cprTraining`, `neighborhoodWatch`, `touristAdvertising`,
`businessAdvertising`, `cityBeautification`, `annualCarnival`,
`energyConservation`, `nuclearFreeZone`, `homelessShelter` and `pollutionControls`.

The budget cannot change while the yearly budget window is open.

```js
// lower the industrial tax and fund the police fully
budget.set({ taxes: { industrial: 5 }, funding: { police: 100 } });

// enable all safety ordinances
for (const ordinance of budget.ordinances()) {
  if (ordinance.category === 'Safety & Health') {
    budget.setOrdinance(ordinance.key, true);
  }
}

// borrow when the funds are low
game.on('sim.month', () => {
  if (city.funds < 0) {
    try {
      budget.issueBond();
    } catch (error) {
      console.warn(error.message);
    }
  }
});
```

```js
// read the budget
const { taxes, funding, autoBudget, bonds } = budget.info();
console.log(`Taxes R${taxes.residential}% C${taxes.commercial}% I${taxes.industrial}%, ${bonds} bonds`);
console.log(`Police ${budget.funding.police}%, fire ${funding.fire}%, automatic budget ${autoBudget}`);

// the same tax for all zones
const rate = budget.taxes.residential;
budget.set({ taxes: { commercial: rate, industrial: rate }, autoBudget: true });

// repay bonds while the funds are high
while (budget.info().bonds > 0 && city.funds > 50000) {
  budget.repayBond();
}
```

## sim

| Member | Use |
| --- | --- |
| `sim.speed` | Get or set the speed: `'Paused'`, `'Turtle'`, `'Llama'`, `'Cheetah'`, `'African Swallow'`, or 1 to 5. |
| `sim.paused`, `sim.pause()`, `sim.resume()` | `resume` selects the speed before the pause. |
| `sim.step()` | Runs one day while the game is paused, as Debug > Advance One Day does. Returns a report. |
| `sim.runUntil(date, speed)` | Runs at the speed (default `'Cheetah'`) until the date `{ year, month, day }`, then pauses. |
| `sim.disaster` | The active disaster `{ id, name }`, or `null`. |
| `sim.disasters` | The disaster names and IDs. |
| `sim.startDisaster(disaster, x, y)` | Starts a disaster by name or ID at a tile. Without a tile, it starts at the view center. |
| `sim.endDisaster()` | Ends the active disaster and clears its marks, as the Debug window does. False without a disaster. |
| `sim.noDisasters` | Get or set: true turns the random disasters off. |

```js
// run to the next year, then show the population
sim.runUntil({ year: city.date.year + 1, month: 1, day: 1 });
game.once('sim.speed', (event) => {
  if (event.speed === 'Paused') {
    console.log(`Population on ${city.date.year}-01-01: ${city.population}`);
  }
});

// a disaster drill at the city center, stopped after ten seconds
sim.startDisaster('Fire', city.size / 2, city.size / 2);
setTimeout(() => sim.endDisaster(), 10000);
```

```js
// one day at a time
sim.pause();
console.log(sim.paused); // true
console.log(sim.step()); // Day ran in 4.1 ms. ...
sim.resume();
sim.pause();

// the disasters and the active one
console.log(Object.keys(sim.disasters).join(', '));

if (sim.disaster) {
  console.log(`A ${sim.disaster.name.toLowerCase()} is active.`);
}

// no random disasters while a mod builds
sim.noDisasters = true;
```

## tools

| Member | Use |
| --- | --- |
| `tools.list()` | Every tool: `{ group, subtool, groupName, name, cost, available }`. |
| `tools.selected` | The selected tool: `{ group, subtool, groupName, name, cost }`. |
| `tools.select(group, tool)` | Selects a tool by its group and tool name or index, for example `tools.select('Roads', 'Road')`. With one name: a tool name in any group, or a group name, which selects the tool of that group that was used last. The rules of the toolbar apply. |
| `tools.apply(from, to)` | Uses the selected tool as a drag from one tile to another. Without `to`, it is a click. Returns the `tool.applied` detail. |
| `tools.undo()` | Undoes the last edit, as Undo does. False when there is nothing to undo. |

`tools.apply` follows the tool rules, the costs and the prompts of the game. A
line tool such as Road follows the path that a drag makes: first along the longer
axis. A zone tool fills the rectangle. A tool that needs a choice, such as a
bridge, opens its window.

```js
// a block of dense residential zones beside a road
tools.select('Roads', 'Road');
tools.apply([30, 30], [40, 30]);
tools.select('Residential', 'Dense Residential');
const result = tools.apply([30, 31], [40, 33]);
console.log(result.changed ? `Zoned for $${result.cost}` : result.message);
```

```js
// the tools that the city can use and pay for
const affordable = tools.list().filter((tool) => tool.available && tool.cost <= city.funds);
console.log(`${affordable.length} tools are available`);

// plant trees, then undo it, and select the previous tool again
const previous = tools.selected;
tools.select('Landscape', 'Trees');
const planted = tools.apply([5, 5], [8, 5]);

if (planted.changed) {
  tools.undo();
}

tools.select(previous.group, previous.subtool);
```

## view

| Member | Use |
| --- | --- |
| `view.center` | The tile at the center of the view: `{ x, y }`. |
| `view.centerOn(x, y)` | Moves the view to a tile. |
| `view.mode` | Get or set the view: `'city'`, `'underground'`, `'density'`, `'growth'`, `'traffic'`, `'pollution'`, `'crime'`, `'police_power'`, `'fire_power'`, `'land_value'`, `'water'`, `'power'`, `'height'`. |
| `view.modes` | The view names. |
| `view.zoom`, `view.zoomIn()`, `view.zoomOut()` | The zoom in percent. |
| `view.rotation`, `view.rotate(clockwise)` | The compass rotation (0 to 3), and a quarter turn, clockwise unless the argument is false. |

```js
// show the traffic view for five seconds
const before = view.mode;
view.mode = 'traffic';
setTimeout(() => (view.mode = before), 5000);
```

```js
// the view names
console.log(view.modes.join(', '));

// zoom in two steps and back
const zoom = view.zoom;
view.zoomIn();
view.zoomIn();
view.zoomOut();
view.zoomOut();
console.log(view.zoom === zoom); // true

// a full turn of the map
const rotation = view.rotation;

for (let turn = 0; turn < 4; turn++) {
  view.rotate();
}

view.rotate(false);
view.rotate(true);
console.log(view.rotation === rotation); // true
```

## ui

| Member | Use |
| --- | --- |
| `ui.alert(text, title)` | A message window with an OK button. The game continues while it shows. |
| `ui.status(text)` | Shows a message on the status bar, as `game.status`. |
| `ui.playSound(id)` | Plays `SOUNDS/<id>.WAV` of the sound pack, for example `500`. |

```js
ui.alert(`Welcome to ${city.name}!`, 'My mod');
ui.status('My mod is ready.');
ui.playSound(500);
```

## Events

A listener receives an event object: the `type`, and the fields below. For a
cancelable event, `event.cancel()` stops the action of the game, and
`event.cancelled` tells if a listener cancelled it. The game sends an event
only while a script listens to its type, thus an event without listeners costs
nothing. `game.events` lists the types.

| Type | Fields | When |
| --- | --- | --- |
| `city.opened` | `name`, `size`, `date` | A city opens. |
| `city.closed` | | The city closes after the game ends. |
| `city.saved` | `path` | The city was saved. |
| `city.renamed` | `name` | The city has a new name. |
| `budget.changed` | `taxes`, `funding`, `autoBudget`, `bonds` | The Budget window, the yearly budget or a script changed the budget. |
| `sim.day` | `year`, `month`, `day`, `age` | A simulation day ended. |
| `sim.month` | `year`, `month` | A new month started. |
| `sim.year` | `year` | A new year started. |
| `sim.speed` | `speed` | The speed changed: by the player, a script, a pause on the `runUntil` date, or a disaster that slows African Swallow to Cheetah. |
| `disaster.beforeStart` | `id`, `name`, `x`, `y` | A menu or a script starts a disaster. Cancelable. The simulation starts other disasters itself. |
| `disaster.started`, `disaster.ended` | `id`, `name` | The active disaster changed. |
| `news` | `type`, `argument` | The simulation sent a news story. |
| `notice` | `id` | The simulation shows a notice. |
| `budget.prompt` | | The yearly budget opens. |
| `military.proposal` | | The military asks for a base. |
| `game.over` | `type`, `funds` | The game ended, or the scenario was won. |
| `tool.selected` | `tool` | A tool was selected. |
| `tool.beforeApply` | `tool`, `start`, `finish`, `dragged`, `tiles` | A tool is about to change the map. Cancelable. |
| `tool.applied` | `tool`, `start`, `finish`, `dragged`, `tiles`, `changed`, `cancelled`, `command`, `cost`, `message` | A tool was used. `changed` is true when the tool made an edit that Undo can reverse. |
| `tool.undone` | `command` | The last edit was undone. |
| `view.mode` | `mode` | The view changed. |
| `frame` | `delta` | A frame started. `delta` is in seconds. Timers are better for most work. |
| `mod.loaded` | `id`, `name`, `version` | A mod started. |
| `mod.unloaded` | `id` | A mod stopped. |

`tool` is `{ group, subtool, groupName, name, cost }`. `start` and `finish` are
`{ x, y }`. The console runtime receives each event first, then each mod in load
order. When a listener cancels a cancelable event, the later runtimes see
`event.cancelled`.

```js
// no bulldozer on the first ten rows
game.on('tool.beforeApply', (event) => {
  if (event.tool.groupName === 'Bulldozer' && Math.min(event.start.y, event.finish.y) < 10) {
    event.cancel();
    game.status('The old town is protected.');
  }
});

// a log of every game event
game.on('*', (event) => console.debug(event.type, event));
```

```js
// city events
game.on('city.opened', (event) => console.log(`Opened ${event.name}, ${event.size} tiles wide, in ${event.date.year}`));
game.on('city.closed', () => console.log('The city closed.'));
game.on('city.saved', (event) => console.log(`Saved to ${event.path}`));
game.on('city.renamed', (event) => console.log(`The city is now ${event.name}`));
game.on('budget.changed', (event) => console.log(`The residential tax is ${event.taxes.residential}%`));

// simulation events
game.on('sim.year', (event) => console.log(`Happy new year ${event.year}!`));
game.on('sim.speed', (event) => console.log(`Speed: ${event.speed}`));
game.on('news', (event) => console.log(`News story ${event.type} (${event.argument})`));
game.on('notice', (event) => console.log(`Notice ${event.id}`));
game.on('budget.prompt', () => game.status('Check the yearly budget.'));
game.on('military.proposal', () => game.status('The military wants a base.'));
game.on('game.over', (event) => console.log(`Game over: ${event.type}, funds $${event.funds}`));

// disasters: no fires from menus or scripts, and a log of the others
game.on('disaster.beforeStart', (event) => {
  if (event.name === 'Fire') {
    event.cancel();
  }
});
game.on('disaster.started', (event) => console.log(`${event.name} started`));
game.on('disaster.ended', (event) => console.log(`${event.name} ended`));

// tools
game.on('tool.selected', (event) => console.log(`Selected ${event.tool.groupName} > ${event.tool.name}`));
game.on('tool.applied', (event) => {
  if (event.changed) {
    console.log(`${event.tool.name} on ${event.tiles} tiles cost $${event.cost}`);
  } else if (!event.cancelled) {
    console.log(`${event.tool.name} did nothing: ${event.message}`);
  }
});
game.on('tool.undone', (event) => console.log(`Undid a ${event.command} edit`));

// mods that start and stop
game.on('mod.loaded', (event) => console.log(`${event.name} ${event.version} runs`));
game.on('mod.unloaded', (event) => console.log(`${event.id} stopped`));

// the view, and one frame
game.on('view.mode', (event) => console.log(`View: ${event.mode}`));
game.once('frame', (event) => console.log(`The frame took ${(event.delta * 1000).toFixed(1)} ms`));
```

## Values between scripts and the game

A JavaScript number becomes an `int` when it is a whole number, and a `float` in
other cases. An object becomes a Dictionary, and an array becomes an Array. A
function or a symbol becomes `null`. From the game, a `Vector2i` becomes `{ x, y }`,
a `Rect2i` becomes `{ x, y, width, height }`, and a packed array becomes an array.

## Add a game function

The game API has three parts:

1. `game/assets/scripting/api.js` defines the JavaScript objects. Each member calls
   `__runtime.host(name, ...arguments)`. `game/assets/scripting/opensc2k.d.ts`
   declares their types; add each new member there too.
2. GDScript functions answer the host calls. `ApplicationScriptingApi` in
   `game/src/application/scripting_api.gd` holds `game`, `sim`, `tools` and `view`;
   `ScriptingCityApi`, `ScriptingBudgetApi` and `ScriptingUiApi` hold the others.
   Each class maps names to functions in `handlers()`. A function receives the
   arguments as an Array and returns the result. A failed call returns
   `fail(message)`; the script then gets an Error. `ScriptingApiBase` has the
   shared helpers: `need_city`, `point`, `argument` and `inside_map`.
3. `ApplicationScripting.emit(type, detail, cancelable)` sends an event.
   `cancelled(type, detail)` sends a cancelable event and returns true when a
   listener cancelled it. Add each new event type to `ApplicationScripting.EVENTS`.
   `ApplicationScripting._host` receives the `ScriptContext` of the calling
   runtime, for functions that differ between mods, such as `game.storage`.

Add a test to the `scripting` validation domain for each new function and event:
`tools/validate_project.sh --suite scripting`.
