{.experimental: "overloadableEnums".}

import std/math
import std/algorithm
import ./vectorgraphics; export vectorgraphics
import opengl

type
  Region* = object
    position*: Vec2
    size*: Vec2

proc region*(position, size: Vec2): Region =
  result.position = position
  result.size = size

proc expand*(region: Region, amount: Vec2): Region =
  result.position = vec2(
    min(region.position.x + region.size.x * 0.5, region.position.x - amount.x),
    min(region.position.y + region.size.y * 0.5, region.position.y - amount.y),
  )
  result.size = vec2(
    max(0, region.size.x + amount.x * 2),
    max(0, region.size.y + amount.y * 2),
  )

proc intersect*(a, b: Region): Region =
  let x1 = max(a.position.x, b.position.x)
  let y1 = max(a.position.y, b.position.y)
  var x2 = min(a.position.x + a.size.x, b.position.x + b.size.x)
  var y2 = min(a.position.y + a.size.y, b.position.y + b.size.y)
  if x2 < x1: x2 = x1
  if y2 < y1: y2 = y1
  Region(position: vec2(x1, y1), size: vec2(x2 - x1, y2 - y1))

proc contains*(a: Region, b: Vec2): bool =
  b.x >= a.position.x and b.x <= a.position.x + a.size.x and
  b.y >= a.position.y and b.y <= a.position.y + a.size.y

type
  CursorStyle* = enum
    Arrow
    IBeam
    Crosshair
    PointingHand
    ResizeLeftRight
    ResizeTopBottom
    ResizeTopLeftBottomRight
    ResizeTopRightBottomLeft

  MouseButton* = enum
    Unknown,
    Left, Middle, Right,
    Extra1, Extra2, Extra3,
    Extra4, Extra5,

  KeyboardKey* = enum
    Unknown,
    A, B, C, D, E, F, G, H, I,
    J, K, L, M, N, O, P, Q, R,
    S, T, U, V, W, X, Y, Z,
    Key1, Key2, Key3, Key4, Key5,
    Key6, Key7, Key8, Key9, Key0,
    Pad1, Pad2, Pad3, Pad4, Pad5,
    Pad6, Pad7, Pad8, Pad9, Pad0,
    F1, F2, F3, F4, F5, F6, F7,
    F8, F9, F10, F11, F12,
    Backtick, Minus, Equal, Backspace,
    Tab, CapsLock, Enter, LeftShift,
    RightShift, LeftControl, RightControl,
    LeftAlt, RightAlt, LeftMeta, RightMeta,
    LeftBracket, RightBracket, Space,
    Escape, Backslash, Semicolon, Quote,
    Comma, Period, Slash, ScrollLock,
    Pause, Insert, End, PageUp, Delete,
    Home, PageDown, LeftArrow, RightArrow,
    DownArrow, UpArrow, NumLock, PadDivide,
    PadMultiply, PadSubtract, PadAdd, PadEnter,
    PadPeriod, PrintScreen,

  Layer = object
    zIndex: int
    drawCommands: seq[DrawCommand]
    finalHoverRequest: pointer

  InteractionTracker* = object
    detectedHover*: bool
    detectedMouseOver*: bool

  Gui* = ref object
    backgroundColor*: Color
    cursorStyle*: CursorStyle
    highestZIndex*: int
    backendData*: pointer
    onFrame*: proc(gui: Gui)

    # Input
    time*: float
    contentScale*: float
    size*: Vec2
    globalMousePosition*: Vec2
    mouseWheelState*: Vec2
    mousePresses*: seq[MouseButton]
    mouseReleases*: seq[MouseButton]
    mouseDownStates*: array[MouseButton, bool]
    keyPresses*: seq[KeyboardKey]
    keyReleases*: seq[KeyboardKey]
    keyDownStates*: array[KeyboardKey, bool]
    textInput*: string
    currentlyIsHovered: bool

    # Hover
    hover*: pointer
    mouseOver*: pointer
    hoverCapture*: pointer

    # Stacks
    offsetStack: seq[Vec2]
    clipRegionStack: seq[Region]
    layerStack: seq[Layer]
    interactionTrackerStack: seq[InteractionTracker]

    # Layer
    layers: seq[Layer]

    # Vector graphics
    vgCtx: VectorGraphicsContext

    # Previous frame state
    previousTime: float
    previousGlobalMousePosition: Vec2

proc inputTime*(gui: Gui, time: float) =
  gui.time = time

proc inputContentScale*(gui: Gui, scale: float) =
  gui.contentScale = scale

proc inputSize*(gui: Gui, x, y: float) =
  gui.size = vec2(x, y)

proc inputMouseMove*(gui: Gui, x, y: float) =
  gui.globalMousePosition = vec2(x, y)

proc inputMouseEnter*(gui: Gui) =
  gui.currentlyIsHovered = true

proc inputMouseExit*(gui: Gui) =
  gui.currentlyIsHovered = false

proc inputMouseWheel*(gui: Gui, x, y: float) =
  gui.mouseWheelState = vec2(x, y)

proc inputMousePress*(gui: Gui, button: MouseButton) =
  gui.mouseDownStates[button] = true
  gui.mousePresses.add(button)

proc inputMouseRelease*(gui: Gui, button: MouseButton) =
  gui.mouseDownStates[button] = false
  gui.mouseReleases.add(button)

proc inputKeyPress*(gui: Gui, key: KeyboardKey) =
  gui.keyDownStates[key] = true
  gui.keyPresses.add(key)

proc inputKeyRelease*(gui: Gui, key: KeyboardKey) =
  gui.keyDownStates[key] = false
  gui.keyReleases.add(key)

proc inputText*(gui: Gui, text: string) =
  gui.textInput &= text

proc isHovered*(gui: Gui): bool = gui.currentlyIsHovered
proc mouseDelta*(gui: Gui): Vec2 = gui.globalMousePosition - gui.previousGlobalMousePosition
proc deltaTime*(gui: Gui): float = gui.time - gui.previousTime
proc mouseDown*(gui: Gui, button: MouseButton): bool = gui.mouseDownStates[button]
proc keyDown*(gui: Gui, key: KeyboardKey): bool = gui.keyDownStates[key]
proc mouseWheel*(gui: Gui): Vec2 = gui.mouseWheelState
proc mouseMoved*(gui: Gui): bool = gui.mouseDelta != vec2(0, 0)
proc mouseWheelMoved*(gui: Gui): bool = gui.mouseWheelState != vec2(0, 0)
proc mousePressed*(gui: Gui, button: MouseButton): bool = button in gui.mousePresses
proc mouseReleased*(gui: Gui, button: MouseButton): bool = button in gui.mouseReleases
proc anyMousePressed*(gui: Gui): bool = gui.mousePresses.len > 0
proc anyMouseReleased*(gui: Gui): bool = gui.mouseReleases.len > 0
proc keyPressed*(gui: Gui, key: KeyboardKey): bool = key in gui.keyPresses
proc keyReleased*(gui: Gui, key: KeyboardKey): bool = key in gui.keyReleases
proc anyKeyPressed*(gui: Gui): bool = gui.keyPresses.len > 0
proc anyKeyReleased*(gui: Gui): bool = gui.keyReleases.len > 0

proc currentLayer(gui: Gui): var Layer =
  gui.layerStack[^1]

proc newWidget*(gui: Gui, T: typedesc[ref]): T =
  result = T()
  result.gui = gui
  when compiles(result.init()):
    result.init()

proc toWidgetPtr(widget: ref): pointer =
  cast[pointer](widget)

proc isHovered*(gui: Gui, widget: ref): bool =
  gui.hover == widget.toWidgetPtr

proc mouseIsOver*(gui: Gui, widget: ref): bool =
  gui.mouseOver == widget.toWidgetPtr

proc requestHover*(gui: Gui, widget: ref) =
  let widgetPtr = widget.toWidgetPtr
  gui.currentLayer.finalHoverRequest = widgetPtr

  if gui.hover == widgetPtr:
    gui.interactionTrackerStack[^1].detectedHover = true

  if gui.mouseOver == widgetPtr:
    gui.interactionTrackerStack[^1].detectedMouseOver = true

proc captureHover*(gui: Gui, widget: ref) =
  if gui.hoverCapture == nil:
    gui.hoverCapture = widget.toWidgetPtr

proc releaseHover*(gui: Gui, widget: ref) =
  if gui.hoverCapture == widget.toWidgetPtr:
    gui.hoverCapture = nil

proc zIndex*(gui: Gui): int =
  gui.currentLayer.zIndex

proc offset*(gui: Gui): Vec2 =
  gui.offsetStack[^1]

proc clipRegion*(gui: Gui, global = false): Region =
  result = gui.clipRegionStack[^1]
  if not global:
    result.position -= gui.offset

proc interactionTracker*(gui: Gui): InteractionTracker =
  gui.interactionTrackerStack[^1]

proc mousePosition*(gui: Gui): Vec2 =
  gui.globalMousePosition - gui.offset

proc beginInteractionTracker*(gui: Gui) =
  gui.interactionTrackerStack.add(InteractionTracker())

proc endInteractionTracker*(gui: Gui): InteractionTracker {.discardable.} =
  result = gui.interactionTrackerStack.pop()
  if result.detectedHover:
    gui.interactionTrackerStack[^1].detectedHover = true
  if result.detectedMouseOver:
    gui.interactionTrackerStack[^1].detectedMouseOver = true

proc beginOffset*(gui: Gui, offset: Vec2, global = false) =
  if global:
    gui.offsetStack.add(offset)
  else:
    gui.offsetStack.add(gui.offset + offset)

proc endOffset*(gui: Gui): Vec2 {.discardable.} =
  gui.offsetStack.pop()

proc beginClipRegion*(gui: Gui, region: Region, global = false, intersect = true) =
  var region = region

  if not global:
    region.position += gui.offset

  if intersect:
    region = region.intersect(gui.clipRegionStack[^1])

  gui.clipRegionStack.add(region)

  gui.currentLayer.drawCommands.add(DrawCommand(kind: Clip, clip: ClipCommand(
    position: region.position,
    size: region.size,
  )))

proc endClipRegion*(gui: Gui): Region {.discardable.} =
  result = gui.clipRegionStack.pop()

  if gui.clipRegionStack.len == 0:
    return

  let clipRect = gui.clipRegionStack[^1]
  gui.currentLayer.drawCommands.add(DrawCommand(kind: Clip, clip: ClipCommand(
    position: clipRect.position,
    size: clipRect.size,
  )))

proc beginZIndex*(gui: Gui, zIndex: int, global = false) =
  if global:
    gui.layerStack.add(Layer(zIndex: zIndex))
  else:
    gui.layerStack.add(Layer(zIndex: gui.zIndex + zIndex))

proc endZIndex*(gui: Gui): int {.discardable.} =
  let layer = gui.layerStack.pop()
  gui.layers.add(layer)
  layer.zIndex

proc mouseHitTest*(gui: Gui, position, size: Vec2): bool =
  let m = gui.mousePosition
  m.x >= position.x and m.x <= position.x + size.x and
  m.y >= position.y and m.y <= position.y + size.y and
  gui.clipRegion.contains(gui.mousePosition)

proc setupVectorGraphics*(gui: Gui) =
  gui.vgCtx = VectorGraphicsContext.new()

proc new*(_: typedesc[Gui]): Gui =
  Gui(contentScale: 1.0)

proc beginFrame*(gui: Gui) =
  glViewport(0, 0, GLsizei(gui.size.x), GLsizei(gui.size.y))
  gui.vgCtx.beginFrame(gui.size, gui.contentScale)
  gui.cursorStyle = Arrow

  gui.beginZIndex(0, global = true)
  gui.beginOffset(vec2(0, 0), global = true)
  gui.beginClipRegion(region(vec2(0, 0), gui.size), global = true, intersect = false)
  gui.interactionTrackerStack.add(InteractionTracker())

proc endFrame*(gui: Gui) =
  discard gui.interactionTrackerStack.pop()
  gui.endClipRegion()
  gui.endOffset()
  gui.endZIndex()

  assert(gui.offsetStack.len == 0)
  assert(gui.layerStack.len == 0)
  assert(gui.clipRegionStack.len == 0)
  assert(gui.interactionTrackerStack.len == 0)

  # The layers are in reverse order because they were added in popZIndex.
  # Sort preserves the order of layers with the same z index, so they
  # must first be reversed and then sorted to keep that ordering in tact.
  gui.layers.reverse()
  gui.layers.sort(proc(x, y: Layer): int =
    cmp(x.zIndex, y.zIndex)
  )

  gui.hover = nil
  gui.mouseOver = nil
  gui.highestZIndex = low(int)

  for layer in gui.layers:
    if layer.zIndex > gui.highestZIndex:
      gui.highestZIndex = layer.zIndex

    gui.vgCtx.renderDrawCommands(layer.drawCommands)
    let hoverRequest = layer.finalHoverRequest
    if hoverRequest != nil:
      gui.hover = hoverRequest
      gui.mouseOver = hoverRequest

  if gui.hoverCapture != nil:
    gui.hover = gui.hoverCapture

  gui.layers.setLen(0)
  gui.mousePresses.setLen(0)
  gui.mouseReleases.setLen(0)
  gui.keyPresses.setLen(0)
  gui.keyReleases.setLen(0)
  gui.textInput.setLen(0)
  gui.mouseWheelState = vec2(0, 0)
  gui.previousGlobalMousePosition = gui.globalMousePosition
  gui.previousTime = gui.time

  gui.vgCtx.endFrame()


# ======================================================================
# Vector graphics
# ======================================================================


proc clear*(gui: Gui) =
  let bg = gui.backgroundColor
  glClearColor(bg.r, bg.g, bg.b, 1.0)
  glClear(GL_COLOR_BUFFER_BIT)

proc pixelAlign*(gui: Gui, value: float): float =
  let contentScale = gui.contentScale
  round(value * contentScale) / contentScale

proc pixelAlign*(gui: Gui, position: Vec2): Vec2 =
  vec2(gui.pixelAlign(position.x), gui.pixelAlign(position.y))

proc fillPath*(gui: Gui, path: Path, paint: Paint) =
  gui.currentLayer.drawCommands.add(DrawCommand(kind: FillPath, fillPath: FillPathCommand(
    path: path[],
    paint: paint,
    position: gui.pixelAlign(gui.offset),
  )))

proc fillPath*(gui: Gui, path: Path, color: Color) =
  gui.fillPath(path, solidColorPaint(color))

proc strokePath*(gui: Gui, path: Path, paint: Paint, strokeWidth = 1.0) =
  gui.currentLayer.drawCommands.add(DrawCommand(kind: StrokePath, strokePath: StrokePathCommand(
    path: path[],
    paint: paint,
    strokeWidth: strokeWidth,
    position: gui.pixelAlign(gui.offset),
  )))

proc strokePath*(gui: Gui, path: Path, color: Color, strokeWidth = 1.0) =
  gui.strokePath(path, solidColorPaint(color), strokeWidth)

proc addFont*(gui: Gui, data: string): Font {.discardable.} =
  gui.vgCtx.addFont(data)

proc measureGlyphs*(gui: Gui, text: openArray[char], font: Font, fontSize: float): seq[Glyph] =
  gui.vgCtx.measureGlyphs(text, font, fontSize)

proc textMetrics*(gui: Gui, font: Font, fontSize: float): TextMetrics =
  gui.vgCtx.textMetrics(font, fontSize)

proc fillTextLine*(gui: Gui,
  text: string,
  position: Vec2,
  color = rgb(255, 255, 255),
  font = Font(0),
  fontSize = 13.0,
) =
  gui.currentLayer.drawCommands.add(DrawCommand(kind: FillText, fillText: FillTextCommand(
    font: font,
    fontSize: fontSize,
    position: gui.pixelAlign(gui.offset + position),
    text: text,
    color: color,
  )))