import data from "./"

export const clear = async () => {
  await data.db.raw(`delete from map`)
  await data.db.raw(`delete from city`)
  await data.db.raw(`vacuum main`)
  info(`Database tables 'map' and 'city' have been truncated`)
}
