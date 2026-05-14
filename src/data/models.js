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

export function createBuff(data = {}) {
  return {
    id: data.id || uuid(),
    name: data.name || '',
    kind: data.kind || 'buff',
    iconImage: data.iconImage || '',
    shortLabel: data.shortLabel || '',
    reminderText: data.reminderText || ''
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
    targeting: data.targeting || (data.requiresTarget ? 'single_enemy' : 'self'),
    requiresTarget: data.requiresTarget ?? data.targeting === 'single_enemy', // legacy compatibility
    effects: (data.effects || []).map(effect => normalizeCardEffect(effect))
  };
}

function normalizeCardEffect(effect) {
  if (typeof effect === 'string') {
    return normalizeLegacyEffect({ value: effect, scalesWith: 'none' });
  }
  if (effect && typeof effect === 'object' && 'type' in effect) {
    const type = normalizeEffectType(effect.type || 'damage');
    return {
      type,
      amount: readEffectAmount(effect),
      target: effect.target || inferTargetFromType(type),
      scaling: effect.scaling || effect.scalesWith || 'none'
    };
  }
  return normalizeLegacyEffect(effect || {});
}

function normalizeLegacyEffect(effect) {
  const value = effect.value || '';
  const [legacyType, rawAmount] = value.split(':');
  const normalizedType = normalizeEffectType(legacyType);
  return {
    type: normalizedType,
    amount: parseInt(rawAmount ?? 0, 10) || 0,
    target: inferTargetFromType(normalizedType),
    scaling: effect.scalesWith || 'none',
    value
  };
}

function normalizeEffectType(type) {
  const normalized = String(type || '').trim();
  if (!normalized) return 'damage';
  const typeMap = {
    ATTACK: 'damage',
    DEFEND: 'block',
    HEAL: 'heal',
    DRAW: 'draw',
    DISCARD: 'discard',
    GAIN_ENERGY: 'gain_energy',
    INSIGHT: 'modify_insight',
    MODIFY_INSIGHT: 'modify_insight'
  };
  return typeMap[normalized.toUpperCase()] || normalized.toLowerCase();
}

function readEffectAmount(effect) {
  if (Number.isFinite(effect.amount)) return effect.amount;
  const numericAmount = parseInt(effect.amount ?? '', 10);
  if (Number.isFinite(numericAmount)) return numericAmount;
  const value = String(effect.value || '');
  const [, rawAmount = value] = value.split(':');
  return parseInt(rawAmount ?? 0, 10) || 0;
}

function inferTargetFromType(type) {
  if (type === 'damage') return 'enemy';
  return 'self';
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
    portraitImage: data.portraitImage || '',
    hp: data.hp ?? data.stats?.maxHealth ?? 10,
    hand_size: data.hand_size ?? data.handSize ?? 3,
    handSize: data.handSize ?? data.hand_size ?? 3,
    factionId: data.factionId || null,
    stats: {
      maxHealth: data.stats?.maxHealth ?? data.hp ?? 10,
      strength: data.stats?.strength ?? 0,
      dexterity: data.stats?.dexterity ?? 0,
      insight: data.stats?.insight ?? 0
    },
    intentMode: data.intentMode || 'deck',
    intentPreviewCount: data.intentPreviewCount ?? 0,
    deckTemplateIds: data.deckTemplateIds || [], // deck templates included in enemy's deck
    deckIds: data.deckIds || [],                 // individual extra cards
    lootTable: data.lootTable || []
  };
}

export function createPlayer(data = {}) {
  return {
    id: data.id || uuid(),
    name: data.name || 'Hero',
    portraitImage: data.portraitImage || '',
    baseStats: {
      maxHealth: data.baseStats?.maxHealth ?? 20,
      strength: data.baseStats?.strength ?? 1,
      dexterity: data.baseStats?.dexterity ?? 1,
      insight: data.baseStats?.insight ?? 0,
      maxEnergy: data.baseStats?.maxEnergy ?? 3,
      handSize: data.baseStats?.handSize ?? 5
    },
    startingDeck: data.startingDeck || [],
    startingOwnedCards: data.startingOwnedCards || data.startingDeck || [],
    startingInventory: {
      consumables: data.startingInventory?.consumables || [],
      equipment: data.startingInventory?.equipment || [],
      keyItems: data.startingInventory?.keyItems || []
    },
    startingEquipped: {
      weapon_main: data.startingEquipped?.weapon_main || '',
      off_hand: data.startingEquipped?.off_hand || '',
      head: data.startingEquipped?.head || '',
      armor: data.startingEquipped?.armor || '',
      legs: data.startingEquipped?.legs || '',
      amulet: data.startingEquipped?.amulet || '',
      ring_left: data.startingEquipped?.ring_left || '',
      ring_right: data.startingEquipped?.ring_right || ''
    }
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
