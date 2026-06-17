import { clampElementalCapacity, normalizeCardAffinities, normalizeElementalAffinityCatalog } from './models.js?v=1779267161';

/**
 * LocalStorage wrapper for the Game Builder data.
 */

const STORE_PREFIX = 'gamebuilder_';
const CATALOG_KEYS = [
  'elemental_affinities'
];
const COLLECTIONS = [
  'players',
  'buffs',
  'factions',
  'cards',
  'consumables',
  'equipment',
  'keyItems',
  'enemies',
  'events',
  'deckTemplates',
  'maps',
  'flags'
];

export const store = {
  /** Initialize empty arrays if missing */
  init() {
    COLLECTIONS.forEach(col => {
      if (!localStorage.getItem(STORE_PREFIX + col)) {
        localStorage.setItem(STORE_PREFIX + col, JSON.stringify([]));
      }
    });
    if (!localStorage.getItem(STORE_PREFIX + 'elemental_affinities')) {
      localStorage.setItem(STORE_PREFIX + 'elemental_affinities', JSON.stringify(normalizeElementalAffinityCatalog([])));
    }
  },

  getAll(collectionName) {
    const data = localStorage.getItem(STORE_PREFIX + collectionName);
    return data ? JSON.parse(data) : [];
  },

  getById(collectionName, id) {
    const list = this.getAll(collectionName);
    return list.find(item => item.id === id) || null;
  },

  save(collectionName, item) {
    const list = this.getAll(collectionName);
    const index = list.findIndex(e => e.id === item.id);
    if (index >= 0) {
      list[index] = item;
    } else {
      list.push(item);
    }
    localStorage.setItem(STORE_PREFIX + collectionName, JSON.stringify(list));
  },

  saveAll(collectionName, items) {
    localStorage.setItem(STORE_PREFIX + collectionName, JSON.stringify(items));
  },

  remove(collectionName, id) {
    const list = this.getAll(collectionName);
    const filtered = list.filter(item => item.id !== id);
    localStorage.setItem(STORE_PREFIX + collectionName, JSON.stringify(filtered));
  },

  /** Returns all data formatted for Godot */
  exportAll() {
    const data = { schemaVersion: 4 };
    COLLECTIONS.forEach(col => {
      // Deep clone to ensure nested arrays (e.g. map nodes/connections) are fully included
      data[col] = JSON.parse(JSON.stringify(this.getAll(col)));
    });
    CATALOG_KEYS.forEach(key => {
      data[key] = JSON.parse(JSON.stringify(this.getAll(key)));
    });
    data.elemental_affinities = normalizeElementalAffinityCatalog(data.elemental_affinities);
    data.cards = data.cards.map(card => normalizeCardForExport(card));
    data.players = data.players.map(player => normalizePlayerForExport(player, data.equipment));
    return JSON.stringify(data, null, 2);
  },

  /** Imports raw JSON, overwriting existing */
  importAll(jsonString) {
    try {
      const data = JSON.parse(jsonString);
      COLLECTIONS.forEach(col => {
        if (data[col] && Array.isArray(data[col])) {
          localStorage.setItem(STORE_PREFIX + col, JSON.stringify(normalizeImportedCollection(col, data[col])));
        }
      });
      localStorage.setItem(STORE_PREFIX + 'elemental_affinities', JSON.stringify(normalizeElementalAffinityCatalog(data.elemental_affinities || [])));
      return true;
    } catch (err) {
      console.error("Import failed:", err);
      return false;
    }
  },

  clearAll() {
    COLLECTIONS.forEach(col => {
      localStorage.removeItem(STORE_PREFIX + col);
    });
    this.init();
  }
};

store.init();

function normalizeImportedCollection(collectionName, items) {
  if (collectionName === 'cards') {
    return items.map(card => normalizeCardForExport(card));
  }
  if (collectionName === 'players') {
    return items.map(player => ({
      ...player,
      player_elemental_capacity: clampElementalCapacity(player.player_elemental_capacity ?? player.playerElementalCapacity ?? 1)
    }));
  }
  return items;
}

function normalizeCardForExport(card) {
  return {
    ...card,
    card_affinities: normalizeCardAffinities(card.card_affinities || card.cardAffinities || [])
  };
}

function normalizePlayerForExport(player, equipmentItems = []) {
  const normalized = JSON.parse(JSON.stringify(player));
  normalized.player_elemental_capacity = clampElementalCapacity(normalized.player_elemental_capacity ?? normalized.playerElementalCapacity ?? 1);
  normalized.startingDeck = normalized.startingDeck || [];
  normalized.startingOwnedCards = normalized.startingDeck.slice();
  normalized.startingEquipped = {
    weapon_1: normalized.startingEquipped?.weapon_1 || '',
    weapon_2: normalized.startingEquipped?.weapon_2 || '',
    armor: normalized.startingEquipped?.armor || '',
    accessory_1: normalized.startingEquipped?.accessory_1 || '',
    accessory_2: normalized.startingEquipped?.accessory_2 || ''
  };
  if (isTwoSlotWeapon(normalized.startingEquipped.weapon_1, equipmentItems)) {
    normalized.startingEquipped.weapon_2 = normalized.startingEquipped.weapon_1;
  } else if (isTwoSlotWeapon(normalized.startingEquipped.weapon_2, equipmentItems)) {
    normalized.startingEquipped.weapon_1 = normalized.startingEquipped.weapon_2;
  }
  normalized.startingInventory = {
    consumables: normalized.startingInventory?.consumables || [],
    equipment: collectStartingEquipmentFromSlots(normalized.startingEquipped, equipmentItems),
    keyItems: normalized.startingInventory?.keyItems || []
  };
  return normalized;
}

function isTwoSlotWeapon(itemId, equipmentItems) {
  const item = equipmentItems.find(entry => entry.id === itemId);
  return item?.type === 'weapon' && parseInt(item.slotCost || 1, 10) > 1;
}

function collectStartingEquipmentFromSlots(slots, equipmentItems) {
  const result = [];
  const countedTwoSlotWeapons = new Set();
  Object.values(slots).forEach(itemId => {
    if (!itemId) return;
    const item = equipmentItems.find(entry => entry.id === itemId);
    const isTwoSlotWeapon = item?.type === 'weapon' && parseInt(item.slotCost || 1, 10) > 1;
    if (isTwoSlotWeapon) {
      if (countedTwoSlotWeapons.has(itemId)) return;
      countedTwoSlotWeapons.add(itemId);
    }
    result.push(itemId);
  });
  return result;
}
