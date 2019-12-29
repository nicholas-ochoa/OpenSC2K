export default class simulation {
  constructor (options) {
    this.scene = options.scene;
    this.common = this.scene.sys.game.common;
    this.sims = [];
    this.simTick = 0;

    this.paused = false;

    this.timer = this.scene.time.addEvent({
      delay: 1000,
      callback: () => { this.tick(); },
      cellbackScope: this,
      loop: true
    });
  }

  tick () {
    if (this.paused)
      return;

    this.sims.forEach((sim) => {
      
    });

    this.simTick++;
  }

  register () {

  }

  deregister () {
    
  }

  sleep () {
    this.paused = true;
  }

  wake () {
    this.paused = false;
  }
}