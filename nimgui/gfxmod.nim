{.experimental: "overloadableEnums".}

import opengl
import std/unicode
import ./text; export text
import ./nanovg
import ./math; export math

proc gladLoadGL(): int {.cdecl, importc.}
var gladIsInitialized {.threadvar.}: bool

type
  Paint* = NVGpaint

  Winding* = enum
    CounterClockwise
    Clockwise

  PathWinding* = enum
    CounterClockwise
    Clockwise
    Solid
    Hole

  LineCap* = enum
    Butt
    Round
    Square

  LineJoin* = enum
    Round
    Bevel
    Miter

  Gfx* = ref object
    nvgContext*: NVGcontext

proc `=destroy`*(gfx: var type Gfx()[]) =
  nvgDeleteGL3(gfx.nvgContext)

proc newGfx*(): Gfx =
  if not gladIsInitialized:
    if gladLoadGL() <= 0:
      quit "Failed to initialise glad."
    gladIsInitialized = true
  result = Gfx(
    nvgContext: nvgCreateGL3(NVG_ANTIALIAS or NVG_STENCIL_STROKES),
  )

template pixelAlign*(gfx: Gfx, value: float): float =
  let pixelDensity = gfx.pixelDensity
  (value * pixelDensity).round / pixelDensity

template pixelAlign*(gfx: Gfx, position: Vec2): Vec2 =
  vec2(
    position.x.pixelAlign(gfx),
    position.y.pixelAlign(gfx),
  )

{.push inline.}

proc toNVGEnum(winding: Winding): cint =
  case winding:
  of CounterClockwise: NVG_CCW
  of Clockwise: NVG_CW

proc toNVGEnum(winding: PathWinding): cint =
  case winding:
  of CounterClockwise: NVG_CCW
  of Clockwise: NVG_CW
  of Solid: NVG_SOLID
  of Hole: NVG_HOLE

proc toNVGEnum(cap: LineCap): cint =
  case cap:
  of Butt: NVG_BUTT
  of Round: NVG_ROUND
  of Square: NVG_SQUARE

proc toNVGEnum(join: LineJoin): cint =
  case join:
  of Round: NVG_ROUND
  of Bevel: NVG_BEVEL
  of Miter: NVG_MITER

proc toNvgColor(color: Color): NVGcolor =
  nvgRGBAf(color.r, color.g, color.b, color.a)

proc beginFrame*(gfx: Gfx, sizePixels: Vec2, pixelDensity: float) =
  nvgBeginFrame(gfx.nvgContext, sizePixels.x / pixelDensity, sizePixels.y / pixelDensity, pixelDensity)
  nvgResetScissor(gfx.nvgContext)

proc endFrame*(gfx: Gfx, sizePixels: Vec2) =
  glEnable(GL_BLEND)
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
  glEnable(GL_STENCIL_TEST)
  glEnable(GL_SCISSOR_TEST)
  glViewport(0.GLint, 0.GLint, sizePixels.x.GLsizei, sizePixels.y.GLsizei)
  glScissor(0.GLint, 0.GLint, sizePixels.x.GLsizei, sizePixels.y.GLsizei)
  glClear(GL_STENCIL_BUFFER_BIT)
  nvgEndFrame(gfx.nvgContext)

proc beginPath*(gfx: Gfx) =
  nvgBeginPath(gfx.nvgContext)

proc moveTo*(gfx: Gfx, p: Vec2) =
  nvgMoveTo(gfx.nvgContext, p.x, p.y)

proc lineTo*(gfx: Gfx, p: Vec2) =
  nvgLineTo(gfx.nvgContext, p.x, p.y)

proc bezierTo*(gfx: Gfx, c0, c1, p: Vec2) =
  nvgBezierTo(gfx.nvgContext, c0.x, c0.y, c1.x, c1.y, p.x, p.y)

proc quadTo*(gfx: Gfx, c, p: Vec2) =
  nvgQuadTo(gfx.nvgContext, c.x, c.y, p.x, p.y)

proc arcTo*(gfx: Gfx, p0, p1: Vec2, radius: float) =
  nvgArcTo(gfx.nvgContext, p0.x, p0.y, p1.x, p1.y, radius)

proc closePath*(gfx: Gfx) =
  nvgClosePath(gfx.nvgContext)

proc `pathWinding=`*(gfx: Gfx, winding: PathWinding) =
  nvgPathWinding(gfx.nvgContext, winding.toNVGEnum)

proc arc*(gfx: Gfx, p: Vec2, r, a0, a1: float, winding: Winding) =
  nvgArc(gfx.nvgContext, p.x, p.y, r, a0, a1, winding.toNVGEnum)

proc rect*(gfx: Gfx, position, size: Vec2) =
  nvgRect(gfx.nvgContext, position.x, position.y, size.x, size.y)

proc roundedRect*(gfx: Gfx, position, size: Vec2, radius: float) =
  nvgRoundedRect(gfx.nvgContext, position.x, position.y, size.x, size.y, radius)

proc roundedRect*(gfx: Gfx, position, size: Vec2, radTopLeft, radTopRight, radBottomRight, radBottomLeft: float) =
  nvgRoundedRectVarying(gfx.nvgContext,
                        position.x, position.y, size.x, size.y,
                        radTopLeft, radTopRight, radBottomRight, radBottomLeft)

proc ellipse*(gfx: Gfx, c, r: Vec2) =
  nvgEllipse(gfx.nvgContext, c.x, c.y, r.x, r.y)

proc circle*(gfx: Gfx, c: Vec2, r: float) =
  nvgCircle(gfx.nvgContext, c.x, c.y, r)

proc fill*(gfx: Gfx) =
  nvgFill(gfx.nvgContext)

proc stroke*(gfx: Gfx) =
  nvgStroke(gfx.nvgContext)

proc saveState*(gfx: Gfx) =
  nvgSave(gfx.nvgContext)

proc restoreState*(gfx: Gfx) =
  nvgRestore(gfx.nvgContext)

proc reset*(gfx: Gfx) =
  nvgReset(gfx.nvgContext)

proc `shapeAntiAlias=`*(gfx: Gfx, enabled: bool) =
  nvgShapeAntiAlias(gfx.nvgContext, enabled.cint)

proc `strokeColor=`*(gfx: Gfx, color: Color) =
  nvgStrokeColor(gfx.nvgContext, color.toNvgColor)

proc `strokePaint=`*(gfx: Gfx, paint: Paint) =
  nvgStrokePaint(gfx.nvgContext, paint)

proc `fillColor=`*(gfx: Gfx, color: Color) =
  nvgFillColor(gfx.nvgContext, color.toNvgColor)

proc `fillPaint=`*(gfx: Gfx, paint: Paint) =
  nvgFillPaint(gfx.nvgContext, paint)

proc `miterLimit=`*(gfx: Gfx, limit: float) =
  nvgMiterLimit(gfx.nvgContext, limit)

proc `strokeWidth=`*(gfx: Gfx, width: float) =
  nvgStrokeWidth(gfx.nvgContext, width)

proc `lineCap=`*(gfx: Gfx, cap: LineCap) =
  nvgLineCap(gfx.nvgContext, cap.toNVGEnum)

proc `lineJoin=`*(gfx: Gfx, join: LineJoin) =
  nvgLineJoin(gfx.nvgContext, join.toNVGEnum)

proc `globalAlpha=`*(gfx: Gfx, alpha: float) =
  nvgGlobalAlpha(gfx.nvgContext, alpha)

proc clip*(gfx: Gfx, position, size: Vec2, intersect = true) =
  if intersect:
    nvgIntersectScissor(gfx.nvgContext, position.x, position.y, size.x, size.y)
  else:
    nvgScissor(gfx.nvgContext, position.x, position.y, size.x, size.y)

proc resetClip*(gfx: Gfx) =
  nvgResetScissor(gfx.nvgContext)

proc addFont*(gfx: Gfx, name, data: string) =
  let font = nvgCreateFontMem(gfx.nvgContext, name.cstring, data.cstring, data.len.cint, 0)
  if font == -1:
    echo "Failed to load font: " & name

proc `font=`*(gfx: Gfx, name: string) =
  nvgFontFace(gfx.nvgContext, name.cstring)

proc `fontSize=`*(gfx: Gfx, size: float) =
  nvgFontSize(gfx.nvgContext, size)

proc `letterSpacing=`*(gfx: Gfx, spacing: float) =
  nvgTextLetterSpacing(gfx.nvgContext, spacing)

proc linearGradient*(gfx: Gfx, startPosition, endPosition: Vec2, startColor, endColor: Color): Paint =
  nvgLinearGradient(gfx.nvgContext, startPosition.x, startPosition.y, endPosition.x, endPosition.y, startColor.toNvgColor, endColor.toNvgColor)

proc boxGradient*(gfx: Gfx, position, size: Vec2, cornerRadius, feather: float, innerColor, outerColor: Color): Paint =
  nvgBoxGradient(gfx.nvgContext, position.x, position.y, size.x, size.y, cornerRadius, feather, innerColor.toNvgColor, outerColor.toNvgColor)

proc radialGradient*(gfx: Gfx, center: Vec2, innerRadius, outerRadius: float, innerColor, outerColor: Color): Paint =
  nvgRadialGradient(gfx.nvgContext, center.x, center.y, innerRadius, outerRadius, innerColor.toNvgColor, outerColor.toNvgColor)

proc translate*(gfx: Gfx, amount: Vec2) =
  nvgTranslate(gfx.nvgContext, amount.x, amount.y)

{.pop.}

proc newText*(gfx: Gfx, data: string): Text =
  if data.len == 0:
    return nil

  let runes = data.toRunes
  result = Text(
    data: data,
    glyphs: newSeq[Glyph](runes.len),
    lines: @[(startIndex: 0, endIndex: runes.len - 1)]
  )

  var ascender, descender, lineHeight: cfloat
  nvgTextMetrics(gfx.nvgContext, ascender.addr, descender.addr, lineHeight.addr)
  result.ascender = ascender
  result.descender = descender
  result.lineHeight = lineHeight

  var positions = newSeq[NVGglyphPosition](runes.len)
  discard nvgTextGlyphPositions(gfx.nvgContext, 0, 0, data, nil, positions[0].addr, runes.len.cint)

  let lastGlyphStart = cast[cstring](data[data.len - runes[^1].size].unsafeAddr)
  let lastGlyphEnd = cast[cstring](cast[uint](data[0].unsafeAddr) + data.len.uint)
  var lastGlyphBounds: array[4, cfloat]
  discard nvgTextBounds(gfx.nvgContext, 0, 0, lastGlyphStart, lastGlyphEnd, lastGlyphBounds[0].addr)
  result.glyphs[^1].width = lastGlyphBounds[2] - lastGlyphBounds[0]

  var byteIndex = 0
  for i in 0 ..< runes.len:
    let rune = runes[i]
    result.glyphs[i].rune = rune
    result.glyphs[i].byteIndex = byteIndex
    if i + 1 < runes.len:
      result.glyphs[i].width = positions[i + 1].x - positions[i].x
    byteIndex += rune.size

proc drawText*(gfx: Gfx,
               text: Text,
               position, size: Vec2,
               alignX = TextAlignX.Left,
               alignY = TextAlignY.Top,
               wordWrap = false,
               clip = true) =
  if text == nil:
    return

  proc drawLine(text: Text, line: TextLine, lineBounds: Rect2) =
    let startGlyph = text.glyphs[line.startIndex]
    let endGlyph = text.glyphs[line.endIndex]
    let lineStartAddr = cast[uint](text.data[startGlyph.byteIndex].unsafeAddr)
    let lineByteLen = (endGlyph.byteIndex + endGlyph.rune.size) - startGlyph.byteIndex
    let lineEndAddr = lineStartAddr + lineByteLen.uint
    # gfx.saveState()
    # gfx.beginPath()
    # gfx.roundedRect lineBounds, 2
    # gfx.fillColor = rgb(0, 120, 0)
    # gfx.fill()
    # gfx.restoreState()
    discard nvgText(gfx.nvgContext, lineBounds.x, lineBounds.y + text.ascender, cast[cstring](lineStartAddr), cast[cstring](lineEndAddr))

  if clip:
    gfx.saveState()
    gfx.clip(position, size)

  text.drawLines(position, size, alignX, alignY, wordWrap, clip, drawLine)

  if clip:
    gfx.restoreState()