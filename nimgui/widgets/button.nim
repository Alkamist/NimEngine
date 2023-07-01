import ../gui

type
  GuiButton* = ref object of GuiNode
    size*: Vec2
    isDown*: bool
    pressed*: bool
    released*: bool
    clicked*: bool
    inputHeld: bool

proc default*(button: GuiButton) =
  button.size = vec2(32, 96)

proc update*(button: GuiButton, hover, press, release: bool) =
  let isHovered = button.isHovered

  if press: button.inputHeld = true
  if release: button.inputHeld = false

  button.pressed = false
  button.released = false
  button.clicked = false

  if isHovered and not button.isDown and press:
    button.isDown = true
    button.pressed = true

  if button.isDown and release:
    button.isDown = false
    button.released = true
    if isHovered:
      button.clicked = true

  if hover:
    button.requestHover()

  if button.inputHeld and not press:
    button.clearHover()

proc update*(button: GuiButton, mouseButton = MouseButton.Left) =
  button.register()

  let m = button.mousePosition
  let mouseHit =
    m.x >= 0.0 and m.x <= button.size.x and
    m.y >= 0.0 and m.y <= button.size.y

  button.update(
    hover = mouseHit,
    press = button.mousePressed(mouseButton),
    release = button.mouseReleased(mouseButton),
  )

proc draw*(button: GuiButton) =
  let path = Path.new()
  path.roundedRect(vec2(0, 0), button.size, 3)

  button.fillPath(path, rgb(31, 32, 34))
  if button.isDown:
    button.fillPath(path, rgba(0, 0, 0, 8))
  elif button.isHovered:
    button.fillPath(path, rgba(255, 255, 255, 8))