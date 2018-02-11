import data from "./"

export const loadTiles = async () => {
  info(`Loading Tiles..`)
  const rows = await data.db.raw(`select * from tiles order by id asc`)

  for (const { id, slopes, polygon, lines, ...rest } of rows) {
    data.tiles[id] = {
      id,
      width: null,
      height: null,
      image: [],
      slopes: eval(slopes), // eslint-disable-line
      polygon: eval(polygon), // eslint-disable-line
      lines: eval(lines), // eslint-disable-line
      ...rest
    }
  }

  info(`Tiles Loaded`)
}
