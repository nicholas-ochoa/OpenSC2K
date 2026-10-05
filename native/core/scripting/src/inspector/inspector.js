// The Chrome DevTools Protocol handler of the script inspector. The native
// engine runs this file after prelude.js. The server threads give each
// message to __inspector.handle on the main thread, and native.send writes
// the answers and events. This is level 1 of a debugger: the Console, object
// inspection and the Sources panel. QuickJS-ng has no API for breakpoints or
// stepping, thus the Debugger methods for them answer with an error.
(function (global) {
  'use strict';

  const native = global.__inspectorNative;
  delete global.__inspectorNative;
  const runtime = global.__runtime;

  const CONTEXT_ID = 1;
  const TARGET_ID = 'opensc2k';
  const INTERNAL_PREFIX = 'opensc2k:';
  // older remote objects go when the table holds more
  const MAX_OBJECTS = 20000;
  const PREVIEW_PROPERTIES = 5;
  const PREVIEW_ITEMS = 20;
  const STACK_FRAME = /^\s*at (.*?) \((.*):(\d+):(\d+)\)$/;
  // eager evaluation and completion may only read names and properties
  const SAFE_EXPRESSION = /^[A-Za-z_$][\w$]*(\s*\.\s*[A-Za-z_$][\w$]*|\[\s*(\d+|'[^'\\]*'|"[^"\\]*")\s*\])*$/;
  const NOT_SUPPORTED = 'Breakpoints, pausing and stepping need a full debugger, which the OpenSC2K script runtime does not have yet';

  let attached = false;
  let runtimeEnabled = false;
  let debuggerEnabled = false;
  // the number of scripts that the native list gave
  let knownScripts = 0;
  let nextObject = 1;
  let nextException = 1;
  // the id of the message that runs now, for fail()
  let currentId = null;
  // objectId -> { value, group }
  const objects = new Map();
  // scriptId -> source, and script file name -> scriptId
  const sources = new Map();
  const scriptIds = new Map();
  const scripts = [];

  // ------------------------------------------------------------- messages

  function send(message) {
    native.send(JSON.stringify(message));
  }

  function notify(method, params) {
    send({ method, params });
  }

  function failure(error) {
    return { code: -32000, message: String((error && error.message) || error) };
  }

  function handle(text) {
    let message;

    try {
      message = JSON.parse(text);
    } catch {
      return;
    }

    const { id, method, params = {} } = message;
    const handler = Object.hasOwn(handlers, method) ? handlers[method] : null;

    if (!handler) {
      send({ id, error: { code: -32601, message: `'${method}' wasn't found` } });

      return;
    }

    currentId = id;
    let result;

    try {
      result = handler(params);
    } catch (error) {
      send({ id, error: failure(error) });

      return;
    } finally {
      currentId = null;
    }

    if (result instanceof Promise) {
      result.then(
        (value) => send({ id, result: value || {} }),
        (error) => send({ id, error: failure(error) }),
      );
    } else {
      send({ id, result: result || {} });
    }
  }

  // the engine calls this when a message stopped with an uncatchable error,
  // such as the time limit
  function fail(text) {
    if (currentId !== null) {
      send({ id: currentId, error: failure(text) });
      currentId = null;
    }
  }

  function attach() {
    attached = true;
    runtimeEnabled = false;
    debuggerEnabled = false;
    objects.clear();
    runtime.taps.console = onConsole;
    runtime.taps.exception = onException;
  }

  function detach() {
    attached = false;
    runtimeEnabled = false;
    debuggerEnabled = false;
    objects.clear();
    runtime.taps.console = null;
    runtime.taps.exception = null;
  }

  // ------------------------------------------------------------- scripts

  // reads the new scripts of the engine, and announces them to the Sources panel
  function sync() {
    for (const script of native.scripts(knownScripts)) {
      knownScripts += 1;
      scripts.push(script);
      sources.set(script.id, script.source);
      scriptIds.set(script.name, script.id);

      if (debuggerEnabled) {
        notify('Debugger.scriptParsed', scriptParsed(script));
      }
    }
  }

  function scriptParsed(script) {
    const lines = script.source.split('\n');

    return {
      scriptId: script.id,
      url: fileUrl(script.name),
      startLine: 0,
      startColumn: 0,
      endLine: lines.length - 1,
      endColumn: lines[lines.length - 1].length,
      executionContextId: CONTEXT_ID,
      hash: hash(script.source),
      isModule: script.module,
      length: script.source.length,
      scriptLanguage: 'JavaScript',
    };
  }

  // an absolute file path as a file URL. Other names stay as they are
  function fileUrl(name) {
    if (name.startsWith('/')) {
      return `file://${name}`;
    }

    if (/^[A-Za-z]:[\\/]/.test(name)) {
      return `file:///${name.replace(/\\/g, '/')}`;
    }

    return name;
  }

  // a 32-bit FNV-1a hash in hex. DevTools only compares hashes
  function hash(text) {
    let value = 0x811c9dc5;

    for (let index = 0; index < text.length; index++) {
      value = Math.imul(value ^ text.charCodeAt(index), 0x01000193) >>> 0;
    }

    return value.toString(16).padStart(8, '0').repeat(5);
  }

  // the error text without the frames of the runtime core and the inspector,
  // and without the native frames that only lead to them
  function withoutInternalFrames(text) {
    const lines = text.split('\n').filter((line) => !(STACK_FRAME.test(line) && STACK_FRAME.exec(line)[2].startsWith(INTERNAL_PREFIX)));

    while (lines.length > 1 && /^\s*at .* \(native\)$/.test(lines[lines.length - 1])) {
      lines.pop();
    }

    return lines.join('\n');
  }

  // the frames of a QuickJS stack, without the frames of the runtime core
  function stackTrace(stack) {
    const callFrames = [];

    for (const line of String(stack || '').split('\n')) {
      const match = STACK_FRAME.exec(line);

      if (!match || match[2].startsWith(INTERNAL_PREFIX)) {
        continue;
      }

      const name = match[1];
      callFrames.push({
        functionName: name === '<anonymous>' || name === '<eval>' ? '' : name,
        scriptId: scriptIds.get(match[2]) || '0',
        url: fileUrl(match[2]),
        lineNumber: Number(match[3]) - 1,
        columnNumber: Number(match[4]) - 1,
      });
    }

    return { callFrames };
  }

  // ------------------------------------------------------------- remote objects

  function register(value, group) {
    const id = String(nextObject++);
    objects.set(id, { value, group });

    if (objects.size > MAX_OBJECTS) {
      objects.delete(objects.keys().next().value);
    }

    return id;
  }

  function lookup(objectId) {
    const entry = objects.get(objectId);

    if (!entry) {
      throw new Error('Could not find object with given id');
    }

    return entry;
  }

  function subtypeOf(value) {
    if (Array.isArray(value)) {
      return 'array';
    }

    if (value instanceof Error) {
      return 'error';
    }

    const checks = [
      [Date, 'date'], [RegExp, 'regexp'], [Map, 'map'], [Set, 'set'], [WeakMap, 'weakmap'], [WeakSet, 'weakset'],
      [Promise, 'promise'], [ArrayBuffer, 'arraybuffer'], [DataView, 'dataview'],
    ];

    for (const [type, name] of checks) {
      if (value instanceof type) {
        return name;
      }
    }

    return ArrayBuffer.isView(value) ? 'typedarray' : undefined;
  }

  function className(value) {
    try {
      const prototype = Object.getPrototypeOf(value);

      return (prototype && prototype.constructor && prototype.constructor.name) || 'Object';
    } catch {
      return 'Object';
    }
  }

  function describe(value) {
    switch (subtypeOf(value)) {
      case 'array':
        return `Array(${value.length})`;
      case 'typedarray':
        return `${className(value)}(${value.length})`;
      case 'error':
        return withoutInternalFrames(runtime.formatError(value));
      case 'date':
        return value.toString();
      case 'regexp':
        return String(value);
      case 'map':
        return `Map(${value.size})`;
      case 'set':
        return `Set(${value.size})`;
      case 'promise':
        return 'Promise';
      default:
        return className(value);
    }
  }

  function describeFunction(value) {
    try {
      return Function.prototype.toString.call(value);
    } catch {
      return 'function';
    }
  }

  function number(value) {
    if (Object.is(value, -0) || !Number.isFinite(value)) {
      const text = Object.is(value, -0) ? '-0' : String(value);

      return { type: 'number', unserializableValue: text, description: text };
    }

    return { type: 'number', value, description: String(value) };
  }

  // a RemoteObject of the protocol. Objects get an id in the table
  function remote(value, group, withPreview) {
    switch (typeof value) {
      case 'undefined':
        return { type: 'undefined' };
      case 'boolean':
        return { type: 'boolean', value };
      case 'string':
        return { type: 'string', value };
      case 'number':
        return number(value);
      case 'bigint':
        return { type: 'bigint', unserializableValue: `${value}n`, description: `${value}n` };
      case 'symbol':
        return { type: 'symbol', description: String(value), objectId: register(value, group) };
      case 'function':
        return { type: 'function', className: 'Function', description: describeFunction(value), objectId: register(value, group) };
    }

    if (value === null) {
      return { type: 'object', subtype: 'null', value: null };
    }

    const result = { type: 'object', className: className(value), description: describe(value), objectId: register(value, group) };
    const subtype = subtypeOf(value);

    if (subtype) {
      result.subtype = subtype;
    }

    if (withPreview) {
      result.preview = preview(value);
    }

    return result;
  }

  // a value for returnByValue: a JSON copy
  function byValue(value) {
    if (value === undefined) {
      return { type: 'undefined' };
    }

    try {
      return { type: typeof value, value: JSON.parse(JSON.stringify(value)) };
    } catch {
      return { type: typeof value, description: String(value) };
    }
  }

  // an ObjectPreview without property values of its own
  function shallowPreview(value) {
    if (value === null || (typeof value !== 'object' && typeof value !== 'function')) {
      const kind = value === null ? 'object' : typeof value;
      const preview = { type: kind, description: typeof value === 'string' ? value : String(value), overflow: false, properties: [] };

      if (value === null) {
        preview.subtype = 'null';
      }

      return preview;
    }

    const preview = { type: typeof value, description: typeof value === 'function' ? 'Function' : describe(value), overflow: true, properties: [] };
    const subtype = typeof value === 'object' ? subtypeOf(value) : undefined;

    if (subtype) {
      preview.subtype = subtype;
    }

    return preview;
  }

  function propertyPreview(name, descriptor) {
    if (!('value' in descriptor)) {
      return { name, type: 'accessor' };
    }

    const value = descriptor.value;

    if (value === null) {
      return { name, type: 'object', subtype: 'null', value: 'null' };
    }

    if (typeof value === 'object') {
      const result = { name, type: 'object', value: describe(value) };
      const subtype = subtypeOf(value);

      if (subtype) {
        result.subtype = subtype;
      }

      return result;
    }

    if (typeof value === 'function') {
      return { name, type: 'function', value: '' };
    }

    return { name, type: typeof value, value: typeof value === 'bigint' ? `${value}n` : String(value) };
  }

  // the ObjectPreview that the console shows inline. Getters do not run
  function preview(value) {
    const result = shallowPreview(value);
    result.overflow = false;
    const subtype = result.subtype;

    if (subtype === 'map' || subtype === 'set') {
      result.entries = [];

      for (const entry of value) {
        if (result.entries.length >= PREVIEW_PROPERTIES) {
          result.overflow = true;
          break;
        }

        result.entries.push(subtype === 'map' ? { key: shallowPreview(entry[0]), value: shallowPreview(entry[1]) } : { value: shallowPreview(entry) });
      }

      return result;
    }

    const limit = subtype === 'array' || subtype === 'typedarray' ? PREVIEW_ITEMS : PREVIEW_PROPERTIES;

    for (const key of Object.keys(value)) {
      if (result.properties.length >= limit) {
        result.overflow = true;
        break;
      }

      const descriptor = Object.getOwnPropertyDescriptor(value, key);

      if (descriptor) {
        result.properties.push(propertyPreview(key, descriptor));
      }
    }

    return result;
  }

  // ------------------------------------------------------------- console and errors

  function onConsole(type, values) {
    if (!runtimeEnabled) {
      return;
    }

    sync();
    notify('Runtime.consoleAPICalled', {
      type,
      args: values.map((value) => remote(value, 'console', true)),
      executionContextId: CONTEXT_ID,
      timestamp: Date.now(),
      stackTrace: stackTrace(new Error().stack),
    });
  }

  function exceptionDetails(error, text) {
    const trace = stackTrace(error && error.stack);
    const top = trace.callFrames[0];
    const details = {
      exceptionId: nextException++,
      text,
      lineNumber: top ? top.lineNumber : 0,
      columnNumber: top ? top.columnNumber : 0,
      exception: remote(error, 'console', true),
      executionContextId: CONTEXT_ID,
    };

    if (top) {
      details.scriptId = top.scriptId;
      details.url = top.url;
      details.stackTrace = trace;
    }

    return details;
  }

  function onException(error, prefix) {
    if (!runtimeEnabled) {
      return;
    }

    sync();
    notify('Runtime.exceptionThrown', { timestamp: Date.now(), exceptionDetails: exceptionDetails(error, prefix) });
  }

  // a line of the game console: level is log, warning or error
  function gameLog(level, text) {
    if (!runtimeEnabled) {
      return;
    }

    const type = level === 'warning' || level === 'error' ? level : 'log';
    notify('Runtime.consoleAPICalled', { type, args: [{ type: 'string', value: text }], executionContextId: CONTEXT_ID, timestamp: Date.now() });
  }

  // ------------------------------------------------------------- Runtime

  function thrown(error, group) {
    return { result: remote(error, group, true), exceptionDetails: exceptionDetails(error, 'Uncaught') };
  }

  function evaluate(params) {
    const { expression = '', objectGroup = 'console', returnByValue, generatePreview, throwOnSideEffect } = params;
    const result = (value) => ({ result: returnByValue ? byValue(value) : remote(value, objectGroup, generatePreview) });

    // eager evaluation runs while the player types; it must not change the game
    if (throwOnSideEffect) {
      if (!SAFE_EXPRESSION.test(expression.trim())) {
        return thrown(new EvalError('Possible side-effect in debug-evaluate'), objectGroup);
      }

      try {
        return result((0, eval)(expression));
      } catch (error) {
        return thrown(error, objectGroup);
      }
    }

    let promise;

    try {
      promise = native.evaluate(expression);
    } catch (error) {
      return thrown(error, objectGroup);
    }

    return promise.then(
      (completion) => result(completion && completion.value),
      (error) => thrown(error, objectGroup),
    );
  }

  function argumentValue(argument) {
    if ('objectId' in argument) {
      return lookup(argument.objectId).value;
    }

    if ('unserializableValue' in argument) {
      const text = argument.unserializableValue;

      return text.endsWith('n') ? BigInt(text.slice(0, -1)) : Number(text);
    }

    return argument.value;
  }

  function callFunctionOn(params) {
    const { functionDeclaration, objectId, returnByValue, generatePreview, awaitPromise } = params;
    const group = params.objectGroup || (objectId && objects.has(objectId) ? objects.get(objectId).group : 'console');
    const result = (value) => ({ result: returnByValue ? byValue(value) : remote(value, group, generatePreview) });
    let value;

    try {
      const target = objectId ? lookup(objectId).value : global;
      const values = (params.arguments || []).map(argumentValue);
      value = (0, eval)(`(${functionDeclaration})`).apply(target, values);
    } catch (error) {
      return thrown(error, group);
    }

    if (awaitPromise && value instanceof Promise) {
      return value.then(result, (error) => thrown(error, group));
    }

    return result(value);
  }

  function getProperties(params) {
    const { objectId, accessorPropertiesOnly, generatePreview } = params;
    const entry = lookup(objectId);
    const value = entry.value;
    const result = [];
    const internalProperties = [];

    if (accessorPropertiesOnly || (typeof value !== 'object' && typeof value !== 'function')) {
      return { result };
    }

    for (const key of Reflect.ownKeys(value)) {
      const descriptor = Object.getOwnPropertyDescriptor(value, key);

      if (!descriptor) {
        continue;
      }

      const property = { name: String(key), configurable: descriptor.configurable, enumerable: descriptor.enumerable, isOwn: true };

      if (typeof key === 'symbol') {
        property.symbol = remote(key, entry.group);
      }

      if ('value' in descriptor) {
        property.value = remote(descriptor.value, entry.group, generatePreview);
        property.writable = descriptor.writable;
      } else {
        if (descriptor.get) {
          property.get = remote(descriptor.get, entry.group);
        }

        if (descriptor.set) {
          property.set = remote(descriptor.set, entry.group);
        }
      }

      result.push(property);
    }

    if (value instanceof Map || value instanceof Set) {
      const entries = value instanceof Map ? [...value].map(([key, item]) => ({ key, value: item })) : [...value];
      internalProperties.push({ name: '[[Entries]]', value: remote(entries, entry.group, false) });
    }

    const prototype = Object.getPrototypeOf(value);

    if (prototype !== null) {
      internalProperties.push({ name: '[[Prototype]]', value: remote(prototype, entry.group, false) });
    }

    return { result, internalProperties };
  }

  function releaseObjectGroup({ objectGroup }) {
    for (const [id, entry] of objects) {
      if (entry.group === objectGroup) {
        objects.delete(id);
      }
    }
  }

  function compileScript({ expression = '' }) {
    try {
      native.check(expression);

      return {};
    } catch (error) {
      return { exceptionDetails: exceptionDetails(error, 'Uncaught') };
    }
  }

  function enableRuntime() {
    runtimeEnabled = true;
    notify('Runtime.executionContextCreated', {
      context: { id: CONTEXT_ID, origin: '', name: 'OpenSC2K', uniqueId: TARGET_ID, auxData: { isDefault: true } },
    });
  }

  function enableDebugger() {
    sync();
    debuggerEnabled = true;

    for (const script of scripts) {
      notify('Debugger.scriptParsed', scriptParsed(script));
    }

    return { debuggerId: TARGET_ID };
  }

  // ------------------------------------------------------------- method table

  const done = () => ({});
  const notSupported = () => {
    throw new Error(NOT_SUPPORTED);
  };

  const handlers = {
    'Runtime.enable': enableRuntime,
    'Runtime.disable': () => {
      runtimeEnabled = false;
    },
    'Runtime.evaluate': evaluate,
    'Runtime.callFunctionOn': callFunctionOn,
    'Runtime.getProperties': getProperties,
    'Runtime.compileScript': compileScript,
    'Runtime.awaitPromise': ({ promiseObjectId, returnByValue, generatePreview }) => {
      const entry = lookup(promiseObjectId);

      return Promise.resolve(entry.value).then(
        (value) => ({ result: returnByValue ? byValue(value) : remote(value, entry.group, generatePreview) }),
        (error) => thrown(error, entry.group),
      );
    },
    'Runtime.releaseObject': ({ objectId }) => {
      objects.delete(objectId);
    },
    'Runtime.releaseObjectGroup': releaseObjectGroup,
    'Runtime.getHeapUsage': () => {
      const memory = native.memory();

      return { usedSize: memory.used, totalSize: memory.total };
    },
    'Runtime.getIsolateId': () => ({ id: TARGET_ID }),
    'Runtime.globalLexicalScopeNames': () => ({ names: [] }),
    'Runtime.runIfWaitingForDebugger': done,
    'Runtime.discardConsoleEntries': done,
    'Runtime.setAsyncCallStackDepth': done,
    'Runtime.setMaxCallStackSizeToCapture': done,
    'Runtime.addBinding': done,
    'Debugger.enable': enableDebugger,
    'Debugger.disable': () => {
      debuggerEnabled = false;
    },
    'Debugger.getScriptSource': ({ scriptId }) => {
      if (!sources.has(scriptId)) {
        throw new Error('No script with given id');
      }

      return { scriptSource: sources.get(scriptId) };
    },
    'Debugger.getPossibleBreakpoints': () => ({ locations: [] }),
    'Debugger.setPauseOnExceptions': done,
    'Debugger.setAsyncCallStackDepth': done,
    'Debugger.setBlackboxPatterns': done,
    'Debugger.setBlackboxExecutionContexts': done,
    'Debugger.setBreakpointsActive': done,
    'Debugger.setSkipAllPauses': done,
    'Debugger.setBreakpointByUrl': notSupported,
    'Debugger.setBreakpoint': notSupported,
    'Debugger.pause': notSupported,
    'Debugger.resume': done,
    'Profiler.enable': done,
    'Profiler.disable': done,
    'Profiler.setSamplingInterval': done,
    'Profiler.start': notSupported,
    'HeapProfiler.enable': done,
    'HeapProfiler.disable': done,
    'HeapProfiler.collectGarbage': () => {
      native.collectGarbage();
    },
    'Log.enable': done,
    'Log.disable': done,
    'Log.startViolationsReport': done,
    'Inspector.enable': done,
    'Network.enable': done,
    'NodeRuntime.enable': done,
    'NodeWorker.enable': done,
    'Target.setAutoAttach': done,
    'Target.setDiscoverTargets': done,
    'Schema.getDomains': () => ({
      domains: ['Runtime', 'Debugger', 'Profiler', 'HeapProfiler', 'Log'].map((name) => ({ name, version: '1.3' })),
    }),
  };

  Object.defineProperty(global, '__inspector', {
    value: Object.freeze({ handle, attach, detach, sync, gameLog, fail, connected: () => attached }),
    configurable: false,
    enumerable: false,
    writable: false,
  });
})(globalThis);
