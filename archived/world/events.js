import * as tools from './tools/';
import * as CONST from '../constants';

export default class events {
  constructor(options) {
    this.scene = options.scene;
    //this.selectedTool = CONST.TOOL_CENTER;
    //this.selectedTool = CONST.TOOL_QUERY;
    this.selectedTool = CONST.TOOL_ROADS;
    this.register();

    this.tools = {};

    Object.keys(tools).forEach((t) => {
      this.tools[t] = new tools[t]({ scene: this.scene });
    });
  }
  

  register () {
    //window.addEventListener(CONST.E_RESIZE, () => {
    //  this.scene.game.scale.resize(window.innerWidth, window.innerHeight);
    //});

    this.scene.scale.on(CONST.E_RESIZE, this.resize, this);
    this.scene.input.on(CONST.E_POINTER_OVER, this.onPointerOver, this);
    this.scene.input.on(CONST.E_POINTER_OUT,  this.onPointerOut,  this);
    this.scene.input.on(CONST.E_POINTER_MOVE, this.onPointerMove, this);
    this.scene.input.on(CONST.E_POINTER_DOWN, this.onPointerDown, this);
    this.scene.input.on(CONST.E_POINTER_UP,   this.onPointerUp,   this);
  }


  onPointerUp (pointer) {
    if (this.selectedTool)
      this.tools[this.selectedTool].onPointerUp(pointer);
  }


  onPointerDown (pointer, camera) {
    if (this.selectedTool)
      this.tools[this.selectedTool].onPointerDown(pointer, camera);
  }


  onPointerMove (pointer, localX, localY) {
    this.scene.viewport.onPointerMove(pointer);

    if (this.selectedTool)
      this.tools[this.selectedTool].onPointerMove(pointer, localX, localY);
  }


  onPointerOver (pointer, localX, localY) {
    if (this.selectedTool)
      this.tools[this.selectedTool].onPointerOver(pointer, localX, localY);
  }


  onPointerOut (pointer) {
    if (this.selectedTool)
      this.tools[this.selectedTool].onPointerOut(pointer);
  }


  resize (gameSize) {
    this.scene.cameras.resize(gameSize.width, gameSize.height);
  }
}