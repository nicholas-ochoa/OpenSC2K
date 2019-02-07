export default (data, map) => {
  let tmpl = {};

  tmpl.raw = data;

  map._segmentData.TMPL = tmpl;
};