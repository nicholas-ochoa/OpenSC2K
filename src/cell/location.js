import Phaser from 'phaser';

export default class location extends Phaser.Math.Vector3 {
  constructor (x, y, z) {
    super(x, y, z);
  }
}