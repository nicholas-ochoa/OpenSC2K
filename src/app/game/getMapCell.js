import data from "@/app/data"

export const getMapCell = (xT, yT) => data?.map?.[xT]?.[yT] || false
