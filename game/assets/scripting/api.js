// The OpenSC2K game API of scripts. The game runs this file after the core
// of the runtime (native/scripting/src/prelude.js). Each function calls a
// GDScript host function of ApplicationScriptingApi. See docs/scripting.md.
(function (global) {
  'use strict';

  const { host, events, command } = global.__runtime;

  // a tile point from (x, y), ({ x, y }) or ([x, y])
  function point(x, y) {
    if (Array.isArray(x)) {
      return { x: x[0], y: x[1] };
    }

    if (x !== null && typeof x === 'object') {
      return { x: x.x, y: x.y };
    }

    return { x, y };
  }

  const game = Object.freeze({
    get version() {
      return host('game.version');
    },

    // the events of the game: { name: description }
    get events() {
      return host('game.events');
    },

    on: events.on,
    once: events.once,
    off: events.off,
    listenerCount: events.listenerCount,

    // sends an event to the script listeners only. The game does not see it
    emit: events.emit,

    // adds a console command: command(name, description, (...words) => text)
    command,

    // shows a message on the status bar
    status(text) {
      host('game.status', String(text));
    },
  });

  const city = Object.freeze({
    get loaded() {
      return host('city.loaded');
    },

    // a copy of the main city values
    info() {
      return host('city.info');
    },

    get name() {
      return host('city.info').name;
    },

    get mayor() {
      return host('city.info').mayor;
    },

    // the number of tiles on each map edge
    get size() {
      return host('city.info').size;
    },

    get population() {
      return host('city.info').population;
    },

    get date() {
      return host('city.info').date;
    },

    get demand() {
      return host('city.info').demand;
    },

    get funds() {
      return host('city.info').funds;
    },

    set funds(value) {
      host('city.setFunds', value);
    },

    addFunds(amount) {
      return host('city.addFunds', amount);
    },

    // the stored values of one tile, or null outside the map
    tile(x, y) {
      return host('city.tile', point(x, y));
    },
  });

  const sim = Object.freeze({
    // 'Paused', 'Turtle', 'Llama', 'Cheetah' or 'African Swallow'
    get speed() {
      return host('sim.speed');
    },

    set speed(value) {
      host('sim.setSpeed', value);
    },

    get paused() {
      return host('sim.speed') === 'Paused';
    },

    pause() {
      host('sim.setSpeed', 'Paused');
    },

    // selects the speed before the pause
    resume() {
      host('sim.resume');
    },

    // runs one day while the game is paused. Returns a report
    step() {
      return host('sim.step');
    },

    // the active disaster { id, name }, or null
    get disaster() {
      return host('sim.disaster');
    },

    // the disasters { name: id } that startDisaster takes
    get disasters() {
      return host('sim.disasters');
    },

    // starts a disaster by name or id, at a tile or at the view center
    startDisaster(disaster, x, y) {
      return host('sim.startDisaster', disaster, x === undefined ? null : point(x, y));
    },
  });

  const tools = Object.freeze({
    // every tool: { group, subtool, groupName, name, cost }
    list() {
      return host('tools.list');
    },

    get selected() {
      return host('tools.selected');
    },

    // select('Roads', 'Road'), select('Road'), or select(group, subtool)
    select(group, subtool) {
      return host('tools.select', group, subtool === undefined ? null : subtool);
    },

    // uses the selected tool from one tile to another, as a drag does
    apply(from, to) {
      const start = point(from);

      return host('tools.apply', start, to === undefined ? start : point(to));
    },

    undo() {
      return host('tools.undo');
    },
  });

  const view = Object.freeze({
    get center() {
      return host('view.center');
    },

    centerOn(x, y) {
      return host('view.centerOn', point(x, y));
    },

    // 'city', 'underground', 'traffic', 'pollution', ...
    get mode() {
      return host('view.mode');
    },

    set mode(value) {
      host('view.setMode', value);
    },

    get modes() {
      return host('view.modes');
    },
  });

  const fixed = { configurable: true, enumerable: true, writable: false };

  for (const [name, value] of Object.entries({ game, city, sim, tools, view })) {
    Object.defineProperty(global, name, { value, ...fixed });
  }
})(globalThis);
