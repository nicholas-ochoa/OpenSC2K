// TypeScript declarations of the OpenSC2K script API: the globals of the
// console runtime and of each mod. Copy this file into a mod folder for the
// completion and the checks of TypeScript and of editors such as VS Code.
// game/assets/scripting/api.js and native/scripting/src/prelude.js define the
// API; docs/scripting.md and docs/mods.md describe it. The API is new: names
// and fields can change.
//
// scripting_types_test checks that each member of api.js and each game event is here.

/** A tile position. The API also takes `[x, y]` or `(x, y)`. */
interface TilePoint {
  x: number;
  y: number;
}

type TileArgument = TilePoint | [number, number];

/** A date of the city. A month has 25 days. `age` counts the days from the founding. */
interface CityDate {
  year: number;
  month: number;
  day: number;
  age: number;
}

/** The demand of each zone kind, from -2000 to 2000. */
interface Demand {
  residential: number;
  commercial: number;
  industrial: number;
}

interface CityInfo {
  name: string;
  mayor: string;
  /** The number of tiles on each map edge. */
  size: number;
  funds: number;
  population: number;
  foundingYear: number;
  difficulty: number;
  scenario: boolean;
  /** The file of the city, or an empty text. */
  path: string;
  date: CityDate;
  demand: Demand;
}

type DataMapName = 'traffic' | 'pollution' | 'landValue' | 'crime' | 'police' | 'fire' | 'populationDensity' | 'growth';

/** The value of each data map at a tile. */
type TileData = Record<DataMapName, number>;

/** The stored values of a tile. */
interface Tile {
  x: number;
  y: number;
  altitude: number;
  waterAltitude: number;
  terrain: number;
  building: number;
  zone: number;
  underground: number;
  overlay: number;
  water: boolean;
  saltWater: boolean;
  powered: boolean;
  powerable: boolean;
  watered: boolean;
  piped: boolean;
  traffic: number;
  data: TileData;
}

interface DataMap {
  name: DataMapName;
  /** The number of values on each edge of the map. */
  size: number;
  /** The number of tiles on each edge of one value. */
  scale: number;
  /** The values, column by column: `values[x * size + y]`. */
  values: number[];
  /** The value at a tile. */
  at(x: number | TileArgument, y?: number): number;
}

type GraphName =
  | 'City Size' | 'Residents' | 'Commerce' | 'Industry' | 'Traffic' | 'Pollution' | 'Value' | 'Crime' | 'Power %'
  | 'Water %' | 'Health' | 'Education' | 'Unemployment' | 'GNP' | "Nat'n Pop." | 'Fed Rate';

type GraphPeriod = 'year' | 'decade' | 'century';

/** A moving object of the city. */
interface Thing {
  id: number;
  type: number;
  name: string;
  x: number;
  y: number;
  state: number;
}

interface Taxes {
  residential: number;
  commercial: number;
  industrial: number;
}

/** The funding of each department, in percent. */
interface Funding {
  police: number;
  fire: number;
  health: number;
  school: number;
  college: number;
  road: number;
  highway: number;
  bridge: number;
  rail: number;
  subway: number;
  tunnel: number;
}

interface BudgetInfo {
  taxes: Taxes;
  funding: Funding;
  autoBudget: boolean;
  bonds: number;
}

interface BudgetChanges {
  taxes?: Partial<Taxes>;
  funding?: Partial<Funding>;
  autoBudget?: boolean;
}

interface Ordinance {
  key: string;
  name: string;
  category: string;
  enabled: boolean;
  /** The yearly amount. A tax ordinance has income. */
  cost: number;
}

interface BondResult {
  bonds: number;
  rate: number;
  funds: number;
}

type SpeedName = 'Paused' | 'Turtle' | 'Llama' | 'Cheetah' | 'African Swallow';

interface Disaster {
  id: number;
  name: string;
}

interface ToolInfo {
  group: number;
  subtool: number;
  groupName: string;
  name: string;
  cost: number;
}

interface ToolListItem extends ToolInfo {
  available: boolean;
}

type ViewMode =
  | 'city' | 'underground' | 'density' | 'growth' | 'traffic' | 'pollution' | 'crime' | 'police_power' | 'fire_power'
  | 'land_value' | 'water' | 'power' | 'height';

/** The info.json fields of a mod. */
interface ModInfo {
  id: string;
  name: string;
  version: string;
  description: string;
  main: string;
  author: string;
  email: string;
  website: string;
  license: string;
  gameVersion: string;
  dependencies: string[];
}

/** A file or a folder in the mod folder. */
interface FileEntry {
  name: string;
  type: 'file' | 'directory' | 'other';
  size: number;
  /** The time of the last change, in milliseconds since 1970. */
  modified: number;
}

/** A JSON value, as `game.storage` and events copy it. */
type JsonValue = null | boolean | number | string | JsonValue[] | { [key: string]: JsonValue };

// ------------------------------------------------------------------ events

interface ToolAppliedDetail {
  tool: ToolInfo;
  start: TilePoint;
  finish: TilePoint;
  dragged: boolean;
  tiles: number;
  changed: boolean;
  cancelled: boolean;
  command: string;
  cost: number;
  message: string;
}

/** The fields of each game event, by type. */
interface GameEventMap {
  'city.opened': { name: string; size: number; date: CityDate };
  'city.closed': {};
  'city.saved': { path: string };
  'city.renamed': { name: string };
  'budget.changed': BudgetInfo;
  'sim.speed': { speed: SpeedName };
  'sim.day': { year: number; month: number; day: number; age: number };
  'sim.month': { year: number; month: number };
  'sim.year': { year: number };
  'disaster.beforeStart': { id: number; name: string; x: number; y: number };
  'disaster.started': Disaster;
  'disaster.ended': Disaster;
  news: { type: number; argument: number };
  notice: { id: number };
  'budget.prompt': {};
  'military.proposal': {};
  'game.over': { type: string; funds: number };
  'tool.selected': { tool: ToolInfo };
  'tool.beforeApply': { tool: ToolInfo; start: TilePoint; finish: TilePoint; dragged: boolean; tiles: number };
  'tool.applied': ToolAppliedDetail;
  'tool.undone': { command: string };
  'view.mode': { mode: ViewMode };
  frame: { delta: number };
  'mod.loaded': { id: string; name: string; version: string };
  'mod.unloaded': { id: string };
}

/** The event object that a listener receives. */
type GameEvent<Detail = {}> = Detail & {
  readonly type: string;
  readonly cancelable: boolean;
  /** True when a listener cancelled a cancelable event. */
  cancelled: boolean;
  /** Stops the action of a cancelable event, such as `tool.beforeApply`. */
  cancel(): void;
  /** The id of the mod that sent an event of `game.emit`, or `'console'`. */
  source?: string;
};

type Listener<Detail> = (event: GameEvent<Detail>) => void;

// ------------------------------------------------------------------ globals

interface Game {
  /** `{ game, godot, quickjs }` version texts. */
  readonly version: { game: string; godot: string; quickjs: string };
  /** The event types of the game and their descriptions. */
  readonly events: Record<keyof GameEventMap, string>;
  /** The info of each mod that runs. */
  readonly mods: ModInfo[];

  /** Calls the listener for each event of the type. `'*'` listens to all events. Returns a function that removes the listener. */
  on<Type extends keyof GameEventMap>(type: Type, listener: Listener<GameEventMap[Type]>, options?: { once?: boolean }): () => boolean;
  on(type: '*', listener: Listener<Record<string, any>>, options?: { once?: boolean }): () => boolean;
  on<Detail = Record<string, any>>(type: string, listener: Listener<Detail>, options?: { once?: boolean }): () => boolean;
  /** Listens to the next event of the type only. */
  once<Type extends keyof GameEventMap>(type: Type, listener: Listener<GameEventMap[Type]>): () => boolean;
  once<Detail = Record<string, any>>(type: string, listener: Listener<Detail>): () => boolean;
  /** Removes a listener. Returns true when it was there. */
  off(type: string, listener: (event: any) => void): boolean;
  listenerCount(type: string): number;
  /**
   * Sends an event to the script listeners of the console and of each mod. Each runtime gets a copy of the
   * detail, with `source`. A mod cannot send a game event. Start the type with the id of your mod.
   */
  emit(type: string, detail?: { [key: string]: JsonValue }): void;
  /** Adds a console command. The handler receives the words after the name, and returns the text to show. */
  command(name: string, description: string, handler: (...words: string[]) => unknown): void;
  /** Shows a message on the status bar. */
  status(text: string): void;
  /** Values that stay after the game closes. Each mod has its own values. */
  readonly storage: {
    /** The stored value, or the fallback. Give the type for a TypeScript check: `get<Zone[]>('zones', [])`. */
    get<Value = any>(key: string, fallback?: NoInfer<Value>): Value;
    set(key: string, value: JsonValue): true;
    remove(key: string): boolean;
    keys(): string[];
  };
}

interface City {
  readonly loaded: boolean;
  /** A copy of the main city values. */
  info(): CityInfo;
  readonly name: string;
  readonly mayor: string;
  /** The number of tiles on each map edge. */
  readonly size: number;
  readonly population: number;
  readonly date: CityDate;
  readonly demand: Demand;
  /** Get or set the funds. Setting them is a cheat. */
  funds: number;
  /** Adds a positive or negative amount, as a cheat. Returns the new funds. */
  addFunds(amount: number): number;
  /** The stored values of a tile, or null outside the map. */
  tile(x: number | TileArgument, y?: number): Tile | null;
  /** The value of a data map at a tile. */
  data(name: DataMapName, x: number | TileArgument, y?: number): number;
  dataMap(name: DataMapName): DataMap;
  readonly dataMaps: DataMapName[];
  /** A graph history, oldest value first. */
  graph(name: GraphName, period?: GraphPeriod): number[];
  readonly graphs: GraphName[];
  /** Gives the city a new name. Returns the name. */
  rename(name: string): string;
  /** The text of the sign on a tile, or null. */
  sign(x: number | TileArgument, y?: number): string | null;
  /** Places or changes a sign. An empty text removes it. */
  setSign(x: number, y: number, text: string): true;
  /** The moving objects. */
  things(): Thing[];
  /** Saves the city to its file. Returns the path. */
  save(): string;
}

interface Budget {
  info(): BudgetInfo;
  readonly taxes: Taxes;
  readonly funding: Funding;
  /** Changes the named values. Tax rates go from 0 to 22, funding from 0 to 100. */
  set(changes: BudgetChanges): BudgetInfo;
  ordinances(): Ordinance[];
  /** Enables or disables an ordinance by its key or its name. Returns the new state. */
  setOrdinance(key: string, enabled?: boolean): boolean;
  /** Issues a $10,000 bond. Throws when the council refuses it. */
  issueBond(): BondResult;
  /** Repays the oldest bond. */
  repayBond(): BondResult;
}

interface Sim {
  /** Get or set the speed, by name or from 1 to 5. */
  speed: SpeedName | number;
  readonly paused: boolean;
  pause(): void;
  /** Selects the speed before the pause. */
  resume(): void;
  /** Runs one day while the game is paused. Returns a report. */
  step(): string;
  /** The active disaster, or null. */
  readonly disaster: Disaster | null;
  /** The disaster names and ids. */
  readonly disasters: Record<string, number>;
  /** Starts a disaster by name or id at a tile, or at the view center. This is a cheat. */
  startDisaster(disaster: string | number, x?: number | TileArgument, y?: number): Disaster;
  /** Ends the active disaster. False without a disaster. */
  endDisaster(): boolean;
  /** Get or set: true turns the random disasters off. */
  noDisasters: boolean;
  /** Runs at the speed until the date, then pauses. */
  runUntil(date: { year: number; month?: number; day?: number }, speed?: SpeedName | number): boolean;
}

interface Tools {
  list(): ToolListItem[];
  readonly selected: ToolInfo;
  /** Selects a tool by its group and tool name or index, or by one tool or group name. */
  select(group: string | number, tool?: string | number): ToolInfo;
  /** Uses the selected tool as a drag from one tile to another. Without `to`, it is a click. */
  apply(from: TileArgument, to?: TileArgument): ToolAppliedDetail;
  /** Undoes the last edit. False when there is nothing to undo. */
  undo(): boolean;
}

interface View {
  /** The tile at the center of the view. */
  readonly center: TilePoint;
  /** Moves the view to a tile. */
  centerOn(x: number | TileArgument, y?: number): boolean;
  /** Get or set the view. */
  mode: ViewMode;
  readonly modes: ViewMode[];
  /** The zoom in percent. */
  readonly zoom: number;
  zoomIn(): number;
  zoomOut(): number;
  /** The compass rotation, 0 to 3. */
  readonly rotation: number;
  /** A quarter turn, clockwise unless the argument is false. Returns the rotation. */
  rotate(clockwise?: boolean): number;
}

interface Ui {
  /** A message window with an OK button. The game continues while it shows. */
  alert(text: string, title?: string): void;
  /** Shows a message on the status bar. */
  status(text: string): void;
  /** Plays SOUNDS/<id>.WAV of the sound pack. */
  playSound(id: number): void;
}

/** The files of the mod folder. Each path is relative to the folder; a path outside it throws an Error. */
interface ModFiles {
  readText(path: string): string;
  readJSON<Value = JsonValue>(path: string): Value;
  readBytes(path: string): Uint8Array;
  /** Writes text to a file. Makes the missing folders. */
  writeText(path: string, text: string): void;
  appendText(path: string, text: string): void;
  writeJSON(path: string, value: unknown, space?: number | string): void;
  writeBytes(path: string, data: Uint8Array | ArrayBuffer | ArrayBufferView | number[]): void;
  exists(path: string): boolean;
  stat(path: string): FileEntry | null;
  list(path?: string): FileEntry[];
  makeFolder(path: string): void;
  /** Removes a file or a folder. Returns false when nothing was there. */
  remove(path: string, options?: { recursive?: boolean }): boolean;
  rename(from: string, to: string): void;
}

interface Mod {
  readonly id: string;
  readonly name: string;
  readonly version: string;
  /** All fields of info.json. */
  readonly info: Readonly<ModInfo>;
  readonly files: ModFiles;
}

declare const game: Game;
declare const city: City;
declare const budget: Budget;
declare const sim: Sim;
declare const tools: Tools;
declare const view: View;
declare const ui: Ui;
/** The mod of this runtime. Only the runtime of a mod has it; the console runtime does not. */
declare const mod: Mod;

/** The text that the console shows for a value. */
declare function inspect(value: unknown, options?: { depth?: number }): string;

// QuickJS-ng has the timers of the game, without the DOM or Node.js types
declare function setTimeout(callback: (...values: any[]) => void, ms?: number, ...values: any[]): number;
declare function setInterval(callback: (...values: any[]) => void, ms?: number, ...values: any[]): number;
declare function clearTimeout(id: number | undefined): void;
declare function clearInterval(id: number | undefined): void;

interface Console {
  log(...values: unknown[]): void;
  info(...values: unknown[]): void;
  debug(...values: unknown[]): void;
  warn(...values: unknown[]): void;
  error(...values: unknown[]): void;
  trace(...values: unknown[]): void;
  dir(value: unknown, options?: { depth?: number }): void;
  assert(condition: unknown, ...values: unknown[]): void;
  count(label?: string): void;
  countReset(label?: string): void;
  time(label?: string): void;
  timeEnd(label?: string): void;
}

declare var console: Console;
