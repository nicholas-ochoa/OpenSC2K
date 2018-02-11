import data, { boolToYN } from "./"

export const loadCity = () => {
  info(`Loading City into Database..`)

  info(`Imported City Rotation: ${data.struct.MISC.rotation}`)

  const cityId = data.db.raw(`select ifnull(max(id), 0) + 1 as id from city`)
  const name = `Test City`
  data.db.raw(
    `insert into city (id, name, tiles_x, tiles_y, rotation, water_level) values (?)`,
    [[cityId.id, name, 128, 128, data.struct.MISC.rotation, data.struct.MISC.waterLevel]]
  )

  const sql = `
    insert into map (
      x, y, z, city_id, terrain_tile_id, zone_tile_id, underground_tile_id, building_tile_id, building_corners,
      zone_type, water_level, surface_water, conductive, powered, piped, watered, land_value, water_covered,
      rotate, salt_water, subway, subway_station, subway_direction, pipes
    ) values (
      :x, :y, :z, :city_id, :terrain_tile_id, :zone_tile_id, :underground_tile_id, :building_tile_id, :building_corners,
      :zone_type, :water_level, :surface_water, :conductive, :powered, :piped, :watered, :land_value, :water_covered,
      :rotate, :salt_water, :subway, :subway_station, :subway_direction, :pipes
    )
  `
  for (const tile of data.struct.tiles) {
    data.db.raw(sql, {
      x: tile.x,
      y: tile.y,
      z: tile.ALTM.altitude,
      city_id: cityId.id,
      terrain_tile_id: data.xterTerrainTileMap[(tile.XTER.id > 13 ? tile.XTER.id - 14 : tile.XTER.id)],
      zone_tile_id: (tile.XZON.type > 0 ? 290 + tile.XZON.type : 0), //291 is the tileID start for zones,
      underground_tile_id: 0,
      building_tile_id: tile.XBLD.id,
      building_corners: tile.XZON.corners,
      zone_type: tile.XZON.type,
      water_level: tile.XTER.waterLevel,
      surface_water: tile.XTER.surfaceWater,
      conductive: boolToYN(tile.XBIT.conductive),
      powered: boolToYN(tile.XBIT.powered),
      piped: boolToYN(tile.XBIT.piped),
      watered: boolToYN(tile.XBIT.watered),
      land_value: boolToYN(tile.XBIT.landValue),
      water_covered: boolToYN(tile.XBIT.waterCovered),
      rotate: boolToYN(tile.XBIT.rotate),
      salt_water: boolToYN(tile.XBIT.saltWater),
      subway: boolToYN(tile.XUND.subway),
      subway_station: boolToYN(tile.XUND.subwayStation),
      subway_direction: boolToYN(tile.XUND.subwayLeftRight),
      pipes: boolToYN(tile.XUND.pipes)
    })
  }

  alert(`City Loaded! Click "OK" to reload..`) // eslint-disable-line
  window.location.reload()
}
