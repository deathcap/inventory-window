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
    @textureSize = opts.textureSize ? 16
    @borderSize = opts.borderSize ? 1
    @leftMouseButton = opts.leftMouseButton ? 0
    @rightMouseButton = opts.rightMouseButton ? 2

    @slotNodes = []
    @heldNode = undefined
    @heldItemPile = undefined

    @enable()

  enable: () ->
    ever(document).on 'mousemove', (ev) =>
      return if not @heldNode

      @heldNode.style.left = ev.x + 'px'
      @heldNode.style.top = ev.y + 'px'

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
border: 1px solid black;
display: block;
float: left;
width: #{widthpx}px;
user-select: none;
-moz-user-select: none;
-webkit-user-select: none;

transform: scale(5,5) translate(80px, 80px);
-webkit-transform: scale(5,5) translate(80px, 80px);
-moz-transform: scale(5,5) translate(80px, 80px);
-ms-transform: scale(5,5) translate(80px, 80px);
-o-transform: scale(5,5) translate(80px, 80px);
"

    container

  bindSlotNodeEvent: (node, index) ->
    ever(node).on 'mousedown', (ev) =>
      console.log 'mousedown'
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
font-size: 5pt;
"
    textNode = document.createTextNode()
    div.appendChild textNode

    # set image and text
    @populateSlotNode div, itemPile

    div

  populateSlotNode: (div, itemPile) ->
    if itemPile?
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

  pickUpSlot: (index, ev) ->
    itemPile = @inventory.slot(index)
    console.log 'pickUpSlot',index,itemPile

    if not itemPile?
      # not picking up anything
      return

    # clear slot
    @populateSlotNode @slotNodes[index], undefined

    # create a new node, attached to cursor
    @createHeldNode(index, ev.x, ev.y)

  createHeldNode: (index, initialX, initialY) ->
    @removeHeldNode() if @heldNode
    
    @heldItemPile = @inventory.array[index]
    return if not @heldItemPile

    console.log 'createHeldNode itempile=',@heldItemPile
    @heldNode = @createSlotNode(@heldItemPile)
    @heldNode.setAttribute 'style', @heldNode.getAttribute('style') + "
position: absolute;
left: #{initialX}px;
top: #{initialY}px;
user-select: none;
-moz-user-select: none;
-webkit-user-select: none;
pointer-events: none;

-webkit-transform: scale(5,5); /* TODO: stop scaling hack */
"
    document.body.appendChild @heldNode

  removeHeldNode: () ->
    @heldNode.parentNode.removeChild(@heldNode)
    @heldNode = undefined
    @heldItemPile = undefined

  clickSlot: (index, ev) ->
    itemPile = @inventory.slot(index)
    console.log 'clickSlot',index,itemPile

    # TODO: if ev.button == @rightMouseButton # right click drop: drop one item

    # left click drop: drop whole pile
    dropPile = @heldItemPile
    @createHeldNode index, ev.x, ev.y   # pickup clicked pile, if any
    @inventory.array[index] = dropPile
    @refreshSlotNode index

