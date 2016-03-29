'use strict';

const EventEmitter = require('events').EventEmitter;
const ever = require('ever');
const createTooltip = require('ftooltip');
const CubeIcon = require('cube-icon');
const touchup = require('touchup');

class InventoryWindow extends EventEmitter {
  // moved to global.InventoryWindow_ instead of class variable, since this module
  // might be included multiple times, creating multiple class variables, but we
  // want them to be shared across _all_ instances, so you can drop between any
  // inventory-window.
  //this.heldItemPile = undefined
  //this.heldNode = undefined
  //this.mouseButtonDown = undefined
  //this.resolvedImageURLs = {}

  constructor(opts) {
    super();
    if (!opts) opts = {};
    this.inventory = opts.inventory;
    if (!this.inventory) throw new Error('inventory-window requires "inventory" option set to Inventory instance');
    this.linkedInventory = opts.linkedInventory;
    this.getTexture = opts.getTexture;
    if (!this.getTexture) this.getTexture = InventoryWindow.defaultGetTexture;
    if (!this.getTexture) this.getTexture = global.InventoryWindow_defaultGetTexture;
    this.registry = opts.registry;
    if (!this.getTexture && !this.registry) {
      throw new Error('inventory-window: required "getTexture" or "registry" option missing');
    }
    this.getMaxDamage = opts.getMaxDamage;
    if (!this.getMaxDamage) this.getMaxDamage = InventoryWindow.defaultGetMaxDamage;
    if (!this.getMaxDamage) this.getMaxDamage = global.InventoryWindow_defaultGetMaxDamage;
    this.inventorySize = opts.inventorySize;
    if (this.inventorySize === undefined) this.inventorySize = this.inventory.size();
    this.width = opts.width;
    if (this.width === undefined) this.width = this.inventory.width;
    this.textureScale = opts.textureScale !== undefined ? opts.textureScale : 5;
    this.textureScaleAlgorithm = 'nearest-neighbor';
    this.textureSrcPx = opts.textureSrcPx !== undefined ? opts.textureSrcPx : 16;
    this.textureSize = opts.textureSize !== undefined ? opts.textureSize : (this.textureSrcPx * this.textureScale);
    this.getTooltip = opts.getTooltip;
    if (!this.getTooltip) this.getTooltip = InventoryWindow.defaultGetTooltip;
    if (!this.getTooltip) this.getTooltip = global.InventoryWindow_defaultGetTooltip;
    this.tooltips = opts.tooltips !== undefined ? opts.tooltips : true;
    this.borderSize = opts.borderSize !== undefined ? opts.borderSize : 4;
    this.progressThickness = opts.progressThickness !== undefined ? opts.progressThickness : 10;
    this.secondaryMouseButton = opts.secondaryMouseButton !== undefined ? opts.secondaryMouseButton : 2;
    this.allowDrop = opts.allowDrop !== undefined ? opts.allowDrop : true;
    this.allowPickup = opts.allowPickup !== undefined ? opts.allowPickup : true;
    this.allowDragPaint = opts.allowDragPaint !== undefined ? opts.allowDragPaint : true;
    this.progressColorsThresholds = opts.progressColorsThresholds !== undefined ? opts.progressColorsThresholds : [0.20, 0.40, Infinity];
    this.progressColors = opts.progressColors !== undefined ? opts.progressColors : ['red', 'orange', 'green'];

    this.slotNodes = [];
    this.container = undefined;
    this.selectedIndex = undefined;  //  no selection

    this.enable();
  }

  enable() {
    if (global.document) {
      ever(document).on('mousemove', (ev) => {
        if (!global.InventoryWindow_heldNode) return;
        this.positionAtMouse(global.InventoryWindow_heldNode, ev);
      });

      ever(document).on('mouseup', (ev) => {
        global.InventoryWindow_mouseButtonDown = undefined;
      });
    }

    this.inventory.on('changed', () => {
      this.refresh();
    });
  };

  createContainer() {
    if (!global.document) return;

    let container = document.createElement('div');
    for (let i = 0; i < this.inventorySize; ++i) {
      const slotItem = this.inventory.get(i)

      const node = this.createSlotNode(slotItem);
      this.setBorderStyle(node, i);
      this.bindSlotNodeEvent(node, i);

      this.slotNodes.push(node);
      container.appendChild(node);
    }

    const widthpx = this.width * (this.textureSize + this.borderSize * 2) + 2 * this.borderSize;
    container.setAttribute('style', `
display: block;
float: left;
width:  ${widthpx}px;
-moz-user-select: none;
-webkit-user-select: none;
-ms-user-select: none;
`);

    this.container = container;
    return this.container;
  }

  bindSlotNodeEvent(node, index) {
    ever(node).on('mousedown', (ev) => {
      this.clickSlot(index, ev);
    });
    ever(node).on('mouseover', (ev) => {
      if (!this.allowDragPaint) return;
      if (!this.allowDrop) return;
      if (!global.InventoryWindow_heldItemPile) return;
      if (global.InventoryWindow_mouseButtonDown !== this.secondaryMouseButton) return;

      //  'drag paint' mode, distributing items as mouseover without clicking
      this.dropOneHeld(index);
      this.createHeldNode(global.InventoryWindow_heldItemPile, ev);
      this.refreshSlotNode(index);

      //  TODO: support left-click drag paint = evenly redistribute 
      //   (vs right-click = drop only one item)
    });
  }

  createSlotNode(itemPile) {
    const div = document.createElement('div');
    div.setAttribute('style', `
display: inline-block;
float: inherit;
margin: 0;
padding: 0;
width: ${this.textureSize}px;
height: ${this.textureSize}px;
font-size: 20pt;
background-size: 100% auto;
image-rendering: -moz-crisp-edges;
image-rendering: -o-crisp-edges;
image-rendering: -webkit-optimize-contrast;
image-rendering: crisp-edges;
-ms-interpolation-mode: nearest-neighbor;
`);
    // set image and text
    this.populateSlotNode(div, itemPile);

    return div;
  }

  populateSlotNode(div, itemPile, isSelected) {
    let src = undefined;
    let text = '';
    let progress = undefined;
    let progressColor = undefined;

    if (itemPile !== undefined) {
      if (this.registry !== undefined) {
        src = this.registry.getItemPileTexture(itemPile);
      } else if (this.getTexture !== undefined) {
        src = this.getTexture(itemPile);
      } else {
        throw new Error('inventory-window textures not specified, set global.InventoryWindow_defaultGetTexture or pass "getTexture" or "registry" option');
      }

      //text = this.getTextOverlay this.inventory.slot
      text = itemPile.count;
      if (text === 1) text = '';
      if (text === Infinity) text = '\u221e';

      if (itemPile.tags !== undefined && itemPile.tags.damage !== undefined) {
        let maxDamage;
        if (this.registry !== undefined) {
          maxDamage = this.registry.getItemProps(itemPile.item).maxDamage;
        } else if (this.getMaxDamage !== undefined) {
          maxDamage = this.getMaxDamage(itemPile);
        } else {
          maxDamage = 100;
        }

        progress = (maxDamage - itemPile.tags.damage) / maxDamage;
        progressColor = this.getProgressBarColor(progress);
      }
    }

    function setImage(src) {
      let newImage;
      if (typeof src === 'string') {   //  simple image
        newImage = 'url(' + src + ')';
      } else {
        newImage = '';   //  clear
        // note: might be 3d cube set below
      }

      // update image, but only if changed to prevent flickering
      if (global.InventoryWindow_resolvedImageURLs === undefined) {
        global.InventoryWindow_resolvedImageURLs = {};
      }
      if (global.InventoryWindow_resolvedImageURLs[newImage] !== div.style.backgroundImage) {
        div.style.backgroundImage = newImage;
        // wrinkle: if the URL may not be fully resolved (relative path, ../, etc.),
        // but setting backgroundImage resolves it, so it won't always match what we
        // set it to -- to fix this, cache the result for comparison next time
        global.InventoryWindow_resolvedImageURLs[newImage] = div.style.backgroundImage;
      }
    }

    if (this.textureScaleAlgorithm !== undefined && typeof src === 'string') {
      // cache scaled images
      if (global.InventoryWindow_cachedScaledImages === undefined) {
        global.InventoryWindow_cachedScaledImages = {};
      }
      if (global.InventoryWindow_cachedScaledImages[src]) {
        setImage(global.InventoryWindow_cachedScaledImages[src]);
      } else {
        // generate scaled image, requires async callback
        let img = new Image();
        img.onload = () => {
          const scaled = touchup.scale(img, this.textureScale, this.textureScale, this.textureScaleAlgorithm);
          global.InventoryWindow_cachedScaledImages[src] = scaled;
          setImage(scaled);
        };
        img.src = src;
      }
    } else {
      // unscaled image
      setImage(src);
    }

    // 3D cube node (for blocks)
    let cubeNode = div.children[0];
    if (!cubeNode) {
      cubeNode = document.createElement('div');
      cubeNode.setAttribute('style', 'position: relative; z-index: 0;');
      div.appendChild(cubeNode);
    }

    while(cubeNode.firstChild) {
      cubeNode.removeChild(cubeNode.firstChild);
    }

    if (Array.isArray(src) || typeof(src) === 'object') {   //  3d cube
      const cube = new CubeIcon({images:src});
      cubeNode.appendChild(cube.container);
    }

    // textual count
    let textBox = div.children[1];
    if (!textBox) {
      textBox = document.createElement('div');
      textBox.setAttribute('style', 'position: absolute; text-shadow: 1px 1px #eee, -1px -1px #333;');
      div.appendChild(textBox);
    }

    if (textBox.textContent !== text) {
      textBox.textContent = text;
    }

    // progress bar
    let progressNode = div.children[2];
    if (!progressNode) {
      progressNode = document.createElement('div');
      progressNode.setAttribute('style', `
width: 0%;
top:  ${this.textureSize - this.borderSize * 2}px;
position: relative;
visibility: hidden;
`);
      div.appendChild(progressNode);
    }

    if (progressColor !== undefined) {
      progressNode.style.borderTop = ` ${this.progressThickness}px solid  ${progressColor}`;
    }
    if (progress !== undefined) {
      progressNode.style.width = (progress * 100) + '%';
    }
    progressNode.style.visibility = progress !== undefined ? '' : 'hidden';

    // tooltip
    if (this.tooltips) {
      let tooltipNode = div.children[3];
      if (!tooltipNode) {
        tooltipNode = document.createTextNode('not set');
        let tooltip = createTooltip(div, tooltipNode);
        div.appendChild(tooltip.div);
      }

      let tooltipText;
      if (itemPile) {
        if (this.registry) {
          tooltipText = this.registry.getItemDisplayName(itemPile.item);
        } else if (this.getTooltip) {
          tooltipText = this.getTooltip(itemPile);
        }
      } else {
        tooltipText = '';
      }

      tooltipNode.textContent = tooltipText;
    }
  }

  getProgressBarColor(progress) {
    for (let i = 0; i < this.progressColorsThresholds.length; ++i) {
      const threshold = this.progressColorsThresholds.length[i];

      if (progress <= threshold) {
        return this.progressColors[i];
      }

    return this.progressColors.slice(-1)[0];   // default to last
    }
  }

  setBorderStyle(node, index) {
    // based on http://coffeescript.org
    // a // b     Math.floor(a / b)
    // a %% b     (a % b + b) % b
    // TODO: refactor
    function integer_division(a, b) { return Math.floor(a / b); }
    function true_modulo(a, b) { return (a % b + b) % b; }

    const x = true_modulo(index, this.width);
    const y = integer_division(index, this.width);
    const height = this.inventorySize / this.width;
    let kind;
    if (index === this.selectedIndex) {
      kind = 'dotted';
    } else {
      kind = 'solid';
    }

    node.style.border = `${this.borderSize}px ${kind} black`
    if (y === 0) node.style.borderTop = `${this.borderSize * 2}px ${kind} black`;
    if (y === height - 1) node.style.borderBottom = `${this.borderSize * 2}px ${kind} black`;
    if (x === 0) node.style.borderLeft = `${this.borderSize * 2}px ${kind} black`;
    if (x === this.width - 1) node.style.borderRight = `${this.borderSize * 2}px ${kind} black`;
  }
 
  setSelected(index) {
    this.selectedIndex = index;
    this.refresh();    // TODO: selective refresh?
  }

  getSelected(index) {
    return this.selectedIndex;
  }

  refreshSlotNode(index) {
    this.populateSlotNode(this.slotNodes[index], this.inventory.get(index));
    this.setBorderStyle(this.slotNodes[index], index);
  }

  refresh() {
    for (let i = 0; i < this.inventorySize; ++i) {
      this.refreshSlotNode(i);
    }
  }

  positionAtMouse(node, mouseEvent) {
    let x = mouseEvent.x !== undefined ? mouseEvent.x : mouseEvent.clientX
    let y = mouseEvent.y !== undefined ? mouseEvent.y : mouseEvent.clientY;

    x -= this.textureSize / 2;
    y -= this.textureSize / 2;

    node.style.left = x + 'px';
    node.style.top = y + 'px';
  }

  createHeldNode(itemPile, ev) {
    if (global.InventoryWindow_heldNode) this.removeHeldNode();
    if (!itemPile || itemPile.count === 0) {
      global.InventoryWindow_heldItemPile = undefined;
      return;
    }

    global.InventoryWindow_heldItemPile = itemPile;
    global.InventoryWindow_heldNode = this.createSlotNode(global.InventoryWindow_heldItemPile);
    global.InventoryWindow_heldNode.setAttribute('style', global.InventoryWindow_heldNode.getAttribute('style') + `
position: absolute;
user-select: none;
-moz-user-select: none;
-webkit-user-select: none;
pointer-events: none;
z-index: 10;
`);

    this.positionAtMouse(global.InventoryWindow_heldNode, ev);

    document.body.appendChild(global.InventoryWindow_heldNode);
  }

  removeHeldNode() {
    global.InventoryWindow_heldNode.parentNode.removeChild(global.InventoryWindow_heldNode);
    global.InventoryWindow_heldNode = undefined;
    global.InventoryWindow_heldItemPile = undefined;
  }

  dropOneHeld(index) {
    if (this.inventory.get(index)) {
      // drop one, but try to merge with existing
      let oneHeld = global.InventoryWindow_heldItemPile.splitPile(1);
      if (this.inventory.get(index).mergePile(oneHeld) === false) {
        // could not merge, so swap 
        global.InventoryWindow_heldItemPile.increase(1);
        let tmp = global.InventoryWindow_heldItemPile;
        global.InventoryWindow_heldItemPile = this.inventory.get(index);
        this.inventory.set(index, tmp);
      } else {
        this.inventory.changed();
      }
    } else {
      // drop on empty slot
      this.inventory.set(index, global.InventoryWindow_heldItemPile.splitPile(1));
    }
  }

  clickSlot(index, ev) {
    let itemPile = this.inventory.get(index);
    console.log('clickSlot',index,itemPile);

    global.InventoryWindow_mouseButtonDown = ev.button;

    let shiftDown = ev.shiftKey;

    if (ev.button !== this.secondaryMouseButton) {
      // left click: whole pile
      if (!global.InventoryWindow_heldItemPile || !this.allowDrop) {
        // pickup whole pile
        if (!this.allowPickup) return;

        if (global.InventoryWindow_heldItemPile) {
          // tried to drop on pickup-only inventory, so merge into held inventory instead
          if (this.inventory.get(index) !== undefined) {
            if (!global.InventoryWindow_heldItemPile.canPileWith(this.inventory.get(index))) return;
            global.InventoryWindow_heldItemPile.mergePile(this.inventory.get(index));
          }
        } else {
          if (!shiftDown) {
            // simply picking up the whole pile
            global.InventoryWindow_heldItemPile = this.inventory.get(index);
            this.inventory.set(index, undefined);
          } else if (this.linkedInventory && this.inventory.get(index) !== undefined) {
            // shift-click: transfer to linked inventory
            this.linkedInventory.give(this.inventory.get(index));
            if (this.inventory.get(index).count === 0) {
              this.inventory.set(index, undefined);
            }
            this.inventory.changed();   //  update source, might not have transferred all of the pile
          }
        }

        this.emit('pickup');  //  TODO: event data? index, item? cancelable?
      } else {
        // drop whole pile
        if (this.inventory.get(index)) {
          // try to merge piles dropped on each other
          if (this.inventory.get(index).mergePile(global.InventoryWindow_heldItemPile) === false) {
            // cannot pile together; swap dropped/held
            let tmp = global.InventoryWindow_heldItemPile;
            global.InventoryWindow_heldItemPile = this.inventory.get(index);
            this.inventory.set(index, tmp);
          } else {
            this.inventory.changed();
          }
        } else {
          // fill entire slot
          this.inventory.set(index, global.InventoryWindow_heldItemPile);
          global.InventoryWindow_heldItemPile = undefined;
        }
      }
    } else {
      // right-click: half/one
      if (!global.InventoryWindow_heldItemPile) {
        // pickup half
        if (!this.allowPickup) return;
        if (this.inventory.get(index) !== undefined) {
          global.InventoryWindow_heldItemPile = this.inventory.get(index).splitPile(0.5);
        } else {
          global.InventoryWindow_heldItemPile = undefined;
        }

        if (this.inventory.get(index) && this.inventory.get(index).count == 0) {
          this.inventory.set(index, undefined );
        }
        this.inventory.changed();
        this.emit('pickup');  //  TODO: event data? index, item? cancelable?
      } else {
        if (!this.allowDrop) return;
        this.dropOneHeld(index);
      }
    }
    this.createHeldNode(global.InventoryWindow_heldItemPile, ev);
    this.refreshSlotNode(index);
  }
}

module.exports = InventoryWindow;
