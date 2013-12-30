# vim: set shiftwidth=2 tabstop=2 softtabstop=2 expandtab:

EventEmitter = (require 'events').EventEmitter
ever = require 'ever'

module.exports =
class InventoryWindow extends EventEmitter
  @heldItemPile = undefined
  @heldNode = undefined
  @mouseButtonDown = undefined
  @resolvedImageURLs = {}

  constructor: (opts) ->
    opts ?= {}
    @inventory = opts.inventory ? throw 'inventory-window requires "inventory" option set to Inventory instance'
    @linkedInventory = opts.linkedInventory
    @getTexture = opts.getTexture ? InventoryWindow.defaultGetTexture
    @registry = opts.registry
    if (!@getTexture? && !@registry?)
      throw 'inventory-window: required "getTexture" or "registry" option missing'
    @getMaxDamage = opts.getMaxDamage ? InventoryWindow.defaultGetMaxDamage
    @inventorySize = opts.inventorySize ? @inventory.size()
    @width = opts.width ? @inventory.width
    @textureSize = opts.textureSize ? (16 * 5)
    @borderSize = opts.borderSize ? 4
    @progressThickness = opts.progressThickness ? 10
    @secondaryMouseButton = opts.secondaryMouseButton ? 2
    @allowDrop = opts.allowDrop ? true
    @allowPickup = opts.allowPickup ? true
    @allowDragPaint = opts.allowDragPaint ? true

    @slotNodes = []
    @container = undefined
    @selectedIndex = undefined # no selection

    @enable()

  enable: () ->
    ever(document).on 'mousemove', (ev) =>
      return if not InventoryWindow.heldNode
      @positionAtMouse InventoryWindow.heldNode, ev

    ever(document).on 'mouseup', (ev) =>
      InventoryWindow.mouseButtonDown = undefined

    @inventory.on 'changed', () =>
      @refresh()

  createContainer: () ->
    container = document.createElement 'div'
    #container.setAttribute 'class', 'inventory-window'  # .inventory-window { border: 1px dotted black; display: inline; float: left; }
    for i in [0...@inventorySize]
      slotItem = @inventory.get(i)

      node = @createSlotNode(slotItem)
      @setBorderStyle node, i
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

    @container = container

  bindSlotNodeEvent: (node, index) ->
    ever(node).on 'mousedown', (ev) =>
      @clickSlot index, ev
    ever(node).on 'mouseover', (ev) =>
      return if not @allowDragPaint
      return if not @allowDrop
      return if not InventoryWindow.heldItemPile?
      return if InventoryWindow.mouseButtonDown != @secondaryMouseButton

      # 'drag paint' mode, distributing items as mouseover without clicking
      @dropOneHeld(index)
      @createHeldNode InventoryWindow.heldItemPile, ev
      @refreshSlotNode index

      # TODO: support left-click drag paint = evenly redistribute 
      #  (vs right-click = drop only one item)

  createSlotNode: (itemPile) ->
    div = document.createElement 'div'
    div.setAttribute 'style', "
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

  populateSlotNode: (div, itemPile, isSelected) ->
    src = undefined
    text = ''
    progress = undefined
    progressColor = 'green'

    if itemPile? and itemPile.count > 0
      if @registry?
        src = @registry.getItemPileTexture itemPile
      else if @getTexture?
        src = @getTexture itemPile
      else
        throw 'inventory-window textures not specified, set InventoryWindow.defaultGetTexture or pass "getTexture" or "registry" option'

      #text = @getTextOverlay @inventory.slot
      text = itemPile.count
      text = '' if text == 1
      text = '\u221e' if text == Infinity

      if itemPile.tags?.damage?
        if @registry?
          maxDamage = @registry.getItemProps(itemPile.item).maxDamage
        else if @getMaxDamage?
          maxDamage = @getMaxDamage(itemPile)
        else
          maxDamage = 100

        progress = (maxDamage - itemPile.tags.damage) / maxDamage
        if progress <= 0.20
          progressColor = 'red'
        else if progress <= 0.40
          progressColor = 'orange' 
        else
          progressColor = 'green'

    newImage = if src? then 'url(' + src + ')' else ''

    # update image, but only if changed to prevent flickering
    if InventoryWindow.resolvedImageURLs[newImage] != div.style.backgroundImage
      div.style.backgroundImage = newImage
      # wrinkle: if the URL may not be fully resolved (relative path, ../, etc.),
      # but setting backgroundImage resolves it, so it won't always match what we
      # set it to -- to fix this, cache the result for comparison next time
      InventoryWindow.resolvedImageURLs[newImage] = div.style.backgroundImage
   
    if div.textContent != text
      div.textContent = text

    progressNode = div.children[0]
    if not progressNode?
      progressNode = document.createElement('div')
      progressNode.setAttribute 'style', "
width: #{progress * 100}%;
border-top: #{@progressThickness}px solid #{progressColor};
top: #{@textureSize - @borderSize * 2}px;
position: relative;
visibility: hidden;
"
      div.appendChild progressNode

    progressNode.style.visibility = if progress? then '' else 'hidden'


  setBorderStyle: (node, index) ->
    if index == @selectedIndex
      node.style.border = "#{@borderSize}px dotted black"
    else
      node.style.border = "#{@borderSize}px solid black"
 
  setSelected: (index) ->
    @selectedIndex = index
    @refresh()   # TODO: selective refresh?

  getSelected: (index) ->
    @selectedIndex

  refreshSlotNode: (index) ->
    @populateSlotNode @slotNodes[index], @inventory.get(index)
    @setBorderStyle @slotNodes[index], index 

  refresh: () ->
    for i in [0...@inventorySize]
      @refreshSlotNode(i)

  positionAtMouse: (node, mouseEvent) ->
    x = mouseEvent.x ? mouseEvent.clientX
    y = mouseEvent.y ? mouseEvent.clientY

    x -= @textureSize / 2
    y -= @textureSize / 2

    node.style.left = x + 'px'
    node.style.top = y + 'px'

  createHeldNode: (itemPile, ev) ->
    @removeHeldNode() if InventoryWindow.heldNode
    if !itemPile or itemPile.count == 0
      InventoryWindow.heldItemPile = undefined
      return

    InventoryWindow.heldItemPile = itemPile
    InventoryWindow.heldNode = @createSlotNode(InventoryWindow.heldItemPile)
    InventoryWindow.heldNode.setAttribute 'style', style = InventoryWindow.heldNode.getAttribute('style') + "
position: absolute;
user-select: none;
-moz-user-select: none;
-webkit-user-select: none;
pointer-events: none;
z-index: 10;
"

    @positionAtMouse InventoryWindow.heldNode, ev

    document.body.appendChild InventoryWindow.heldNode

  removeHeldNode: () ->
    InventoryWindow.heldNode.parentNode.removeChild(InventoryWindow.heldNode)
    InventoryWindow.heldNode = undefined
    InventoryWindow.heldItemPile = undefined

  dropOneHeld: (index) ->
    if @inventory.get(index)
      # drop one, but try to merge with existing
      oneHeld = InventoryWindow.heldItemPile.splitPile(1)
      if @inventory.get(index).mergePile(oneHeld) == false
        # could not merge, so swap 
        InventoryWindow.heldItemPile.increase(1)
        tmp = InventoryWindow.heldItemPile
        InventoryWindow.heldItemPile = @inventory.get(index)
        @inventory.set(index, tmp)
      else
        @inventory.changed()
    else
      # drop on empty slot
      @inventory.set(index, InventoryWindow.heldItemPile.splitPile(1))

  clickSlot: (index, ev) ->
    itemPile = @inventory.get(index)
    console.log 'clickSlot',index,itemPile

    InventoryWindow.mouseButtonDown = ev.button

    shiftDown = ev.shiftKey

    if ev.button != @secondaryMouseButton
      # left click: whole pile
      if not InventoryWindow.heldItemPile or not @allowDrop
        # pickup whole pile
        return if not @allowPickup

        if InventoryWindow.heldItemPile?
          # tried to drop on pickup-only inventory, so merge into held inventory instead
          if @inventory.get(index)?
            return if not InventoryWindow.heldItemPile.canPileWith @inventory.get(index)
            InventoryWindow.heldItemPile.mergePile @inventory.get(index)
        else
          if not shiftDown
            # simply picking up the whole pile
            InventoryWindow.heldItemPile = @inventory.get(index)
            @inventory.set(index, undefined)
          else if @linkedInventory and @inventory.get(index)?
            # shift-click: transfer to linked inventory
            @linkedInventory.give @inventory.get(index)
            @inventory.changed()  # update source, might not have transferred all of the pile

        @emit 'pickup' # TODO: event data? index, item? cancelable?
      else
        # drop whole pile
        if @inventory.get(index)
          # try to merge piles dropped on each other
          if @inventory.get(index).mergePile(InventoryWindow.heldItemPile) == false
            # cannot pile together; swap dropped/held
            tmp = InventoryWindow.heldItemPile
            InventoryWindow.heldItemPile = @inventory.get(index)
            @inventory.set(index, tmp)
          else
            @inventory.changed()
        else
          # fill entire slot
          @inventory.set(index, InventoryWindow.heldItemPile)
          InventoryWindow.heldItemPile = undefined
    else
      # right-click: half/one
      if not InventoryWindow.heldItemPile
        # pickup half
        return if not @allowPickup
        InventoryWindow.heldItemPile = @inventory.get(index)?.splitPile(0.5)
        @inventory.changed()
        @emit 'pickup' # TODO: event data? index, item? cancelable?
      else
        return if not @allowDrop
        @dropOneHeld(index)
    @createHeldNode InventoryWindow.heldItemPile, ev
    @refreshSlotNode index

