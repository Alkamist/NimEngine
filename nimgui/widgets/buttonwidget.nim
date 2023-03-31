{.experimental: "overloadableEnums".}

import ../guimod
import ./frame

type
  ButtonWidget* = ref object of GuiWidget
    isDown*: bool
    wasDown*: bool
    justClicked*: bool

template justPressed*(button: ButtonWidget): bool = button.isDown and not button.wasDown
template justReleased*(button: ButtonWidget): bool = button.wasDown and not button.isDown

func update*(button: ButtonWidget, gui: Gui) =
  button.justClicked = false
  button.wasDown = button.isDown

  if button.isHovered and gui.mouseJustPressed(Left):
    button.isDown = true

  if button.isDown and gui.mouseJustReleased(Left):
    button.isDown = false
    if button.isHovered:
      button.justClicked = true

  let gfx = gui.drawList
  let bodyColor = rgb(33, 38, 45)
  let borderColor = rgb(52, 59, 66)
  # let textColor = rgb(201, 209, 217)

  let bodyColorHighlighted =
    if button.isDown: bodyColor.darken(0.3)
    elif button.isHovered: bodyColor.lighten(0.05)
    else: bodyColor

  let borderColorHighlighted =
    if button.isDown: borderColor.darken(0.1)
    elif button.isHovered: borderColor.lighten(0.4)
    else: borderColor

  gfx.drawFrame(
    bounds = button.bounds,
    borderThickness = 1.0,
    cornerRadius = 5.0,
    bodyColor = bodyColorHighlighted,
    borderColor = borderColorHighlighted,
  )

template button*(gui: Gui, name, code: untyped): untyped =
  let `name` {.inject.} = gui.addWidget(makeGuiId(name), ButtonWidget)
  code
  name.update(gui)