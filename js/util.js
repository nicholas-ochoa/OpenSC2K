game.util = {

  toJson: function(jsonString){
    var data = '';
    
    if (jsonString !== ''){
      jsonString = '{ data: '+jsonString+'}';
      data = eval(jsonString);
    }

    return data;
  },

  boolToYn: function(val){
    if(val)
      return 'Y';
    else
      return 'N';
  },

  boolToInt: function(val){
    if(val)
      return 1;
    else
      return 0;
  }

}

Number.prototype.between = function (min, max) {
    return this > min && this < max;
};