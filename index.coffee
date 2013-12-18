# vim: set shiftwidth=2 tabstop=2 softtabstop=2 expandtab:

EventEmitter = (require 'events').EventEmitter

module.exports =
class InventoryWindow extends EventEmitter
  constructor: (opts) ->
    opts ?= {}
    @inventory = opts.inventory ? throw 'inventory-window requires "inventory" option set to Inventory instance'
    @getTexture = opts.getTexture ? throw 'inventory-window requires "getTexture" option set to callback'
    @width = opts.width ? 5
    @textureSize = opts.textureSize ? 16
    @borderSize = opts.borderSize ? 1

  createContainer: () ->
    container = document.createElement 'div'
    #container.setAttribute 'class', 'inventory-window'  # .inventory-window { border: 1px dotted black; display: inline; float: left; }
    for i in [0...@inventory.size()]
      src = @getTexture @inventory.slot(i)
      #text = @getTextOverlay @inventory.slot
      text = @inventory.slot(i)?.count
      text = undefined if text == 1
      text = '\u221e' if text == Infinity

      container.appendChild @createSlotNode(src, text)
    widthpx = @width * (@textureSize + @borderSize * 2)
    container.setAttribute 'style', "
border: 1px solid black;
display: inline;
float: left;
width: #{widthpx}px;
font-size: 5pt;
transform: scale(5,5);
-webkit-transform: scale(5,5);
-moz-transform: scale(5,5);
-ms-transform: scale(5,5);
-o-transform: scale(5,5);
"

    container

  createSlotNode: (src, text) ->
    div = document.createElement 'div'
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

    div
