import game from "@/app/game"
import graphics from "@/app/graphics"
import { colors } from "@/app/constants"
import data from "./"

export const loadMap = async () => {
  const [{ id, name, rotation, water_level: waterLevel }] = await data.db
    .raw(`select * from city where id = (select max(id) from city)`)

  // TODO: Replace with React UI
  if (!id) {
    graphics.primaryContext.font = `24px Verdana`
    graphics.primaryContext.fillStyle = colors.white
    graphics.primaryContext.textAlign = `center`
    graphics.primaryContext.fillText(
      `Could not load city!`,
      document.documentElement.clientWidth / 2,
      graphics.primaryContext.canvas.height / 2
    )
    return
  }

  info(`Loading City: ${id}`)

  data.cityId = id
  data.cityName = name
  data.cityRotation = rotation

  info(` - Map Rotation: ${game.mapRotation}, Saved City Rotation: ${data.cityRotation}`)

  game.waterLevel = waterLevel

  // params that change depending on the imported city rotation
  if (data.cityRotation === 0) {
    game.corners = [`1000`, `0100`, `0010`, `0001`]
    game.rotationModifier = 0
  } else if (data.cityRotation === 1) {
    game.corners = [`0001`, `1000`, `0100`, `0010`]
    game.rotationModifier = 1
  } else if (data.cityRotation === 2) {
    game.corners = [`0010`, `0001`, `1000`, `0100`]
    game.rotationModifier = 2
  } else if (data.cityRotation === 3) {
    game.corners = [`0100`, `0010`, `0001`, `1000`]
    game.rotationModifier = 3
  }

  const rows = await data.db.raw(
    `select * from map where city_id = :id and x < :max and y < :max order by x asc, y asc`,
    { id, max: game.maxMapSize }
  )

  for (const { x, y, z, rotate, ...row } of rows) {
    if (typeof data.map[x] === `undefined`) data.map[x] = []
    if (typeof data?.map[x][y] === `undefined`) data.map[x][y] = []

    data.map[x][y] = {
      x,
      y,
      z,
      original_x: x,
      original_y: y,
      tiles: {
        terrain: row.terrain_tile_id,
        building: row.building_tile_id,
        zone: row.zone_tile_id,
        underground: row.underground_tile_id
      },
      water_level: row.water_level,
      corners: row.building_corners,
      rotate
    }
  }

  data.cityLoaded = true
  info(`City Loaded`)
}
