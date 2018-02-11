import data, { binaryString } from "../"

export const XZON = (segment, { tiles }) => {
  (new Uint8Array(segment)).forEach((square, i) => {
    let zone = {}

    zone.corners = binaryString(square, 1).substring(0, 4) //first 4 bytes
    //zone.corners = '['+zone.corners[0]+','+zone.corners[1]+','+zone.corners[2]+','+zone.corners[3]+']'
    zone.zoneType = binaryString(square, 1).substring(4, 8) //last 4 bytes
    zone.type = data.xzonTypeMap[zone.zoneType]

    tiles[i].XZON = zone
  })
}
