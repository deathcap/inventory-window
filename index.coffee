# vim: set shiftwidth=2 tabstop=2 softtabstop=2 expandtab:

EventEmitter = (require 'events').EventEmitter
ever = require 'ever'

module.exports =
class InventoryWindow extends EventEmitter
  @heldItemPile = undefined
  @heldNode = undefined
  @mouseButtonDown = undefined
  @resolvedImageURLs = {}

  @defaultGetTexture = (itemPile) -> return "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAEJGlDQ1BJQ0MgUHJvZmlsZQAAOBGFVd9v21QUPolvUqQWPyBYR4eKxa9VU1u5GxqtxgZJk6XtShal6dgqJOQ6N4mpGwfb6baqT3uBNwb8AUDZAw9IPCENBmJ72fbAtElThyqqSUh76MQPISbtBVXhu3ZiJ1PEXPX6yznfOec7517bRD1fabWaGVWIlquunc8klZOnFpSeTYrSs9RLA9Sr6U4tkcvNEi7BFffO6+EdigjL7ZHu/k72I796i9zRiSJPwG4VHX0Z+AxRzNRrtksUvwf7+Gm3BtzzHPDTNgQCqwKXfZwSeNHHJz1OIT8JjtAq6xWtCLwGPLzYZi+3YV8DGMiT4VVuG7oiZpGzrZJhcs/hL49xtzH/Dy6bdfTsXYNY+5yluWO4D4neK/ZUvok/17X0HPBLsF+vuUlhfwX4j/rSfAJ4H1H0qZJ9dN7nR19frRTeBt4Fe9FwpwtN+2p1MXscGLHR9SXrmMgjONd1ZxKzpBeA71b4tNhj6JGoyFNp4GHgwUp9qplfmnFW5oTdy7NamcwCI49kv6fN5IAHgD+0rbyoBc3SOjczohbyS1drbq6pQdqumllRC/0ymTtej8gpbbuVwpQfyw66dqEZyxZKxtHpJn+tZnpnEdrYBbueF9qQn93S7HQGGHnYP7w6L+YGHNtd1FJitqPAR+hERCNOFi1i1alKO6RQnjKUxL1GNjwlMsiEhcPLYTEiT9ISbN15OY/jx4SMshe9LaJRpTvHr3C/ybFYP1PZAfwfYrPsMBtnE6SwN9ib7AhLwTrBDgUKcm06FSrTfSj187xPdVQWOk5Q8vxAfSiIUc7Z7xr6zY/+hpqwSyv0I0/QMTRb7RMgBxNodTfSPqdraz/sDjzKBrv4zu2+a2t0/HHzjd2Lbcc2sG7GtsL42K+xLfxtUgI7YHqKlqHK8HbCCXgjHT1cAdMlDetv4FnQ2lLasaOl6vmB0CMmwT/IPszSueHQqv6i/qluqF+oF9TfO2qEGTumJH0qfSv9KH0nfS/9TIp0Wboi/SRdlb6RLgU5u++9nyXYe69fYRPdil1o1WufNSdTTsp75BfllPy8/LI8G7AUuV8ek6fkvfDsCfbNDP0dvRh0CrNqTbV7LfEEGDQPJQadBtfGVMWEq3QWWdufk6ZSNsjG2PQjp3ZcnOWWing6noonSInvi0/Ex+IzAreevPhe+CawpgP1/pMTMDo64G0sTCXIM+KdOnFWRfQKdJvQzV1+Bt8OokmrdtY2yhVX2a+qrykJfMq4Ml3VR4cVzTQVz+UoNne4vcKLoyS+gyKO6EHe+75Fdt0Mbe5bRIf/wjvrVmhbqBN97RD1vxrahvBOfOYzoosH9bq94uejSOQGkVM6sN/7HelL4t10t9F4gPdVzydEOx83Gv+uNxo7XyL/FtFl8z9ZAHF4bBsrEwAAALtJREFUOBF1kVEShSAMA31ehLNzNE7ynMVZJ1Tsh22TNGD59d7/rbVjjHF8xY4XOxnKYQjCTJ08PSE2DW7o/kqYQdMsa7hpIGiGyNAM3hqefvmFSqYJdfL2Zz3VPsVi1XDeQKEi+xRXLLXPDVKkIE0SS+2ZjQNiuyEx8/IKGkhqBF4xueUVFEpqSN5hmD47UPwllPcmmr52kALrNLWWe+1AgSd4stlBdcsOJKvYnuwgNfplB5Ia1Z4hIvkLST+EXyFGzfgAAAAASUVORK5CYII="

  constructor: (opts) ->
    opts ?= {}
    @inventory = opts.inventory ? throw 'inventory-window requires "inventory" option set to Inventory instance'
    @getTexture = opts.getTexture ? InventoryWindow.defaultGetTexture
    @inventorySize = opts.inventorySize ? @inventory.size()
    @width = opts.width ? @inventory.width
    @textureSize = opts.textureSize ? (16 * 5)
    @borderSize = opts.borderSize ? 4
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
    if itemPile? and itemPile.count > 0
      src = @getTexture itemPile
      #text = @getTextOverlay @inventory.slot
      text = itemPile.count
      text = '' if text == 1
      text = '\u221e' if text == Infinity
    else
      src = undefined
      text = ''

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
          InventoryWindow.heldItemPile = @inventory.get(index)
          @inventory.set(index, undefined)
        @emit 'pickup' # TODO: event data? index, item? cancelable?
      else
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

