export default class {
  public key: string;
  public top: boolean = false;
  public right: boolean = false;
  public bottom: boolean = false;
  public left: boolean = false;
  public none: boolean = false;

  constructor (options: any) {
    //this.key = options.cell.city.corner;
    this.top = options.top ?? false;
    this.right = options.right ?? false;
    this.bottom = options.bottom ?? false;
    this.left = options.left ?? false;
    this.none = options.none ?? false;
  }
}