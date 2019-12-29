import { bin2str } from './common';

export default (data, map) => {
  let view = new DataView(data.buffer, data.byteOffset, data.byteLength);

  for (let i = 0; i < data.byteLength / 2; i++) {
    let bits = view.getUint16(i * 2);
    let altm = {};

    // how many levels below altitude should we display a grey block
    // for a tunnel?
    altm.tunnelLevels    = (((bits >> 8) & 0b11111100) >> 2);

    // related to tunnel?
    // appears to be set to 1 for hydroelectric dams and nearby
    // surface water tiles
    // not used for now
    //altm.unknownBits     = ((bits >> 8) & 0b00000011);

    // level / altitude
    altm.altitude        = (bits & 0b0000000000011111);

    // unknown, not always accurate (rely on XTER value instead)
    // not used for now
    //altm.waterLevel      = (bits & 0b0000000001100000) >> 5;

    // unknown, not always accurate (rely on XTER value instead)
    // not used for now
    //altm.waterCovered    = (bits & 0b0000000010000000) >> 7;

    // raw binary values as strings for research/debug
    altm.binaryText = {
      bits:             bin2str(bits, 16),
      first8bits:       bin2str((bits & 0b1111111100000000) >> 8, 8),
      last8bits:        bin2str((bits & 0b0000000011111111), 8),
      //tunnelLevelsBits: bin2str(altm.tunnelLevels, 8),
      //unknownBits:      bin2str(altm.unknownBits,  8),
      //altitudeBits:     bin2str(altm.altitude,     8),
      //waterLevelBits:   bin2str(altm.waterLevel,   8),
      //waterCoveredBits: bin2str(altm.waterCovered, 8),
    };

    map.cells[i]._segmentData.ALTM = altm;
  }
};