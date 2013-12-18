# vim: set shiftwidth=2 tabstop=2 softtabstop=2 expandtab:

EventEmitter = (require 'events').EventEmitter

module.exports =
class InventoryWindow extends EventEmitter
  constructor: (opts) ->
    @inventory = opts.inventory || throw 'inventory-window requires "inventory" option set to Inventory instance'
    @getTexture = opts.getTexture || throw 'inventory-window requires "getTexture" option set to callback'

  createContainer: () ->
    container = document.createElement 'div'
    container.setAttribute 'class', 'inventory-window'  # .inventory-window { border: 1px dotted black; display: inline; float: left; }
    for i in [0...@inventory.size]
      src = @getTexture @inventory.slot(i)

      container.appendChild @createSlotNode src

    container

  createSlotNode: (src) ->
    img = document.createElement 'img'
    img.setAttribute 'src',  src
    img.setAttribute 'class', 'inventory-slot'  # .inventory-slot { border: 1px solid black; display: inline; float: inherit; }
    img
