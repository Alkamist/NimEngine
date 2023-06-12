{.experimental: "overloadableEnums".}

import std/hashes
import std/tables
import std/algorithm
import ./math; export math
import ./layout
import ./vectorgraphics; export vectorgraphics
import oswindow; export oswindow

type
  GuiId* = Hash

  GuiState* = ref object of RootObj
    id*: GuiId
    init*: bool

  GuiLayer* = ref object of GuiState
    vg*: VectorGraphics
    offset: Vec2
    zIndex: int
    layoutStack: seq[GuiLayout]
    finalMouseOver: GuiId
    controlEngaged: bool
    controlHovered: bool

  Gui* = ref object
    size*: Vec2
    scale*: float
    time*: float
    globalMousePosition*: Vec2
    mouseWheel*: Vec2
    mousePresses*: seq[MouseButton]
    mouseReleases*: seq[MouseButton]
    mouseDownStates*: array[MouseButton, bool]
    keyPresses*: seq[KeyboardKey]
    keyReleases*: seq[KeyboardKey]
    keyDownStates*: array[KeyboardKey, bool]
    textInput*: string

    defaultItemSize*: Vec2
    itemSpacing*: Vec2

    hover*: GuiId
    focus*: GuiId
    mouseCapture*: GuiId
    currentId*: GuiId
    currentBounds*: Rect2
    highestZIndex*: int
    cursorStyle*: CursorStyle
    layerEngaged*: GuiId
    hoverLayer*: GuiId

    retainedState: Table[GuiId, GuiState]

    idStack: seq[GuiId]
    layerStack: seq[GuiLayer]
    activeLayers: seq[GuiLayer]

    finalMouseOver: GuiId

    vgCtx: VectorGraphicsContext

    previousTime: float
    previousGlobalMousePosition: Vec2

proc mouseDelta*(gui: Gui): Vec2 = gui.globalMousePosition - gui.previousGlobalMousePosition
proc deltaTime*(gui: Gui): float = gui.time - gui.previousTime
proc mouseDown*(gui: Gui, button: MouseButton): bool = gui.mouseDownStates[button]
proc keyDown*(gui: Gui, key: KeyboardKey): bool = gui.keyDownStates[key]
proc mouseMoved*(gui: Gui): bool = gui.mouseDelta != vec2(0, 0)
proc mouseWheelMoved*(gui: Gui): bool = gui.mouseWheel != vec2(0, 0)
proc mousePressed*(gui: Gui, button: MouseButton): bool = button in gui.mousePresses
proc mouseReleased*(gui: Gui, button: MouseButton): bool = button in gui.mouseReleases
proc anyMousePressed*(gui: Gui): bool = gui.mousePresses.len > 0
proc anyMouseReleased*(gui: Gui): bool = gui.mouseReleases.len > 0
proc keyPressed*(gui: Gui, key: KeyboardKey): bool = key in gui.keyPresses
proc keyReleased*(gui: Gui, key: KeyboardKey): bool = key in gui.keyReleases
proc anyKeyPressed*(gui: Gui): bool = gui.keyPresses.len > 0
proc anyKeyReleased*(gui: Gui): bool = gui.keyReleases.len > 0

proc getId*[T: not GuiId](gui: Gui, x: T): GuiId =
  if gui.idStack.len > 0:
    result = !$(gui.idStack[^1] !& hash(x))
  else:
    result = hash(x)
  gui.currentId = result

proc beginIdSpace*(gui: Gui, id: GuiId) =
  gui.idStack.add(id)

proc beginIdSpace*(gui: Gui, str: string) =
  gui.beginIdSpace(gui.getId(str))

proc endIdSpace*(gui: Gui) =
  discard gui.idStack.pop()

proc currentIdSpace*(gui: Gui): GuiId =
  gui.idStack[gui.idStack.len - 1]

proc currentLayer*(gui: Gui): GuiLayer =
  gui.layerStack[gui.layerStack.len - 1]

proc mousePosition*(gui: Gui): Vec2 =
  gui.globalMousePosition - gui.currentLayer.offset

proc vg*(gui: Gui): VectorGraphics =
  gui.currentLayer.vg

proc getState*(gui: Gui, id: GuiId, T: typedesc): T =
  if gui.retainedState.hasKey(id):
    result = T(gui.retainedState[id])
    result.init = false
  else:
    result = T()
    result.init = true
    result.id = id
    gui.retainedState[id] = result

proc getState*(gui: Gui, str: string, T: typedesc): T =
  gui.getState(gui.getId(str), T)

template currentLayout(gui: Gui): untyped =
  let layer = gui.currentLayer
  layer.layoutStack[layer.layoutStack.len - 1]

proc row*(gui: Gui, widths: openArray[float], height: float) =
  gui.currentLayout.row(widths, height)

proc getNextBounds*(gui: Gui): Rect2 =
  result = gui.currentLayout.getNextBounds()
  gui.currentBounds = result

proc beginLayout*(gui: Gui, bounds: Rect2, scroll: Vec2) =
  let layer = gui.currentLayer
  layer.layoutStack.add GuiLayout(
    itemSpacing: gui.itemSpacing,
    defaultItemSize: gui.defaultItemSize,
    bounds: rect2(
      bounds.x - scroll.x, bounds.y - scroll.y,
      bounds.width, bounds.height,
    ),
    max: vec2(low(float), low(float)),
  )
  gui.row([0.0], 0.0)

proc endLayout*(gui: Gui) =
  let layer = gui.currentLayer
  discard layer.layoutStack.pop()

proc beginColumn*(gui: Gui) =
  gui.beginLayout(gui.getNextBounds(), vec2(0, 0))

proc endColumn*(gui: Gui) =
  let layer = gui.currentLayer
  let b = layer.layoutStack.pop()
  var a = layer.layoutStack[layer.layoutStack.len - 1]
  a.rowSize.x = max(a.rowSize.x, b.rowSize.x + b.bounds.x - a.bounds.x)
  a.nextRow = max(a.nextRow, b.nextRow + b.bounds.y - a.bounds.y)
  a.max.x = max(a.max.x, b.max.x)
  a.max.y = max(a.max.y, b.max.y)
  layer.layoutStack[layer.layoutStack.len - 1] = a

proc setNextBounds*(gui: Gui, bounds: Rect2, positioning = GuiPositioning.Relative) =
  gui.currentLayout.setNextBounds(bounds, positioning)

proc beginLayer*(gui: Gui, id: GuiId, offset, scroll = vec2(0, 0), zIndex = 0) =
  let layer = gui.getState(id, GuiLayer)
  if layer.init:
    layer.vg = VectorGraphics.new()

  layer.offset = offset
  layer.zIndex = zIndex

  gui.layerStack.add(layer)
  gui.activeLayers.add(layer)

  gui.beginLayout(rect2(vec2(0, 0), vec2(500, 500)), scroll)

proc beginLayer*(gui: Gui, str: string, offset, scroll = vec2(0, 0), zIndex = 0) =
  gui.beginLayer(gui.getId(str), offset, scroll, zIndex)

proc endLayer*(gui: Gui) =
  gui.endLayout()
  assert(gui.currentLayer.layoutStack.len == 0)
  discard gui.layerStack.pop()

proc new*(_: typedesc[Gui]): Gui =
  result = Gui()
  result.vgCtx = VectorGraphicsContext.new()
  result.defaultItemSize = vec2(50, 50)
  result.itemSpacing = vec2(10, 20)

proc beginFrame*(gui: Gui, time: float) =
  gui.vgCtx.beginFrame(gui.size, gui.scale)

  gui.previousTime = gui.time
  gui.time = time
  gui.cursorStyle = Arrow

  gui.beginLayer("MainLayer", vec2(0, 0))

proc endFrame*(gui: Gui) =
  gui.endLayer()

  assert(gui.idStack.len == 0)
  assert(gui.layerStack.len == 0)

  gui.activeLayers.sort do (x, y: GuiLayer) -> int:
    cmp(x.zIndex, y.zIndex)

  gui.layerEngaged = 0
  gui.hoverLayer = 0

  for layer in gui.activeLayers:
    gui.vgCtx.renderVectorGraphics(layer.vg, layer.offset)

    if layer.controlEngaged:
      gui.layerEngaged = layer.id

    if layer.controlHovered:
      gui.hoverLayer = layer.id

    if layer.finalMouseOver != 0:
      gui.finalMouseOver = layer.finalMouseOver

    layer.controlHovered = false
    layer.controlEngaged = false
    layer.finalMouseOver = 0

  let highestZIndex = gui.activeLayers[gui.activeLayers.len - 1].zIndex
  if highestZIndex > gui.highestZIndex:
    gui.highestZIndex = highestZIndex

  gui.activeLayers.setLen(0)

  gui.mousePresses.setLen(0)
  gui.mouseReleases.setLen(0)
  gui.keyPresses.setLen(0)
  gui.keyReleases.setLen(0)
  gui.textInput.setLen(0)
  gui.mouseWheel = vec2(0, 0)
  gui.previousGlobalMousePosition = gui.globalMousePosition

  gui.vgCtx.endFrame()

proc updateControl*(gui: Gui, id: GuiId, mouseOver: bool) =
  let layer = gui.currentLayer

  let mousePressed = gui.mousePressed(Left) or gui.mousePressed(Middle) or gui.mousePressed(Right)
  let mouseReleased = gui.mouseReleased(Left) or gui.mouseReleased(Middle) or gui.mouseReleased(Right)

  if mouseOver:
    layer.finalMouseOver = id

  # Set hover.
  if gui.mouseCapture == 0 and mouseOver and gui.finalMouseOver == id:
    gui.hover = id
  else:
    gui.hover = 0

  # Set focus.
  if gui.hover == id:
    gui.focus = id

  if mousePressed and not mouseOver and gui.focus == id:
    gui.focus = 0

  # Set mouse capture.
  if mousePressed and gui.hover == id:
    gui.mouseCapture = id
    layer.controlEngaged = true

  if mouseReleased:
    gui.mouseCapture = 0

  if gui.mouseCapture == id:
    gui.hover = id
    gui.focus = id

  if gui.hover == id:
    layer.controlHovered = true