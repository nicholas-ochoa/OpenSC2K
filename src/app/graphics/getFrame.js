import graphics from "./"

// returns the current animation frame for a given tile object
export const getFrame = ({ frames }) => ((frames)
  ? 0
  : graphics.animationFrame - Math.floor(graphics.animationFrame / frames) * frames
)
