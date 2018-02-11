import { writeFileSync } from "fs"

export const writeImageToFile = (id, image) => {
  writeFileSync(`${__dirname}/../../images/test/${id}.png`, Buffer.from(new Uint8Array(image)))
}
