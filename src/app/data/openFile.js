import fs from "fs"
import { remote } from 'electron'
import { isSimCity2000SaveFile, parse } from "./"

export const openFile = () => {
  remote.dialog.showOpenDialog(fileNames => {
    if (!fileNames) return

    try {
      const file = fs.readFileSync(fileNames[0])
      const bytes = new Uint8Array(file)

      if (!isSimCity2000SaveFile(bytes)) {
        info(`File is not a valid SimCity 2000 SC2 Save File`)
        return
      }

      parse(bytes)
    } catch (err) {
      info(`Error reading file: ${err.message}`, err)
    }
  })
}
