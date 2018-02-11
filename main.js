import path from "path"
import url from "url"
import { app, BrowserWindow } from "electron"
import logger from "electron-log"

logger.transports.rendererConsole.level = `debug`

let mainWindow

app.commandLine.appendSwitch(`remote-debugging-port`, `2000`)
app.commandLine.appendSwitch(`enable-precise-memory-info`)

app.on(`ready`, () => {
  mainWindow = new BrowserWindow({
    width: 1280,
    height: 1024,
    webPreferences: {
      experimentalCanvasFeatures: true
    }
  })

  mainWindow.loadURL(url.format({
    pathname: path.join(__dirname, `index.html`),
    protocol: `file:`,
    slashes: true
  }))

  mainWindow.webContents.openDevTools()

  mainWindow.on(`closed`, () => {
    mainWindow = null
  })
})

app.on(`window-all-closed`, () => {
  app.quit()
})
