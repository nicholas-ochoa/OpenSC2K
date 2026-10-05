// The OpenSC2K game API of scripts. The game runs this file after the core
// of the runtime (native/core/scripting/src/prelude.js). Each function calls a
// GDScript host function of ApplicationScriptingApi. See docs/scripting.md.
(function (global) {
  'use strict';

  const { host, events, command } = global.__runtime;

  // the file functions of a mod; only the runtime of a mod has them
  const nativeFiles = global.__files;
  delete global.__files;

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

    // the info of each mod that runs: [{ id, name, version, ... }]
    get mods() {
      return host('game.mods');
    },

    on: events.on,
    once: events.once,
    off: events.off,
    listenerCount: events.listenerCount,

    // sends an event to the script listeners of the console and of each mod,
    // with a copy of the detail. The game does not see it
    emit: events.emit,

    // adds a console command: command(name, description, (...words) => text)
    command,

    // shows a message on the status bar
    status(text) {
      host('game.status', String(text));
    },

    // values that stay after the game closes. Each value must be JSON data.
    // Each mod has its own values, in storage.json in its folder
    storage: Object.freeze({
      get: (key, fallback) => host('storage.get', String(key), fallback === undefined ? null : fallback),
      set: (key, value) => host('storage.set', String(key), value),
      remove: (key) => host('storage.remove', String(key)),
      keys: () => host('storage.keys'),
    }),
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

    // the value of a data map at a tile, such as city.data('pollution', 10, 20)
    data(name, x, y) {
      return host('city.data', name, point(x, y));
    },

    // a whole data map: { name, size, scale, values, at(x, y) }
    dataMap(name) {
      const map = host('city.dataMap', name);

      map.at = (x, y) => {
        const tile = point(x, y);

        return map.values[Math.floor(tile.x / map.scale) * map.size + Math.floor(tile.y / map.scale)];
      };

      return map;
    },

    get dataMaps() {
      return host('city.dataMaps');
    },

    // a graph history, oldest value first: graph('Residents', 'decade')
    graph(name, period = 'year') {
      return host('city.graph', name, period);
    },

    get graphs() {
      return host('city.graphs');
    },

    rename(name) {
      return host('city.rename', String(name));
    },

    // the text of the sign on a tile, or null
    sign(x, y) {
      return host('city.sign', point(x, y));
    },

    // places or changes a sign; an empty text removes it
    setSign(x, y, text) {
      return host('city.setSign', point(x, y), String(text));
    },

    // the moving objects: { id, type, name, x, y, state }
    things() {
      return host('city.things');
    },

    // saves the city to its file
    save() {
      return host('city.save');
    },
  });

  const budget = Object.freeze({
    // { taxes, funding, autoBudget, bonds }
    info() {
      return host('budget.info');
    },

    get taxes() {
      return host('budget.info').taxes;
    },

    get funding() {
      return host('budget.info').funding;
    },

    // set({ taxes: { residential: 8 }, funding: { police: 90 }, autoBudget: true })
    set(changes) {
      return host('budget.set', changes);
    },

    // every ordinance: { key, name, category, enabled, cost }
    ordinances() {
      return host('budget.ordinances');
    },

    setOrdinance(key, enabled = true) {
      return host('budget.setOrdinance', String(key), Boolean(enabled));
    },

    issueBond() {
      return host('budget.issueBond');
    },

    repayBond() {
      return host('budget.repayBond');
    },
  });

  const ui = Object.freeze({
    // a message window with an OK button
    alert(text, title = 'Script') {
      host('ui.alert', String(text), String(title));
    },

    status(text) {
      host('game.status', String(text));
    },

    // plays SOUNDS/<id>.WAV of the sound pack
    playSound(id) {
      host('ui.playSound', id);
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

    // ends the active disaster and clears its marks. False without a disaster
    endDisaster() {
      return host('sim.endDisaster');
    },

    // true when random disasters are off
    get noDisasters() {
      return host('sim.noDisasters');
    },

    set noDisasters(value) {
      host('sim.setNoDisasters', Boolean(value));
    },

    // runs at the speed until the date, then pauses: runUntil({ year: 2051, month: 1, day: 1 })
    runUntil(date, speed = 'Cheetah') {
      const speeds = { Turtle: 2, Llama: 3, Cheetah: 4, 'African Swallow': 5 };

      return host('sim.runUntil', date, typeof speed === 'number' ? speed : speeds[speed] || 4);
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

    // the zoom in percent
    get zoom() {
      return host('view.zoom');
    },

    zoomIn() {
      return host('view.zoomIn');
    },

    zoomOut() {
      return host('view.zoomOut');
    },

    // the compass rotation of the map, 0 to 3
    get rotation() {
      return host('view.rotation');
    },

    // a quarter turn, clockwise unless the argument is false
    rotate(clockwise = true) {
      return host('view.rotate', Boolean(clockwise));
    },
  });

  // the bytes of a Uint8Array, another typed array, a DataView, an ArrayBuffer or an array of numbers
  function bytes(data) {
    if (data instanceof Uint8Array) {
      return data;
    }

    if (data instanceof ArrayBuffer) {
      return new Uint8Array(data);
    }

    if (ArrayBuffer.isView(data)) {
      return new Uint8Array(data.buffer, data.byteOffset, data.byteLength);
    }

    if (Array.isArray(data)) {
      return Uint8Array.from(data);
    }

    throw new TypeError('The data must be a Uint8Array, an ArrayBuffer, a typed array or an array of bytes');
  }

  // the files of the mod folder. Each path is relative to the folder; a path
  // outside it throws an Error
  function modFiles(native) {
    return Object.freeze({
      readText: (path) => native.readText(String(path)),
      readBytes: (path) => native.readBytes(String(path)),
      readJSON: (path) => JSON.parse(native.readText(String(path))),
      writeText: (path, text) => native.write(String(path), String(text), false),
      appendText: (path, text) => native.write(String(path), String(text), true),
      writeBytes: (path, data) => native.write(String(path), bytes(data), false),
      writeJSON: (path, value, space = 2) => native.write(String(path), JSON.stringify(value, null, space), false),
      exists: (path) => native.exists(String(path)),
      stat: (path) => native.stat(String(path)),
      list: (path = '.') => native.list(String(path)),
      makeFolder: (path) => native.makeFolder(String(path)),
      remove: (path, options) => native.remove(String(path), Boolean(options && options.recursive)),
      rename: (from, to) => native.rename(String(from), String(to)),
    });
  }

  const globals = { game, city, budget, sim, tools, view, ui };
  const info = nativeFiles ? host('mod.info') : null;

  if (info) {
    globals.mod = Object.freeze({
      id: info.id,
      name: info.name,
      version: info.version,
      // all fields of info.json
      info: Object.freeze(info),
      files: modFiles(nativeFiles),
    });
  }

  const fixed = { configurable: true, enumerable: true, writable: false };

  for (const [name, value] of Object.entries(globals)) {
    Object.defineProperty(global, name, { value, ...fixed });
  }
})(globalThis);
