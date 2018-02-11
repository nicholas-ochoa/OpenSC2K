import { getTileUnderCursor, setSelectedTile } from "@/app/game"
import { setDrawFrame, updateCanvasSize } from "@/app/graphics"
import { centerCameraOnClick } from "@/app/ui"
import events, { keymap } from "./"

export const register = () => {
  document.addEventListener(`mousewheel`, event => {
    event.preventDefault()
  })

  window.addEventListener(`resize`, () => {
    updateCanvasSize()
  })

  document.addEventListener(`mousemove`, event => {
    getTileUnderCursor(event)
  })

  document.addEventListener(`click`, event => {
    event.preventDefault()
    getTileUnderCursor(event)
    setSelectedTile()

    if (events.activeCursorTool === `center`) centerCameraOnClick()
  })

  document.addEventListener(`keydown`, event => {
    setDrawFrame()

    keymap[event.key]
  })
}
