{.experimental: "overloadableEnums".}

import ../gui

type
  GuiText* = ref object of GuiNode
    data*: string
    glyphs*: seq[Glyph]
    font*: string
    fontSize*: float
    lineHeight*: float
    ascender*: float
    descender*: float
    textAlignment*: TextAlignment
    color*: Color

proc drawPosition*(text: GuiText): Vec2 =
  result.x = case text.textAlignment.x:
    of Left: 0.0
    of Center: 0.5 * text.size.x
    of Right: text.size.y
  result.y = case text.textAlignment.y:
    of Top: 0.0
    of Center: 0.5 * text.size.y
    of Bottom: text.size.y
    of Baseline: text.lineHeight

proc update*(text: GuiText) =
  let vg = text.vg
  vg.font = text.font
  vg.fontSize = text.fontSize

  let metrics = vg.textMetrics
  text.lineHeight = metrics.lineHeight
  text.ascender = metrics.ascender
  text.descender = metrics.descender

  vg.textAlignment = text.textAlignment

  text.glyphs = vg.getGlyphs(vec2(0, 0), text.data)

proc defaultDraw*(text: GuiText) =
  let vg = text.vg
  vg.fillColor = text.color
  vg.textAlignment = text.textAlignment
  vg.font = text.font
  vg.fontSize = text.fontSize
  vg.text(text.drawPosition, text.data)

proc addText*(node: GuiNode, id: string): GuiText {.discardable.} =
  let text = node.addNode(id, GuiText)
  text.update()

  text.draw:
    text.defaultDraw()

  if text.init:
    text.passInput = true
    text.font = "consola"
    text.fontSize = 13
    text.textAlignment = textAlignment(Center, Center)
    text.color = rgb(242, 243, 245)

  text