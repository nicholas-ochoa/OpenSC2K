class Util {
  static wrap (value, min, max) {
    if (value > max)
      value = min;

    if (value < min)
      value = max;

    return value;
  }

  static isNumberBetween (value, min, max) {
    return value >= min && value <= max;
  }
}

export default Util;