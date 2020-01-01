export function decompressSegment(bytes) {
  const output = [];
  let dataCount = 0;

  for (let i = 0; i < bytes.length; i++) {
    if (dataCount > 0) {
      output.push(bytes[i]);
      dataCount -= 1;
      continue;
    }

    // data bytes
    if (bytes[i] < 128) {
      dataCount = bytes[i];

      // run-length encoded byte
    } else {
      const repeatCount = bytes[i] - 127;
      const repeated = bytes[i + 1];

      for (let i = 0; i < repeatCount; i++) output.push(repeated);

      // skip the next byte
      i += 1;
    }
  }

  return Uint8Array.from(output);
}
