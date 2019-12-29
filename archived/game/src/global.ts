const wa: any = window;

let game: any;
let world: any;
let tiles: any;
let city: any;
let map: any;
let cells: any;
let sim: any;
let scene: any;
let data: any;

const global: any = {
  _game: {},
  _world: {},
  _tiles: {},
  _city: {},
  _map: {},
  _cells: {},
  _sim: {},
  _scene: {},
  _data: {},

  init() {
    wa.global = this;
    delete this.init;
  },

  set game(value) {
    this._game = value;

    wa.game = this._game;
    game = this._game;
  },

  set world(value) {
    this._world = value;

    wa.world = this._world;
    world = this._world;
  },

  set tiles(value) {
    this._tiles = value;

    wa.tiles = this._tiles;
    tiles = this._tiles;
  },

  set city(value) {
    this._city = value;

    wa.city = this._city;
    city = this._city;
  },

  set map(value) {
    this._map = value;

    wa.map = this._map;
    map = this._map;
  },

  set cells(value) {
    this._cells = value;

    wa.cells = this._cells;
    cells = this._cells;
  },

  set sim(value) {
    this._sim = value;

    wa.sim = this._sim;
    sim = this._sim;
  },

  set scene(value) {
    this._scene = value;

    wa.scene = this._scene;
    scene = this._scene;
  },

  set data(value) {
    this._data = value;

    wa.data = this._data;
    data = this._data;
  },

  get game() {
    return this._game;
  },

  get world() {
    return this._world;
  },

  get tiles() {
    return this._tiles;
  },

  get city() {
    return this._city;
  },

  get map() {
    return this._map;
  },

  get cells() {
    return this._cells;
  },

  get sim() {
    return this._sim;
  },

  get scene() {
    return this._scene;
  },

  get data() {
    return this._data;
  },
};

export { global, game, world, tiles, city, map, cells, sim, scene, data };
