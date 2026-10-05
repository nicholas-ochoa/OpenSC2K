# Scripting

OpenSC2K runs JavaScript for mods and developer tools. The runtime is
[QuickJS-ng](https://github.com/quickjs-ng/quickjs) 0.17.0, an ES2023 engine,
in the native `scripting` library (see [Native scripting](native-scripting.md)).
This API is new. Names and fields can change.

## Run scripts

- **Console.** Open the Console (Cmd+Shift+J or Ctrl+Shift+J). Input that is not
  a console command runs as JavaScript. The console shows the value of the input.
  Declarations stay for the next input, and top-level `await` is permitted.
  Shift+Enter starts a new line.
- **Script files.** In debug mode, select **Debug > Run Script File** and select
  a `.js` or `.mjs` file. Or type `run <path>` in the Console. A relative path
  starts in the `scripts` folder of the user data folder.
- A file with `import` or `export`, or an `.mjs` file, runs as an ES module. It
  can import other files by relative path, for example
  `import { tax } from './lib/tax.js'`.

The runtime starts at its first use. All scripts share one global scope. Their
listeners, timers and console commands stay active until a reset. To stop all
scripts, select **Debug > Reset Script Runtime** or type `reset`. Type `scripts`
to show the listeners, timers, commands and memory of the runtime.

One call from the game into scripts can take 5 seconds at most. A longer script
stops with `InternalError: interrupted`. The runtime can use 256 MiB of memory.
Scripts run on the main thread between simulation ticks. A change that a script
makes to the city stops the simulation tick that runs at that time, and the
simulation then runs the tick again with the change.

An uncaught error in a listener, a timer or a promise shows in the Console with
its stack. It does not stop the other listeners.

## Example

```js
// Pay a grant at the start of each year, and protect the city hall area
game.on('sim.year', (event) => {
  city.addFunds(1000);
  game.status(`The ${event.year} grant arrived.`);
});

game.on('tool.beforeApply', (event) => {
  if (event.tool.groupName === 'Bulldozer' && event.start.x < 10) {
    event.cancel();
  }
});

game.command('rich', 'Add $100,000.', () => `Funds: ${city.addFunds(100000)}`);
```

## Globals

| Name | Use |
| --- | --- |
| `console` | `log`, `info`, `debug`, `warn`, `error`, `trace`, `dir`, `assert`, `count`, `countReset`, `time`, `timeEnd`. |
| `setTimeout`, `setInterval`, `clearTimeout`, `clearInterval` | Timers in real time. They run once each frame at most, also while the game is paused. |
| `inspect(value, { depth })` | The text that the console shows for a value. |
| `game`, `city`, `sim`, `tools`, `view` | The game API. |

The standard JavaScript built-ins are available. There is no file, network or
process access, except the import of module files.

## game

| Member | Use |
| --- | --- |
| `game.on(type, listener, { once })` | Calls `listener(event)` for each event of the type. `'*'` listens to all events. Returns a function that removes the listener. |
| `game.once(type, listener)` | Listens to the next event of the type only. |
| `game.off(type, listener)` | Removes a listener. |
| `game.listenerCount(type)` | The number of listeners of the type. |
| `game.emit(type, detail)` | Sends an event to the script listeners. The game does not receive it. Use it to connect mods. |
| `game.command(name, description, handler)` | Adds a console command. `handler(...words)` returns the text to show. A script cannot replace a game command. |
| `game.status(text)` | Shows a message on the status bar. |
| `game.version` | `{ game, godot, quickjs }`. |
| `game.events` | The event types and their descriptions. |

## city

The city functions throw an Error when no city is loaded.

| Member | Use |
| --- | --- |
| `city.loaded` | True when a city is open. |
| `city.info()` | `{ name, mayor, size, funds, population, foundingYear, difficulty, scenario, path, date, demand }`. |
| `city.name`, `city.mayor`, `city.size`, `city.population` | Single values. `size` is the number of tiles on each map edge. |
| `city.date` | `{ year, month, day, age }`. A month has 25 days. `age` counts days from the founding. |
| `city.demand` | `{ residential, commercial, industrial }`. |
| `city.funds` | Get or set the funds. |
| `city.addFunds(amount)` | Adds a positive or negative amount. Returns the new funds. |
| `city.tile(x, y)` | `{ x, y, altitude, waterAltitude, terrain, building, zone, underground, overlay, water, saltWater, powered, powerable, watered, piped, traffic }`, or `null` outside the map. |

A point argument can also be `{ x, y }` or `[x, y]`.

## sim

| Member | Use |
| --- | --- |
| `sim.speed` | Get or set the speed: `'Paused'`, `'Turtle'`, `'Llama'`, `'Cheetah'`, `'African Swallow'`, or 1 to 5. |
| `sim.paused`, `sim.pause()`, `sim.resume()` | `resume` selects the speed before the pause. |
| `sim.step()` | Runs one day while the game is paused, as Debug > Advance One Day does. |
| `sim.disaster` | The active disaster `{ id, name }`, or `null`. |
| `sim.disasters` | The disaster names and IDs. |
| `sim.startDisaster(disaster, x, y)` | Starts a disaster by name or ID at a tile. Without a tile it starts at the view center. |

## tools

| Member | Use |
| --- | --- |
| `tools.list()` | Every tool: `{ group, subtool, groupName, name, cost, available }`. |
| `tools.selected` | The selected tool. |
| `tools.select(group, tool)` | Selects a tool by group and tool name or index, for example `tools.select('Roads', 'Road')`. With one name, the name of a tool or a group. The rules of the toolbar apply. |
| `tools.apply(from, to)` | Uses the selected tool as a drag from one tile to another. Returns the `tool.applied` detail. The tool rules, costs and prompts apply. |
| `tools.undo()` | Undoes the last edit, as Undo does. |

## view

| Member | Use |
| --- | --- |
| `view.center`, `view.centerOn(x, y)` | The tile at the center of the view. |
| `view.mode`, `view.modes` | Get or set the view: `'city'`, `'underground'`, `'traffic'`, `'pollution'` and the other data views. |

## Events

A listener receives an event object. It has the `type` and the fields below.
For a cancelable event, `event.cancel()` stops the action of the game, and
`event.cancelled` tells if a listener cancelled it. The game sends an event only
while a script listens to its type.

| Type | Fields | When |
| --- | --- | --- |
| `city.opened` | `name`, `size`, `date` | A city opens. |
| `city.closed` | | The city closes after the game ends. |
| `city.saved` | `path` | The city was saved. |
| `sim.day` | `year`, `month`, `day`, `age` | A simulation day ended. |
| `sim.month` | `year`, `month` | A new month started. |
| `sim.year` | `year` | A new year started. |
| `sim.speed` | `speed` | The speed changed. |
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
| `frame` | `delta` | A frame started. `delta` is in seconds. Timers are better for most work. |

`tool` is `{ group, subtool, groupName, name, cost }`. `start` and `finish` are
`{ x, y }`.

## Add a game function

The game API has three parts:

1. `game/assets/scripting/api.js` defines the JavaScript objects. Each member
   calls `__runtime.host(name, ...arguments)`.
2. `ApplicationScriptingApi.handlers()` in `game/src/application/scripting_api.gd`
   maps each name to a GDScript function. A function receives the arguments as
   an Array and returns the result. A failed call returns `_fail(message)`; the
   script then gets an Error.
3. `ApplicationScripting.emit(type, detail, cancelable)` sends an event.
   `cancelled(type, detail)` sends a cancelable event and returns true when a
   listener cancelled it. Add each new event type to `ApplicationScripting.EVENTS`.

Values convert as follows. A JavaScript number is an `int` when it is a whole
number and a `float` in other cases. An object becomes a Dictionary and an array
becomes an Array. A function or a symbol becomes `null`. From Godot, a
`Vector2i` becomes `{ x, y }`, a `Rect2i` becomes `{ x, y, width, height }`, and
packed arrays become arrays.
