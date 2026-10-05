// Text helpers of the city statistics mod.

export function money(value) {
  const sign = value < 0 ? '-' : '';

  return `${sign}$${Math.abs(value).toLocaleString('en-US')}`;
}

// a fixed-width text table: rows is an array of arrays of cells
export function table(header, rows) {
  const widths = header.map((title, column) => Math.max(title.length, ...rows.map((row) => String(row[column]).length)));
  const line = (cells) => cells.map((cell, column) => String(cell).padStart(widths[column])).join('  ');

  return [line(header), line(widths.map((width) => '-'.repeat(width))), ...rows.map(line)].join('\n');
}
