import { main } from "./"

export const loop = () => {
  main()
  requestAnimationFrame(loop)
}
