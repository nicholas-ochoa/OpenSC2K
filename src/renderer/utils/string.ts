String.prototype.inList = function(list) {
  return Array.apply(null, arguments).indexOf(this.toString()) != -1;
};
