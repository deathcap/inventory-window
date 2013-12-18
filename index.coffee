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
    @emptySlotImage = opts.emptySlotImage ? 'data:image/gif;base64,R0lGODlhAQABAAAAACwAAAAAAQABAAA' # blank

    @slotNodes = []
    @dragNode = null

  createContainer: () ->
    container = document.createElement 'div'
    #container.setAttribute 'class', 'inventory-window'  # .inventory-window { border: 1px dotted black; display: inline; float: left; }
    for i in [0...@inventory.size()]
      slotItem = @inventory.slot(i)

      if slotItem?
        src = @getTexture slotItem
        #text = @getTextOverlay @inventory.slot
        text = slotItem.count
        text = undefined if text == 1
        text = '\u221e' if text == Infinity
      else
        src = @emptySlotImage
        text = undefined

      node = @createSlotNode(src, text, i)
      @slotNodes.push node
      container.appendChild node

    widthpx = @width * (@textureSize + @borderSize * 2)
    container.setAttribute 'style', "
border: 1px solid black;
display: block;
float: left;
width: #{widthpx}px;
font-size: 5pt;
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

  createSlotNode: (src, text, index) ->
    div = document.createElement 'div'
    div.setAttribute 'data-inventory-index', index
    div.setAttribute 'style', "
border: #{@borderSize}px solid black;
display: block;
float: inherit;
margin: 0;
padding: 0;
background-image: url(#{src});
width: #{@textureSize}px;
height: #{@textureSize}px;
"
    if text?
      textNode = document.createTextNode text
      div.appendChild textNode

    ever(div).on 'mousedown', (ev) =>
      console.log 'mousedown'
      if @dragNode
        @dropSlot index, ev
      else
        @pickUpSlot index, ev

    ever(document).on 'mousemove', (ev) =>
      return if not @dragNode

      @dragNode.style.left = ev.x + 'px'
      @dragNode.style.top = ev.y + 'px'

    div

  pickUpSlot: (index, ev) ->
    pile = @inventory.slot(index)
    console.log 'pickUpSlot',index,pile

    if not pile?
      # not picking up anything
      return

    div = @slotNodes[index]
    # clear slot
    div.style.backgroundImage = 'url(' + @emptySlotImage + ')'

    # create a new node, attached TODO: also include text
    @dragNode = document.createElement 'img'
    src = @getTexture pile
    @dragNode.setAttribute 'src', src
    @dragNode.setAttribute 'style', "
position: absolute;
left: #{ev.x}px;
top: #{ev.y}px;
user-select: none;
-moz-user-select: none;
-webkit-user-select: none;
pointer-events: none;
"
    document.body.appendChild @dragNode

  dropSlot: (index, ev) ->
    pile = @inventory.slot(index)
    console.log 'dropSlot',index,pile

    div = @slotNodes[index]

    @dragNode.parentNode.removeChild(@dragNode)
    div.style.backgroundImage = 'url(' + @dragNode.src + ')' # TODO: real item, not just image
    
    @dragNode = null

    # TODO: if not empty, pick up this slot after dropped (swap)
    #pickUpSlot div, ev, src

    return


