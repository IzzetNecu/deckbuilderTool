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

export function createConsumable(data = {}) {
  return {
    id: data.id || uuid(),
    name: data.name || '',
    description: data.description || '',
    rarity: data.rarity || 'common',
    value: data.value ?? 10,
    effects: data.effects || []
  };
}

export function createEquipmentCondition(data = {}) {
  return {
    id: data.id || uuid(),
    type: data.type || 'hasStat',
    target: data.target || '',
    operator: data.operator || '>=',
    value: data.value || ''
  };
}

export function createEquipment(data = {}) {
  return {
    id: data.id || uuid(),
    name: data.name || '',
    description: data.description || '',
    type: data.type || 'onehandedWeapon', // offHand, onehandedWeapon, twohandedWeapon, head, armor, legs, ring, amulet
    rarity: data.rarity || 'common',
    value: data.value ?? 10,
    effects: data.effects || [],
    cardIds: data.cardIds || [],
    conditions: data.conditions || []
  };
}

export function createKeyItem(data = {}) {
  return {
    id: data.id || uuid(),
    name: data.name || '',
    description: data.description || ''
  };
}

export function createEnemy(data = {}) {
  return {
    id: data.id || uuid(),
    name: data.name || '',
    description: data.description || '',
    hp: data.hp ?? 10,
    hand_size: data.hand_size ?? 3,
    factionId: data.factionId || null,
    deckIds: data.deckIds || [],
    lootTable: data.lootTable || []
  };
}

export function createEventOption(data = {}) {
  return {
    id: data.id || uuid(),
    text: data.text || '',
    lockType: data.lockType || 'soft', // 'soft' (visible but locked), 'hard' (invisible)
    conditions: data.conditions || [],
    outcomes: data.outcomes || []
  };
}

export function createEventCondition(data = {}) {
  return {
    id: data.id || uuid(),
    type: data.type || 'hasStat', // hasMoney, hasStat, hasConsumable, lacksConsumable, hasEquipment, lacksEquipment, hasKeyItem, lacksKeyItem, hasFactionRank
    target: data.target || '', 
    operator: data.operator || '>=', // >=, <=, ==
    value: data.value || '' 
  };
}

export function createEventOutcome(data = {}) {
  return {
    id: data.id || uuid(),
    type: data.type || 'text', // addConsumable, removeConsumable, addEquipment, removeEquipment, addKeyItem, removeKeyItem, addCard, removeCard, addMoney, removeMoney, damage, heal, modifyStat, travelToMap, startCombat, startEvent, text
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
    backgroundImage: data.backgroundImage || '',
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
    label: data.label || '',
    description: data.description || '',
    isStartingNode: data.isStartingNode || false,
    options: data.options || [] // same shape as event options: { text, conditions[], outcomes[] }
  };
}

export function createMapConnection(fromNodeId, toNodeId, data = {}) {
  return {
    id: data.id || uuid(),
    fromNodeId,
    toNodeId,
    conditions: data.conditions || [],
    gateType: data.gateType || 'none' // 'none', 'soft' (visible but locked), 'hard' (hidden)
  };
}

export function createFlag(data = {}) {
  return {
    id: data.id || uuid(),
    name: data.name || '',
    description: data.description || '',
    defaultValue: data.defaultValue || false
  };
}
