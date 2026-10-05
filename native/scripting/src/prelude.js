// The core of the OpenSC2K script runtime. The native engine runs this file
// once in each new runtime, before any other script. It defines console,
// the timers, the event bus and the console commands of scripts. It takes
// the native __host function and keeps it in __runtime.host.
(function (global) {
  'use strict';

  const host = global.__host;
  delete global.__host;

  // ---------------------------------------------------------------- inspect

  const MAX_DEPTH = 2;
  const MAX_ITEMS = 100;
  const MAX_LINE = 72;
  const IDENTIFIER = /^[A-Za-z_$][\w$]*$/;

  function inspect(value, options) {
    const depth = options && typeof options.depth === 'number' ? options.depth : MAX_DEPTH;

    return format(value, depth, [], 0);
  }

  function format(value, depth, seen, indent) {
    switch (typeof value) {
      case 'string':
        return quote(value);
      case 'number':
        return Object.is(value, -0) ? '-0' : String(value);
      case 'bigint':
        return `${value}n`;
      case 'undefined':
      case 'boolean':
      case 'symbol':
        return String(value);
      case 'function':
        return formatFunction(value);
    }

    if (value === null) {
      return 'null';
    }

    if (seen.includes(value)) {
      return '[Circular]';
    }

    if (value instanceof Error) {
      return formatError(value);
    }

    if (value instanceof Date) {
      return isNaN(value) ? 'Invalid Date' : value.toISOString();
    }

    if (value instanceof RegExp) {
      return String(value);
    }

    if (value instanceof Promise) {
      return 'Promise {}';
    }

    const nested = seen.concat([value]);

    if (Array.isArray(value) || ArrayBuffer.isView(value)) {
      if (depth < 0) {
        return '[Array]';
      }

      const items = [];
      const count = Math.min(value.length, MAX_ITEMS);

      for (let index = 0; index < count; index++) {
        items.push(format(value[index], depth - 1, nested, indent + 2));
      }

      if (value.length > MAX_ITEMS) {
        items.push(`... ${value.length - MAX_ITEMS} more items`);
      }

      const prefix = Array.isArray(value) ? '' : `${value.constructor.name}(${value.length}) `;

      return prefix + wrap('[', items, ']', indent);
    }

    if (value instanceof Map) {
      if (depth < 0) {
        return '[Map]';
      }

      const items = [];

      for (const [key, item] of value) {
        items.push(`${format(key, depth - 1, nested, indent + 2)} => ${format(item, depth - 1, nested, indent + 2)}`);
      }

      return `Map(${value.size}) ` + wrap('{', items, '}', indent);
    }

    if (value instanceof Set) {
      if (depth < 0) {
        return '[Set]';
      }

      const items = [];

      for (const item of value) {
        items.push(format(item, depth - 1, nested, indent + 2));
      }

      return `Set(${value.size}) ` + wrap('{', items, '}', indent);
    }

    const name = constructorName(value);

    if (depth < 0) {
      return `[${name || 'Object'}]`;
    }

    const items = [];

    for (const key of Object.keys(value)) {
      const label = IDENTIFIER.test(key) ? key : quote(key);
      let text;

      try {
        text = format(value[key], depth - 1, nested, indent + 2);
      } catch (error) {
        text = `[Getter error: ${error && error.message}]`;
      }

      items.push(`${label}: ${text}`);
    }

    const prefix = name && name !== 'Object' ? `${name} ` : '';

    return prefix + wrap('{', items, '}', indent);
  }

  function constructorName(value) {
    const prototype = Object.getPrototypeOf(value);

    if (prototype === null) {
      return '[Object: null prototype]';
    }

    return prototype.constructor && prototype.constructor.name;
  }

  function formatFunction(value) {
    const source = Function.prototype.toString.call(value);

    if (source.startsWith('class')) {
      return `[class ${value.name || '(anonymous)'}]`;
    }

    return value.name ? `[Function: ${value.name}]` : '[Function (anonymous)]';
  }

  function wrap(open, items, close, indent) {
    if (items.length === 0) {
      return open + close;
    }

    const line = `${open} ${items.join(', ')} ${close}`;

    if (line.length + indent <= MAX_LINE && !line.includes('\n')) {
      return line;
    }

    const space = ' '.repeat(indent + 2);

    return `${open}\n${space}${items.join(`,\n${space}`)}\n${' '.repeat(indent)}${close}`;
  }

  function quote(text) {
    return JSON.stringify(text);
  }

  // an error with its stack, as the console shows it
  function formatError(error) {
    if (!(error instanceof Error)) {
      return typeof error === 'string' ? error : format(error, MAX_DEPTH, [], 0);
    }

    const title = `${error.name || 'Error'}: ${error.message}`;
    const stack = typeof error.stack === 'string' ? error.stack.trimEnd() : '';

    return stack ? `${title}\n${stack}` : title;
  }

  // ---------------------------------------------------------------- console

  function text(values) {
    return values.map((value) => (typeof value === 'string' ? value : inspect(value))).join(' ');
  }

  // the inspector sets these hooks: console(type, values) and exception(error, prefix)
  const taps = { console: null, exception: null };

  // a console method returns undefined, as in a browser
  function write(level, line) {
    host('console', level, line);
  }

  // writes the values to the game console, and gives them to the inspector
  function log(level, type, values) {
    write(level, text(values));

    if (taps.console) {
      taps.console(type, values);
    }
  }

  // reports an uncaught error in the game console and in the inspector
  function reportUncaught(error, prefix) {
    write('error', `${prefix} ${formatError(error)}`);

    if (taps.exception) {
      taps.exception(error, prefix);
    }
  }

  const counts = new Map();
  const timings = new Map();

  const console = {
    log: (...values) => log('log', 'log', values),
    info: (...values) => log('info', 'info', values),
    debug: (...values) => log('debug', 'debug', values),
    warn: (...values) => log('warn', 'warning', values),
    error: (...values) => log('error', 'error', values),
    trace: (...values) => log('log', 'trace', [`${text(values)}\n${new Error().stack.split('\n').slice(1).join('\n')}`]),
    dir: (value, options) => {
      write('log', inspect(value, options));

      if (taps.console) {
        taps.console('dir', [value]);
      }
    },
    assert(condition, ...values) {
      if (!condition) {
        log('error', 'assert', [`Assertion failed${values.length ? ': ' + text(values) : ''}`]);
      }
    },
    count(label = 'default') {
      counts.set(label, (counts.get(label) || 0) + 1);
      log('log', 'count', [`${label}: ${counts.get(label)}`]);
    },
    countReset(label = 'default') {
      counts.delete(label);
    },
    time(label = 'default') {
      timings.set(label, Date.now());
    },
    timeEnd(label = 'default') {
      if (timings.has(label)) {
        log('log', 'timeEnd', [`${label}: ${Date.now() - timings.get(label)} ms`]);
        timings.delete(label);
      }
    },
  };

  // ---------------------------------------------------------------- events

  // event type -> [{ listener, once }]. '*' listens to every event
  const listeners = new Map();

  class GameEvent {
    constructor(type, detail, cancelable) {
      if (detail && typeof detail === 'object') {
        Object.assign(this, detail);
      }

      this.type = type;
      this.cancelable = Boolean(cancelable);
      this.cancelled = false;
    }

    // stops the action of a cancelable event, such as tool.beforeApply
    cancel() {
      if (this.cancelable) {
        this.cancelled = true;
      }
    }
  }

  function checkListener(type, listener) {
    if (typeof type !== 'string' || type.length === 0) {
      throw new TypeError('The event type must be a string');
    }

    if (typeof listener !== 'function') {
      throw new TypeError('The listener must be a function');
    }
  }

  function on(type, listener, options) {
    checkListener(type, listener);
    const list = listeners.get(type) || [];
    list.push({ listener, once: Boolean(options && options.once) });
    listeners.set(type, list);
    host('listeners', type, list.length);

    return () => off(type, listener);
  }

  function once(type, listener) {
    return on(type, listener, { once: true });
  }

  function off(type, listener) {
    const list = listeners.get(type);

    if (!list) {
      return false;
    }

    const index = list.findIndex((entry) => entry.listener === listener);

    if (index < 0) {
      return false;
    }

    list.splice(index, 1);

    if (list.length === 0) {
      listeners.delete(type);
    }

    host('listeners', type, list.length);

    return true;
  }

  function listenerCount(type) {
    const list = listeners.get(type);

    return list ? list.length : 0;
  }

  // calls the listeners of the type, then the '*' listeners. Returns the
  // event. A listener that an earlier listener removes is not called
  function dispatch(type, detail, cancelable) {
    const event = new GameEvent(type, detail, cancelable);
    const targets = [];

    for (const key of type === '*' ? ['*'] : [type, '*']) {
      for (const entry of listeners.get(key) || []) {
        targets.push([key, entry]);
      }
    }

    for (const [key, entry] of targets) {
      const list = listeners.get(key);

      if (!list || !list.includes(entry)) {
        continue;
      }

      if (entry.once) {
        off(key, entry.listener);
      }

      try {
        entry.listener(event);
      } catch (error) {
        reportUncaught(error, `Uncaught error in a "${type}" listener:`);
      }
    }

    return event;
  }

  // ---------------------------------------------------------------- timers

  // id -> { callback, values, due, interval }
  const timers = new Map();
  let nextTimer = 1;

  function addTimer(callback, delay, values, repeat) {
    if (typeof callback !== 'function') {
      throw new TypeError('The timer callback must be a function');
    }

    const wait = Math.max(0, Number(delay) || 0);
    const id = nextTimer++;
    timers.set(id, { callback, values, due: Date.now() + wait, interval: repeat ? Math.max(1, wait) : 0 });

    if (timers.size === 1) {
      host('timers', 1);
    }

    return id;
  }

  // the host learns when the first timer starts and when the last one ends
  function clearTimer(id) {
    if (timers.delete(id) && timers.size === 0) {
      host('timers', 0);
    }
  }

  // runs the timers that are due. The game calls this once each frame while timers wait
  function tick() {
    const now = Date.now();
    const due = [];

    for (const [id, timer] of timers) {
      if (timer.due <= now) {
        due.push([id, timer]);
      }
    }

    due.sort((first, second) => first[1].due - second[1].due || first[0] - second[0]);

    for (const [id, timer] of due) {
      // an earlier callback can clear this timer
      if (timers.get(id) !== timer) {
        continue;
      }

      if (timer.interval > 0) {
        timer.due = Math.max(now, timer.due + timer.interval);
      } else {
        clearTimer(id);
      }

      try {
        timer.callback(...timer.values);
      } catch (error) {
        reportUncaught(error, 'Uncaught error in a timer:');
      }
    }

    return timers.size;
  }

  // ---------------------------------------------------------------- commands

  // console command name -> function. The words after the name are the arguments
  const commands = new Map();

  function command(name, description, handler) {
    if (typeof name !== 'string' || !/^[\w.-]+$/.test(name)) {
      throw new TypeError('A command name is one word of letters, digits, ".", "_" and "-"');
    }

    if (typeof handler !== 'function') {
      throw new TypeError('The command handler must be a function');
    }

    commands.set(name.toLowerCase(), handler);
    host('command', name.toLowerCase(), String(description || ''));
  }

  function runCommand(name, words) {
    const handler = commands.get(name);

    if (!handler) {
      throw new Error(`No script command is named ${name}`);
    }

    const result = handler(...words);

    if (result instanceof Promise) {
      settle(result);

      return '';
    }

    return result === undefined ? '' : typeof result === 'string' ? result : inspect(result);
  }

  // prints the value of console input when its promise settles
  function settle(promise) {
    promise.then(
      (completion) => {
        const value = completion && typeof completion === 'object' && 'value' in completion ? completion.value : completion;

        if (value !== undefined) {
          host('console', 'result', inspect(value));
        }
      },
      (error) => reportUncaught(error, 'Uncaught'),
    );
  }

  // ---------------------------------------------------------------- globals

  const runtime = Object.freeze({
    host,
    inspect,
    formatError,
    dispatch,
    tick,
    runCommand,
    settle,
    reportUncaught,
    taps,
    events: Object.freeze({ on, once, off, listenerCount, emit: (type, detail) => dispatch(type, detail, false) }),
    command,
  });

  const hidden = { configurable: false, enumerable: false, writable: false };
  Object.defineProperty(global, '__runtime', { value: runtime, ...hidden });
  Object.defineProperty(global, 'console', { value: console, configurable: true, enumerable: false, writable: true });

  global.setTimeout = (callback, delay, ...values) => addTimer(callback, delay, values, false);
  global.setInterval = (callback, delay, ...values) => addTimer(callback, delay, values, true);
  global.clearTimeout = clearTimer;
  global.clearInterval = clearTimer;
  global.inspect = inspect;
})(globalThis);
