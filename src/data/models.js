/** 
 * Data models with default factory functions
 * Generates an ID if not provided.
 */

function uuid() {
  return crypto.randomUUID();
}

export function createFaction(data = {}) {
  return {
    id: data.id || uuid(),
    name: data.name || '',
    description: data.description || '',
    color: data.color || '#ffffff',
    ranks: data.ranks || [] // Array of string tier names
  };
}

export function createCard(data = {}) {
  return {
    id: data.id || uuid(),
    name: data.name || '',
    description: data.description || '',
    type: data.type || 'attack', // attack, defend, skill, power
    factionId: data.factionId || null, 
    cost: data.cost ?? 1,
    rarity: data.rarity || 'common', // common, uncommon, rare
    effects: data.effects || []
  };
}

export function createItem(data = {}) {
  return {
    id: data.id || uuid(),
    name: data.name || '',
    description: data.description || '',
    type: data.type || 'consumable', // weapon, armor, consumable, key
    effects: data.effects || [],
    rarity: data.rarity || 'common',
    value: data.value ?? 10
  };
}

export function createEnemy(data = {}) {
  return {
    id: data.id || uuid(),
    name: data.name || '',
    description: data.description || '',
    hp: data.hp ?? 10,
    factionId: data.factionId || null,
    deckIds: data.deckIds || [],
    lootTable: data.lootTable || []
  };
}

export function createEventOption(data = {}) {
  return {
    id: data.id || uuid(),
    text: data.text || '',
    conditions: data.conditions || [],
    outcomes: data.outcomes || []
  };
}

export function createEventCondition(data = {}) {
  return {
    id: data.id || uuid(),
    type: data.type || 'hasStat', // hasMoney, hasStat, hasItem, lacksItem, hasFactionRank
    target: data.target || '', // e.g. "strength", itemId
    operator: data.operator || '>=', // >=, <=, ==
    value: data.value || '' // number or string depending on type
  };
}

export function createEventOutcome(data = {}) {
  return {
    id: data.id || uuid(),
    type: data.type || 'text', // addItem, removeItem, addCard, removeCard, addMoney, removeMoney, damage, heal, modifyStat, text
    target: data.target || '', 
    value: data.value || '' 
  };
}

export function createEvent(data = {}) {
  return {
    id: data.id || uuid(),
    name: data.name || '',
    description: data.description || '',
    options: data.options || [] 
  };
}

export function createDeckTemplate(data = {}) {
  return {
    id: data.id || uuid(),
    name: data.name || '',
    factionId: data.factionId || null,
    cardIds: data.cardIds || []
  };
}

export function createGameMap(data = {}) {
  return {
    id: data.id || uuid(),
    name: data.name || '',
    description: data.description || '',
    isOverworld: data.isOverworld || false,
    parentMapId: data.parentMapId || null,
    nodes: data.nodes || [],
    connections: data.connections || []
  };
}

export function createMapNode(data = {}) {
  return {
    id: data.id || uuid(),
    x: data.x || 0,
    y: data.y || 0,
    type: data.type || 'event', // event, combat, shop, rest, boss, submap, start
    label: data.label || '',
    linkedId: data.linkedId || null // ID of linked event, enemy, or submap
  };
}

export function createMapConnection(fromNodeId, toNodeId) {
  return {
    fromNodeId,
    toNodeId
  };
}
