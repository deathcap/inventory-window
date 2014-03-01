
EventEmitter = (require 'events').EventEmitter
ever = require 'ever'
ftooltip = require 'ftooltip'
CubeIcon = require 'cube-icon'
touchup = require 'touchup'

module.exports =
class InventoryWindow extends EventEmitter
  # moved to global.InventoryWindow_ instead of class variable, since this module
  # might be included multiple times, creating multiple class variables, but we
  # want them to be shared across _all_ instances, so you can drop between any
  # inventory-window.
  #@heldItemPile = undefined
  #@heldNode = undefined
  #@mouseButtonDown = undefined
  #@resolvedImageURLs = {}

  constructor: (opts) ->
    opts ?= {}
    @inventory = opts.inventory ? throw 'inventory-window requires "inventory" option set to Inventory instance'
    @linkedInventory = opts.linkedInventory
    @getTexture = opts.getTexture ? InventoryWindow.defaultGetTexture ? global.InventoryWindow_defaultGetTexture
    @registry = opts.registry
    if (!@getTexture? && !@registry?)
      throw 'inventory-window: required "getTexture" or "registry" option missing'
    @getMaxDamage = opts.getMaxDamage ? InventoryWindow.defaultGetMaxDamage ? global.InventoryWindow_defaultGetMaxDamage
    @inventorySize = opts.inventorySize ? @inventory.size()
    @width = opts.width ? @inventory.width
    @textureScale = opts.textureScale ? 5
    @textureScaleAlgorithm = 'nearest-neighbor'
    @textureSrcPx = opts.textureSrcPx ? 16
    @textureSize = opts.textureSize ? (@textureSrcPx * @textureScale)
    @getTooltip = opts.getTooltip ? InventoryWindow.defaultGetTooltip ? global.InventoryWindow_defaultGetTooltip
    @tooltips = opts.tooltips ? true
    @borderSize = opts.borderSize ? 4
    @progressThickness = opts.progressThickness ? 10
    @secondaryMouseButton = opts.secondaryMouseButton ? 2
    @allowDrop = opts.allowDrop ? true
    @allowPickup = opts.allowPickup ? true
    @allowDragPaint = opts.allowDragPaint ? true
    @progressColorsThresholds = opts.progressColorsThresholds ?= [0.20, 0.40, Infinity]
    @progressColors = opts.progressColors ?= ['red', 'orange', 'green']

    @slotNodes = []
    @container = undefined
    @selectedIndex = undefined # no selection

    @enable()

  enable: () ->
    if document?
      ever(document).on 'mousemove', (ev) =>
        return if not global.InventoryWindow_heldNode
        @positionAtMouse global.InventoryWindow_heldNode, ev

      ever(document).on 'mouseup', (ev) =>
        global.InventoryWindow_mouseButtonDown = undefined

    @inventory.on 'changed', () =>
      @refresh()

  createContainer: () ->
    return if not document?

    container = document.createElement 'div'
    for i in [0...@inventorySize]
      slotItem = @inventory.get(i)

      node = @createSlotNode(slotItem)
      @setBorderStyle node, i
      @bindSlotNodeEvent node, i

      @slotNodes.push node
      container.appendChild node

    widthpx = @width * (@textureSize + @borderSize * 2) + 2 * @borderSize
    container.setAttribute 'style', "
display: block;
float: left;
width: #{widthpx}px;
-moz-user-select: none;
-webkit-user-select: none;
-ms-user-select: none;
"

    @container = container

  bindSlotNodeEvent: (node, index) ->
    ever(node).on 'mousedown', (ev) =>
      @clickSlot index, ev
    ever(node).on 'mouseover', (ev) =>
      return if not @allowDragPaint
      return if not @allowDrop
      return if not global.InventoryWindow_heldItemPile?
      return if global.InventoryWindow_mouseButtonDown != @secondaryMouseButton

      # 'drag paint' mode, distributing items as mouseover without clicking
      @dropOneHeld(index)
      @createHeldNode global.InventoryWindow_heldItemPile, ev
      @refreshSlotNode index

      # TODO: support left-click drag paint = evenly redistribute 
      #  (vs right-click = drop only one item)

  createSlotNode: (itemPile) ->
    div = document.createElement 'div'
    div.setAttribute 'style', "
display: inline-block;
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
    # set image and text
    @populateSlotNode div, itemPile

    div

  populateSlotNode: (div, itemPile, isSelected) ->
    src = undefined
    text = ''
    progress = undefined
    progressColor = undefined

    if itemPile?
      if @registry?
        src = @registry.getItemPileTexture itemPile
      else if @getTexture?
        src = @getTexture itemPile
      else
        throw 'inventory-window textures not specified, set global.InventoryWindow_defaultGetTexture or pass "getTexture" or "registry" option'

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
        progressColor = @getProgressBarColor(progress)

    setImage = (src) ->
      if typeof src == 'string'  # simple image
        newImage = 'url(' + src + ')'
      else
        newImage = ''  # clear
        # note: might be 3d cube set below

      # update image, but only if changed to prevent flickering
      global.InventoryWindow_resolvedImageURLs ?= {}
      if global.InventoryWindow_resolvedImageURLs[newImage] != div.style.backgroundImage
        div.style.backgroundImage = newImage
        # wrinkle: if the URL may not be fully resolved (relative path, ../, etc.),
        # but setting backgroundImage resolves it, so it won't always match what we
        # set it to -- to fix this, cache the result for comparison next time
        global.InventoryWindow_resolvedImageURLs[newImage] = div.style.backgroundImage

    if @textureScaleAlgorithm? and typeof src == 'string'
      # cache scaled images
      global.InventoryWindow_cachedScaledImages ?= {}
      if global.InventoryWindow_cachedScaledImages[src]
        setImage global.InventoryWindow_cachedScaledImages[src]
      else
        # generate scaled image, requires async callback
        img = new Image()
        img.onload = () =>
          scaled = touchup.scale(img, @textureScale, @textureScale, @textureScaleAlgorithm)
          global.InventoryWindow_cachedScaledImages[src] = scaled
          setImage scaled
        img.src = src
    else
      # unscaled image
      setImage src


    # 3D cube node (for blocks)
    cubeNode = div.children[0]
    if not cubeNode?
      cubeNode = document.createElement('div')
      cubeNode.setAttribute 'style', 'position: relative; z-index: 0;'
      div.appendChild cubeNode

    cubeNode.removeChild(cubeNode.firstChild) while cubeNode.firstChild

    if Array.isArray(src)  # 3d cube
      cube = new CubeIcon(images:src)
      cubeNode.appendChild cube.container

    # textual count
    textBox = div.children[1]
    if not textBox?
      textBox = document.createElement('div')
      textBox.setAttribute 'style', 'position: absolute;'
      div.appendChild textBox

    if textBox.textContent != text
      textBox.textContent = text

    # progress bar
    progressNode = div.children[2]
    if not progressNode?
      progressNode = document.createElement('div')
      progressNode.setAttribute 'style', "
width: 0%;
top: #{@textureSize - @borderSize * 2}px;
position: relative;
visibility: hidden;
"
      div.appendChild progressNode

    progressNode.style.borderTop = "#{@progressThickness}px solid #{progressColor}" if progressColor?
    progressNode.style.width = (progress * 100) + '%' if progress?
    progressNode.style.visibility = if progress? then '' else 'hidden'

    # tooltip text
    if itemPile? and @tooltips
      if @registry?
        tooltip = @registry.getItemDisplayName itemPile.item
      else if @getTooltip?
        tooltip = @getTooltip?

      if tooltip
        ftooltip div, tooltip

  getProgressBarColor: (progress) ->
    for threshold, i in @progressColorsThresholds
      if progress <= threshold
        return @progressColors[i]
    return @progressColors.slice(-1)[0]  # default to last

  setBorderStyle: (node, index) ->
    x = index %% @width
    y = index // @width
    height = @inventorySize / @width
    if index == @selectedIndex
      kind = 'dotted'
    else
      kind = 'solid'

    node.style.border = "#{@borderSize}px #{kind} black"
    node.style.borderTop = "#{@borderSize * 2}px #{kind} black" if y == 0
    node.style.borderBottom = "#{@borderSize * 2}px #{kind} black" if y == height - 1
    node.style.borderLeft = "#{@borderSize * 2}px #{kind} black" if x == 0
    node.style.borderRight = "#{@borderSize * 2}px #{kind} black" if x == @width - 1
 
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
    @removeHeldNode() if global.InventoryWindow_heldNode
    if !itemPile or itemPile.count == 0
      global.InventoryWindow_heldItemPile = undefined
      return

    global.InventoryWindow_heldItemPile = itemPile
    global.InventoryWindow_heldNode = @createSlotNode(global.InventoryWindow_heldItemPile)
    global.InventoryWindow_heldNode.setAttribute 'style', style = global.InventoryWindow_heldNode.getAttribute('style') + "
position: absolute;
user-select: none;
-moz-user-select: none;
-webkit-user-select: none;
pointer-events: none;
z-index: 10;
"

    @positionAtMouse global.InventoryWindow_heldNode, ev

    document.body.appendChild global.InventoryWindow_heldNode

  removeHeldNode: () ->
    global.InventoryWindow_heldNode.parentNode.removeChild(global.InventoryWindow_heldNode)
    global.InventoryWindow_heldNode = undefined
    global.InventoryWindow_heldItemPile = undefined

  dropOneHeld: (index) ->
    if @inventory.get(index)
      # drop one, but try to merge with existing
      oneHeld = global.InventoryWindow_heldItemPile.splitPile(1)
      if @inventory.get(index).mergePile(oneHeld) == false
        # could not merge, so swap 
        global.InventoryWindow_heldItemPile.increase(1)
        tmp = global.InventoryWindow_heldItemPile
        global.InventoryWindow_heldItemPile = @inventory.get(index)
        @inventory.set(index, tmp)
      else
        @inventory.changed()
    else
      # drop on empty slot
      @inventory.set(index, global.InventoryWindow_heldItemPile.splitPile(1))

  clickSlot: (index, ev) ->
    itemPile = @inventory.get(index)
    console.log 'clickSlot',index,itemPile

    global.InventoryWindow_mouseButtonDown = ev.button

    shiftDown = ev.shiftKey

    if ev.button != @secondaryMouseButton
      # left click: whole pile
      if not global.InventoryWindow_heldItemPile or not @allowDrop
        # pickup whole pile
        return if not @allowPickup

        if global.InventoryWindow_heldItemPile?
          # tried to drop on pickup-only inventory, so merge into held inventory instead
          if @inventory.get(index)?
            return if not global.InventoryWindow_heldItemPile.canPileWith @inventory.get(index)
            global.InventoryWindow_heldItemPile.mergePile @inventory.get(index)
        else
          if not shiftDown
            # simply picking up the whole pile
            global.InventoryWindow_heldItemPile = @inventory.get(index)
            @inventory.set(index, undefined)
          else if @linkedInventory and @inventory.get(index)?
            # shift-click: transfer to linked inventory
            @linkedInventory.give @inventory.get(index)
            @inventory.set index, undefined if @inventory.get(index).count == 0
            @inventory.changed()  # update source, might not have transferred all of the pile

        @emit 'pickup' # TODO: event data? index, item? cancelable?
      else
        # drop whole pile
        if @inventory.get(index)
          # try to merge piles dropped on each other
          if @inventory.get(index).mergePile(global.InventoryWindow_heldItemPile) == false
            # cannot pile together; swap dropped/held
            tmp = global.InventoryWindow_heldItemPile
            global.InventoryWindow_heldItemPile = @inventory.get(index)
            @inventory.set(index, tmp)
          else
            @inventory.changed()
        else
          # fill entire slot
          @inventory.set(index, global.InventoryWindow_heldItemPile)
          global.InventoryWindow_heldItemPile = undefined
    else
      # right-click: half/one
      if not global.InventoryWindow_heldItemPile
        # pickup half
        return if not @allowPickup
        global.InventoryWindow_heldItemPile = @inventory.get(index)?.splitPile(0.5)
        @inventory.set index, undefined if @inventory.get(index)?.count == 0
        @inventory.changed()
        @emit 'pickup' # TODO: event data? index, item? cancelable?
      else
        return if not @allowDrop
        @dropOneHeld(index)
    @createHeldNode global.InventoryWindow_heldItemPile, ev
    @refreshSlotNode index

