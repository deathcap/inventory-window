'use strict';

const InventoryWindow = require('./');
const Inventory = require('inventory');
const ItemPile = require('itempile');
const ever = require('ever');

const inv = new Inventory(5, 5);
inv.give(new ItemPile('diamond', 1));
inv.give(new ItemPile('emerald', 64));
inv.give(new ItemPile('emerald', 32));
inv.give(new ItemPile('emerald', 32));
for (let i = 0; i < 10; ++i) {
  inv.give(new ItemPile('stick', 64));
}
inv.array[15] = new ItemPile('grass', 3);  // block
inv.array[17] = new ItemPile('pick', 2, {damage:20});
inv.array[18] = new ItemPile('stick', 0);
inv.array[19] = new ItemPile('pick', 1, {damage:50});
inv.array[20] = new ItemPile('stick', 2);
inv.array[21] = new ItemPile('stick', 16);
inv.array[22] = new ItemPile('stick', 32);
inv.array[24] = new ItemPile('diamond', Infinity);
console.log(inv+'');
console.log(inv.size());

// a few simple images for testing
const images = {
  diamond: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAKUlEQVQ4y2NgGAX4wf///8GYIs1kG0KRAeiaqWIASYYMAwOoEo1DBgAANn6AgLPwDSsAAAAASUVORK5CYII=',
  emerald: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAJ0lEQVQ4y2NgGAX4wX8opEgz2YZQZMB/LJBiA0gyZBgYQJVoHDIAAHr/Vaux9NNYAAAAAElFTkSuQmCC',
  stick: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAI0lEQVQ4y2NgGFlgb73j/0Jv9f8UaQbRo5pHNeMEFGkeUAAAmkJGZ284PasAAAAASUVORK5CYII=',
  pick: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAATUlEQVQ4y2NgGMzgPxZMvOb//zExyYagY3IMAYO99Y7/C73VyTMEphlEk2wAmmYGkgzAopl4A3BoJs4APJqRY4dszQy00QwCFGkeUAAAq91xekLx2vsAAAAASUVORK5CYII=',
  grass_top: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAYElEQVQ4y61TwREAIAiy/cdyGqao3qWIXQ8flgGimfmYhh1OAuQsvahAPQOoFCACUFkR5K2+wxbQMMyZApXxrJUZ8TIFBoRoCl8UdL2QHpSLpBanf+F1hJcCNP2AugckXwA2yZhbyqZNAAAAAElFTkSuQmCC',
  grass_side: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAdElEQVQ4y2NgOMz4n+ElEB/Gg1/iEcMpQchQGJ6ZZvyfEL4zxRsrG4QZkAXRJfEZBOMzEKsYF2bAZiqxhqG4gFgb0dUyEGsjLgsYSAk0bAHOgCt0yXYBqWHBQIwGggmJWMXY1DFQEoUYLiAmMIkKA0IGIfMBkw04/LuclggAAAAASUVORK5CYII='
};

const item_images = {
  diamond: images.diamond,
  emerald: images.emerald,
  stick: images.stick,
  pick: images.pick,
  grass: {top:images.grass_top, front:images.grass_side, left:images.grass_side}
  //grass: [images.grass_top, null, images.grass_side, images.grass_side] # arrays work too
};

const ucfirst = (s) => s.substr(0, 1).toUpperCase() + s.substring(1);

InventoryWindow.defaultGetTexture = (pile) => item_images[pile.item];
InventoryWindow.defaultGetMaxDamage = (pile) => 80;
InventoryWindow.defaultGetTooltip = (pile) => ucfirst(pile.item);

const w = new InventoryWindow({
  inventory: inv
});

const container = w.createContainer();
console.log(container);
document.body.appendChild(container);

ever(document.body).on('contextmenu', (ev) => ev.preventDefault());

w.setSelected(7);

window.w = w;

const w2 = new InventoryWindow({
  inventory: inv,
  allowDrop: false});

document.body.appendChild(w2.createContainer());

const inv3 = new Inventory(4, 4);
const w3 = new InventoryWindow({inventory: inv3, linkedInventory:inv});
w.linkedInventory = inv3;  // go both ways
document.body.appendChild(w3.createContainer());

