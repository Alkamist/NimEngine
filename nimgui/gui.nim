{.experimental: "codeReordering".}
{.experimental: "overloadableEnums".}

import std/tables
import std/times
# import std/algorithm
import ./math; export math
import oswindow; export oswindow
import vectorgraphics; export vectorgraphics

type
  Widget* = ref object of RootObj
    gui* {.cursor.}: Gui
    parent* {.cursor.}: Widget
    children*: Table[string, Widget]
    id*: string
    iteration*: int
    zIndex*: int
    init*: bool
    isHovered*: bool
    position*: Vec2
    size*: Vec2
    updateProc*: proc(widget: Widget)
    drawProc*: proc(widget: Widget)

  Gui* = ref object of Widget
    osWindow*: OsWindow
    vg*: VectorGraphics
    widgetStack*: seq[Widget]
    contentScale*: float
    time*: float
    timePrevious*: float
    mouseCapture*: Widget
    globalMousePosition*: Vec2
    globalMousePositionPrevious*: Vec2
    mouseWheel*: Vec2
    mousePresses*: seq[MouseButton]
    mouseReleases*: seq[MouseButton]
    mouseDownStates*: array[MouseButton, bool]
    keyPresses*: seq[KeyboardKey]
    keyReleases*: seq[KeyboardKey]
    keyDownStates*: array[KeyboardKey, bool]
    textInput*: string
    parentGlobalPosition*: Vec2

# =================================================================================
# Widget
# =================================================================================

template x*(widget: Widget): untyped = widget.position.x
template `x=`*(widget: Widget, value: untyped): untyped = widget.position.x = value
template y*(widget: Widget): untyped = widget.position.y
template `y=`*(widget: Widget, value: untyped): untyped = widget.position.y = value
template width*(widget: Widget): untyped = widget.size.x
template `width=`*(widget: Widget, value: untyped): untyped = widget.size.x = value
template height*(widget: Widget): untyped = widget.size.y
template `height=`*(widget: Widget, value: untyped): untyped = widget.size.y = value

template update*(widget: Widget, code: untyped): untyped =
  widget.updateProc = proc(widgetBase: Widget) =
    {.hint[ConvFromXtoItselfNotNeeded]: off.}
    {.hint[XDeclaredButNotUsed]: off.}
    let self {.inject.} = typeof(widget)(widgetBase)
    let `widget` {.inject.} = self
    let gui {.inject.} = self.gui
    code

template draw*(widget: Widget, code: untyped): untyped =
  widget.drawProc = proc(widgetBase: Widget) =
    {.hint[ConvFromXtoItselfNotNeeded]: off.}
    {.hint[XDeclaredButNotUsed]: off.}
    let self {.inject.} = typeof(widget)(widgetBase)
    let `widget` {.inject.} = self
    let gui {.inject.} = self.gui
    let vg {.inject.} = gui.vg
    code

proc globalPosition*(widget: Widget): Vec2 =
  widget.position + widget.gui.parentGlobalPosition

# =================================================================================
# Gui
# =================================================================================

proc mousePosition*(gui: Gui): Vec2 = gui.globalMousePosition - gui.parentGlobalPosition
proc mouseDelta*(gui: Gui): Vec2 = gui.globalMousePosition - gui.globalMousePositionPrevious
proc deltaTime*(gui: Gui): float = gui.time - gui.timePrevious
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

proc currentWidget*(gui: Gui): Widget =
  gui.widgetStack[gui.widgetStack.len - 1]

proc beginWidget*(gui: Gui, id: string, T: typedesc): T =
  let parent = gui.currentWidget
  if parent.children.hasKey(id):
    result = T(parent.children[id])
    result.init = false
  else:
    result = T()
    result.init = true
    result.gui = gui
    result.parent = parent
    parent.children[id] = result

  gui.parentGlobalPosition += parent.position
  gui.widgetStack.add(result)

proc endWidget*(gui: Gui) =
  gui.widgetStack.setLen(gui.widgetStack.len - 1)

proc updateWidgetHover*(gui: Gui, widget: Widget) =
  widget.isHovered = widget.parent.isHovered and rect2(widget.globalPosition, widget.size).contains(gui.globalMousePosition)

proc new*(_: typedesc[Gui]): Gui =
  result = Gui()

  result.time = cpuTime()
  result.timePrevious = result.time

  result.id = "gui"
  result.gui = result
  result.isHovered = true

  # result.hovers = newSeqOfCap[Widget](16)
  result.mousePresses = newSeqOfCap[MouseButton](16)
  result.mouseReleases = newSeqOfCap[MouseButton](16)
  result.keyPresses = newSeqOfCap[KeyboardKey](16)
  result.keyReleases = newSeqOfCap[KeyboardKey](16)
  result.textInput = newStringOfCap(16)

  result.osWindow = OsWindow.new()
  result.osWindow.setBackgroundColor(49 / 255, 51 / 255, 56 / 255)
  result.osWindow.setSize(800, 600)
  result.osWindow.show()

  result.vg = VectorGraphics.new()

  result.attachToOsWindow()

proc processFrame*(gui: Gui) =
  gui.time = cpuTime()

  gui.widgetStack = @[Widget(gui)]

  let (pixelWidth, pixelHeight) = gui.osWindow.size
  gui.vg.beginFrame(pixelWidth, pixelHeight, gui.contentScale)
  if gui.updateProc != nil:
    gui.updateProc(gui)
  gui.vg.endFrame()

  gui.mousePresses.setLen(0)
  gui.mouseReleases.setLen(0)
  gui.keyPresses.setLen(0)
  gui.keyReleases.setLen(0)
  gui.textInput.setLen(0)
  gui.mouseWheel = vec2(0, 0)
  gui.globalMousePositionPrevious = gui.globalMousePosition
  gui.timePrevious = gui.time

template run*(gui: Gui, code: untyped): untyped =
  gui.updateProc = proc(base: Widget) =
    {.hint[ConvFromXtoItselfNotNeeded]: off.}
    {.hint[XDeclaredButNotUsed]: off.}
    let gui {.inject.} = Gui(base)
    let vg {.inject.} = gui.vg
    code

  gui.osWindow.run()

const densityPixelDpi = 96.0

proc toContentScale(dpi: float): float =
  dpi / densityPixelDpi

proc toDensityPixels(pixels: int, dpi: float): float =
  float(pixels) * dpi / densityPixelDpi

proc attachToOsWindow(gui: Gui) =
  let window = gui.osWindow
  window.userData = cast[pointer](gui)

  let dpi = window.dpi
  gui.contentScale = dpi.toContentScale

  let (width, height) = window.size
  gui.width = width.toDensityPixels(dpi)
  gui.height = height.toDensityPixels(dpi)

  window.onFrame = proc(window: OsWindow) =
    let gui = cast[Gui](window.userData)
    gui.processFrame()
    window.swapBuffers()

  window.onResize = proc(window: OsWindow, width, height: int) =
    let gui = cast[Gui](window.userData)
    let dpi = window.dpi
    gui.width = width.toDensityPixels(dpi)
    gui.height = height.toDensityPixels(dpi)

  window.onMouseMove = proc(window: OsWindow, x, y: int) =
    let gui = cast[Gui](window.userData)
    let dpi = window.dpi
    gui.globalMousePosition.x = x.toDensityPixels(dpi)
    gui.globalMousePosition.y = y.toDensityPixels(dpi)

  window.onMousePress = proc(window: OsWindow, button: MouseButton, x, y: int) =
    let gui = cast[Gui](window.userData)
    let dpi = window.dpi
    gui.mouseDownStates[button] = true
    gui.mousePresses.add(button)
    gui.globalMousePosition.x = x.toDensityPixels(dpi)
    gui.globalMousePosition.y = y.toDensityPixels(dpi)

  window.onMouseRelease = proc(window: OsWindow, button: oswindow.MouseButton, x, y: int) =
    let gui = cast[Gui](window.userData)
    let dpi = window.dpi
    gui.mouseDownStates[button] = false
    gui.mouseReleases.add(button)
    gui.globalMousePosition.x = x.toDensityPixels(dpi)
    gui.globalMousePosition.y = y.toDensityPixels(dpi)

  window.onMouseWheel = proc(window: OsWindow, x, y: float) =
    let gui = cast[Gui](window.userData)
    gui.mouseWheel.x = x
    gui.mouseWheel.y = y

  window.onKeyPress = proc(window: OsWindow, key: KeyboardKey) =
    let gui = cast[Gui](window.userData)
    gui.keyDownStates[key] = true
    gui.keyPresses.add(key)

  window.onKeyRelease = proc(window: OsWindow, key: oswindow.KeyboardKey) =
    let gui = cast[Gui](window.userData)
    gui.keyDownStates[key] = false
    gui.keyReleases.add(key)

  window.onTextInput = proc(window: OsWindow, text: string) =
    let gui = cast[Gui](window.userData)
    gui.textInput &= text

  window.onDpiChange = proc(window: OsWindow, dpi: float) =
    let gui = cast[Gui](window.userData)
    gui.contentScale = dpi.toContentScale


# =================================================================================
# Helper macros
# =================================================================================


import std/macros; export macros

# template bindCallback*(T: typedesc, callbackName, procName: untyped): untyped =
#   template `callbackName`*(widget: T, code: untyped): untyped =
#     widget.`procName` = proc(`widget` {.inject.}: T): bool =
#       {.hint[XDeclaredButNotUsed]: off.}
#       let self {.inject.} = `widget`
#       let gui {.inject.} = self.gui
#       let vg {.inject.} = gui.vg
#       code

template implementWidget*(T: typedesc, macroName, behaviorCode: untyped): untyped {.dirty.} =
  template implementation(gui, widgetName, iterationIndex, idString, initCode: untyped): untyped =
    let `widgetName` {.inject.} = gui.beginWidget(idString, T)
    block:
      let self {.inject.} = `widgetName`
      if self.init:
        self.id = idString
        self.iteration = iterationIndex
        initCode

      gui.updateWidgetHover(self)

      behaviorCode

      if self.updateProc != nil:
        self.updateProc(self)

      vg.saveState()
      vg.translate(self.position)
      if self.drawProc != nil:
        self.drawProc(self)
      vg.restoreState()

      gui.endWidget()

  macro `macroName`*(gui: Gui, widgetIdent, initCode: untyped): untyped =
    case widgetIdent.kind:

    of nnkIdent:
      let widgetAsString = widgetIdent.strVal
      let id = quote do:
        `widgetAsString`
      result = getAst(implementation(gui, widgetIdent, 0, id, initCode))

    of nnkBracketExpr:
      let widgetAsString = widgetIdent[0].strVal
      let iteration = widgetIdent[1]
      let id = quote do:
        `widgetAsString` & "Iteration" & $`iteration`
      result = getAst(implementation(gui, widgetIdent[0], iteration, id, initCode))

    else:
      error("Widget identifiers must be in the form name, or name[i].")