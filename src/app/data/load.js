import knex from "knex"
import data, { loadTiles, loadMap } from "./"

export const load = async () => {
  data.db = await knex({
    client: `sqlite`,
    connection: {
      filename: `./db/database.sqlite`
    },
    pool: {
      afterCreate: (connection, cb) => connection.run(`PRAGMA journal_mode = WAL`, cb) // eslint-disable-line
    },
    useNullAsDefault: true,
    debug: true
  })

  await loadTiles()
  await loadMap()
  await data.db.raw(`vacuum main`)
}
