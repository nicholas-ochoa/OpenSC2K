import { data } from '../data';

export function XGRP(bytes: Buffer) {
  let offset: number = 0;
  const graph: Record<string, Buffer> = {};

  graph.citySize = graphData(bytes.subarray(offset, offset += 208));
  graph.residents = graphData(bytes.subarray(offset, offset += 208));
  graph.commerce = graphData(bytes.subarray(offset, offset += 208));
  graph.industry = graphData(bytes.subarray(offset, offset += 208));
  graph.traffic = graphData(bytes.subarray(offset, offset += 208));
  graph.pollution = graphData(bytes.subarray(offset, offset += 208));
  graph.value = graphData(bytes.subarray(offset, offset += 208));
  graph.crime = graphData(bytes.subarray(offset, offset += 208));
  graph.powerPercentage = graphData(bytes.subarray(offset, offset += 208));
  graph.waterPercentage = graphData(bytes.subarray(offset, offset += 208));
  graph.health = graphData(bytes.subarray(offset, offset += 208));
  graph.education = graphData(bytes.subarray(offset, offset += 208));
  graph.unemployment = graphData(bytes.subarray(offset, offset += 208));
  graph.gnpInThousands = graphData(bytes.subarray(offset, offset += 208));
  graph.nationalPopulationInThousands = graphData(bytes.subarray(offset, offset += 208));
  graph.fedRate = graphData(bytes.subarray(offset, offset += 208));

  data.segments.XGRP = bytes;
}

function graphData(bytes: Buffer) {
  const data: any = {
    year: [],
    tenYear: [],
    hundredYear: [],
  };

  for (let i = 0; i < 52; i++) {
    const offset = i * 4;

    if (i < 12) {
      data.year.push(bytes.readUInt32BE(offset));
    } else if (i >= 12 && i < 32) {
      data.tenYear.push(bytes.readUInt32BE(offset));
    } else if (i >= 32) {
      data.hundredYear.push(bytes.readUInt32BE(offset));
    }
  }

  return data;
}
