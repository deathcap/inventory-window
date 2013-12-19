# vim: set shiftwidth=2 tabstop=2 softtabstop=2 expandtab:

EventEmitter = (require 'events').EventEmitter
ever = require 'ever'

module.exports =
class InventoryWindow extends EventEmitter
  constructor: (opts) ->
    opts ?= {}
    @inventory = opts.inventory ? throw 'inventory-window requires "inventory" option set to Inventory instance'
    @getTexture = opts.getTexture ? throw 'inventory-window requires "getTexture" option set to callback'
    @width = opts.width ? 5
    @textureSize = opts.textureSize ? (16 * 5)
    @borderSize = opts.borderSize ? 4
    @secondaryMouseButton = opts.secondaryMouseButton ? 2

    @slotNodes = []
    @heldNode = undefined
    @heldItemPile = undefined

    @enable()

  enable: () ->
    ever(document).on 'mousemove', (ev) =>
      return if not @heldNode

      @positionAtMouse @heldNode, ev

  createContainer: () ->
    container = document.createElement 'div'
    #container.setAttribute 'class', 'inventory-window'  # .inventory-window { border: 1px dotted black; display: inline; float: left; }
    for i in [0...@inventory.size()]
      slotItem = @inventory.slot(i)

      node = @createSlotNode(slotItem)
      @bindSlotNodeEvent node, i

      @slotNodes.push node
      container.appendChild node

    widthpx = @width * (@textureSize + @borderSize * 2)
    container.setAttribute 'style', "
border: #{@borderSize}px solid black;
display: block;
float: left;
width: #{widthpx}px;
user-select: none;
-moz-user-select: none;
-webkit-user-select: none;
"

    container

  bindSlotNodeEvent: (node, index) ->
    ever(node).on 'mousedown', (ev) =>
      @clickSlot index, ev

  createSlotNode: (itemPile) ->
    div = document.createElement 'div'
    div.setAttribute 'style', "
border: #{@borderSize}px solid black;
display: block;
float: inherit;
margin: 0;
padding: 0;
width: #{@textureSize}px;
height: #{@textureSize}px;
font-size: 20pt;
background-size: 100% auto;
image-rendering: -moz-crisp-edges;
image-rendering: -o-crisp-edges;
image-rendering: -webkit-optimize-contrast;
image-rendering: crisp-edges;
-ms-interpolation-mode: nearest-neighbor;
"
    textNode = document.createTextNode('')
    div.appendChild textNode

    # set image and text
    @populateSlotNode div, itemPile

    div

  populateSlotNode: (div, itemPile) ->
    if itemPile? and itemPile.count > 0
      src = @getTexture itemPile
      #text = @getTextOverlay @inventory.slot
      text = itemPile.count
      text = '' if text == 1
      text = '\u221e' if text == Infinity
    else
      src = undefined
      text = ''

    div.style.backgroundImage = if src? then 'url(' + src + ')' else ''
    div.textContent = text

  refreshSlotNode: (index) ->
    @populateSlotNode @slotNodes[index], @inventory.array[index]

  positionAtMouse: (node, mouseEvent) ->
    x = mouseEvent.x ? mouseEvent.clientX
    y = mouseEvent.y ? mouseEvent.clientY

    x -= @textureSize / 2
    y -= @textureSize / 2

    node.style.left = x + 'px'
    node.style.top = y + 'px'

  createHeldNode: (itemPile, ev) ->
    @removeHeldNode() if @heldNode
    if !itemPile or itemPile.count == 0
      @heldItemPile = undefined
      return

    @heldItemPile = itemPile
    @heldNode = @createSlotNode(@heldItemPile)
    @heldNode.setAttribute 'style', style = @heldNode.getAttribute('style') + "
position: absolute;
user-select: none;
-moz-user-select: none;
-webkit-user-select: none;
pointer-events: none;
"

    @positionAtMouse @heldNode, ev

    document.body.appendChild @heldNode

  removeHeldNode: () ->
    @heldNode.parentNode.removeChild(@heldNode)
    @heldNode = undefined
    @heldItemPile = undefined

  clickSlot: (index, ev) ->
    itemPile = @inventory.slot(index)
    console.log 'clickSlot',index,itemPile

    if ev.button != @secondaryMouseButton
      # left click drop: drop whole pile
      if not @heldItemPile
        # pickup whole pile
        @heldItemPile = @inventory.array[index]
        @inventory.array[index] = undefined
      else
        if @inventory.array[index]
          # try to merge piles dropped on each other
          if @inventory.array[index].mergePile(@heldItemPile) == false
            # cannot pile together; swap dropped/held
            tmp = @heldItemPile
            @heldItemPile = @inventory.array[index]
            @inventory.array[index] = tmp
        else
          # fill entire slot
          @inventory.array[index] = @heldItemPile 
          @heldItemPile = undefined
    else
      # right-click: half/one
      if not @heldItemPile
        @heldItemPile = @inventory.array[index]?.splitPile(0.5)
      else
        if @inventory.array[index]
          oneHeld = @heldItemPile.splitPile(1)
          if @inventory.array[index].mergePile(oneHeld) == false
            @heldItemPile.increase(1)
            tmp = @heldItemPile
            @heldItemPile = @inventory.array[index]
            @inventory.array[index] = tmp
        else
          @inventory.array[index] = @heldItemPile.splitPile(1)
    @createHeldNode @heldItemPile, ev
    @refreshSlotNode index

