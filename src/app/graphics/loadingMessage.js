import { colors } from "@/app/constants"
import graphics from "./"

// initial loading message while images and resources load
export const loadingMessage = () => {
  const { interfaceContext: { fillText, ...props } } = graphics
  props.font = `24px Verdana`
  props.fillStyle = colors.white
  props.textAlign = `center`
  fillText(`Loading resources..`, document.documentElement.clientWidth / 2, document.documentElement.clientHeight / 2)
  props.textAlign = `left`
}
