/**
 * LocalStorage wrapper for the Game Builder data.
 */

const STORE_PREFIX = 'gamebuilder_';
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

  remove(collectionName, id) {
    const list = this.getAll(collectionName);
    const filtered = list.filter(item => item.id !== id);
    localStorage.setItem(STORE_PREFIX + collectionName, JSON.stringify(filtered));
  },

  /** Returns all data formatted for Godot */
  exportAll() {
    const data = { schemaVersion: 3 };
    COLLECTIONS.forEach(col => {
      // Deep clone to ensure nested arrays (e.g. map nodes/connections) are fully included
      data[col] = JSON.parse(JSON.stringify(this.getAll(col)));
    });
    return JSON.stringify(data, null, 2);
  },

  /** Imports raw JSON, overwriting existing */
  importAll(jsonString) {
    try {
      const data = JSON.parse(jsonString);
      COLLECTIONS.forEach(col => {
        if (data[col] && Array.isArray(data[col])) {
          localStorage.setItem(STORE_PREFIX + col, JSON.stringify(data[col]));
        }
      });
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
