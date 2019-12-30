/* eslint-disable */
require('phaser/polyfills');
const CONST = require('phaser/const');
const Extend = require('phaser/utils/object/Extend');
/* eslint-enable */

let Phaser = {
  Actions: require('phaser/actions'),
  Animations: require('phaser/animations'),
  Cache: require('phaser/cache'),
  Cameras: require('phaser/cameras'),
  Core: require('phaser/core'),
  Class: require('phaser/utils/Class'),
  Create: require('phaser/create'),
  Curves: require('phaser/curves'),
  Data: require('phaser/data'),
  Display: require('phaser/display'),
  DOM: require('phaser/dom'),
  Events: require('phaser/events/EventEmitter'),
  Game: require('phaser/core/Game'),
  GameObjects: require('phaser/gameobjects'),
  Geom: require('phaser/geom'),
  Input: require('phaser/input'),
  Loader: require('phaser/loader'),
  Math: require('phaser/math'),
  //Physics: require('phaser/physics'),
  Plugins: require('phaser/plugins'),
  Renderer: require('phaser/renderer'),
  Scale: require('phaser/scale'),
  Scene: require('phaser/scene/Scene'),
  Scenes: require('phaser/scene'),
  Sound: require('phaser/sound'),
  Structs: require('phaser/structs'),
  Textures: require('phaser/textures'),
  Tilemaps: require('phaser/tilemaps'),
  Time: require('phaser/time'),
  Tweens: require('phaser/tweens'),
  Utils: require('phaser/utils'),
};

//   Merge in the consts

Phaser = Extend(false, Phaser, CONST);

//  Export it

module.exports = Phaser;

global.Phaser = Phaser;
