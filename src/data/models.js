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

export const DEFAULT_ELEMENTAL_AFFINITIES = [
  { id: 1, key: 'fire', name: 'Fire', color: '#e4572e', description: 'Direct pressure and attack setup.' },
  { id: 2, key: 'earth', name: 'Earth', color: '#8a6f3d', description: 'Endurance, attrition, and recovery.' },
  { id: 3, key: 'water', name: 'Water', color: '#2f80ed', description: 'Defense flow and adaptive protection.' },
  { id: 4, key: 'wind', name: 'Wind', color: '#4fb286', description: 'Card flow, speed, and disruption.' },
  { id: 5, key: 'lightning', name: 'Lightning', color: '#f2c94c', description: 'Energy spikes and duplicated action windows.' },
  { id: 6, key: 'ice', name: 'Ice', color: '#8fd3ff', description: 'Block pressure and end-of-turn control.' }
];

export function createElementalAffinity(data = {}) {
  const base = DEFAULT_ELEMENTAL_AFFINITIES.find(entry => entry.id === Number(data.id)) || DEFAULT_ELEMENTAL_AFFINITIES[0];
  return {
    id: base.id,
    key: base.key,
    name: data.name || base.name,
    color: normalizeHexColor(data.color || base.color, base.color),
    description: data.description || base.description
  };
}

export function normalizeElementalAffinityCatalog(entries = []) {
  return DEFAULT_ELEMENTAL_AFFINITIES.map(base => {
    const authored = Array.isArray(entries) ? entries.find(entry => Number(entry?.id) === base.id || entry?.key === base.key) : null;
    return createElementalAffinity({ ...base, ...(authored || {}) });
  });
}

export function normalizeCardAffinities(values = []) {
  const allowedIds = DEFAULT_ELEMENTAL_AFFINITIES.map(entry => entry.id);
  const seen = new Set();
  const result = [];
  (Array.isArray(values) ? values : []).forEach(value => {
    const id = parseInt(value, 10);
    if (!allowedIds.includes(id) || seen.has(id) || result.length >= 3) return;
    seen.add(id);
    result.push(id);
  });
  return allowedIds.filter(id => result.includes(id));
}

function normalizeHexColor(value, fallback = '#ffffff') {
  const color = String(value || '').trim();
  return /^#[0-9a-fA-F]{6}$/.test(color) ? color.toLowerCase() : fallback;
}

export function createCard(data = {}) {
  return {
    id: data.id || uuid(),
    name: data.name || '',
    description: data.description || '',
    cardImage: data.cardImage || '',
    type: data.type || 'attack', // attack, defend, skill, power
    factionId: data.factionId || null, 
    cost: data.cost ?? 1,
    rarity: data.rarity || 'common', // common, uncommon, rare
    targeting: data.targeting || (data.requiresTarget ? 'single_enemy' : 'self'),
    requiresTarget: data.requiresTarget ?? data.targeting === 'single_enemy', // legacy compatibility
    card_affinities: normalizeCardAffinities(data.card_affinities || data.cardAffinities || []),
    effects: (data.effects || []).map(effect => normalizeCardEffect(effect))
  };
}

function normalizeCardEffect(effect) {
  if (typeof effect === 'string') {
    return normalizeLegacyEffect({ value: effect, scalesWith: 'none' });
  }
  if (effect && typeof effect === 'object' && 'type' in effect) {
    const type = normalizeEffectType(effect.type || 'damage');
    const normalized = {
      ...effect,
      type,
      amount: readEffectAmount(effect),
      target: effect.target || inferTargetFromType(type),
      scaling: effect.scaling || effect.scalesWith || 'none'
    };
    if (type === 'apply_status') {
      normalized.statusId = String(effect.statusId || '');
      if (!normalized.statusId) normalized.amount = 0;
    }
    return normalized;
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
    MODIFY_INSIGHT: 'modify_insight',
    APPLY_STATUS: 'apply_status'
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
    equipmentImage: data.equipmentImage || '',
    type: normalizeEquipmentType(data.type || 'weapon'),
    slotCost: normalizeEquipmentType(data.type || 'weapon') === 'weapon' ? clampSlotCost(data.slotCost) : 1,
    rarity: data.rarity || 'common',
    value: data.value ?? 10,
    effects: data.effects || [],
    cardIds: data.cardIds || [],
    conditions: data.conditions || []
  };
}

function normalizeEquipmentType(type) {
  const value = String(type || '').trim();
  if (['onehandedWeapon', 'twohandedWeapon', 'offHand', 'weapon'].includes(value)) return 'weapon';
  if (['head', 'legs', 'armor'].includes(value)) return 'armor';
  if (['ring', 'amulet', 'accessory'].includes(value)) return 'accessory';
  return 'accessory';
}

function clampSlotCost(value) {
  const parsed = parseInt(value ?? 1, 10);
  return parsed === 2 ? 2 : 1;
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
  const startingDeck = data.startingDeck || [];
  const startingEquipped = {
    weapon_1: data.startingEquipped?.weapon_1 || data.startingEquipped?.weapon_main || '',
    weapon_2: data.startingEquipped?.weapon_2 || data.startingEquipped?.off_hand || '',
    armor: data.startingEquipped?.armor || '',
    accessory_1: data.startingEquipped?.accessory_1 || data.startingEquipped?.ring_left || data.startingEquipped?.amulet || '',
    accessory_2: data.startingEquipped?.accessory_2 || data.startingEquipped?.ring_right || ''
  };
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
    startingDeck,
    startingOwnedCards: startingDeck.slice(),
    startingInventory: {
      consumables: data.startingInventory?.consumables || [],
      equipment: collectStartingEquipmentFromSlots(startingEquipped, data.equipment || []),
      keyItems: data.startingInventory?.keyItems || []
    },
    startingEquipped,
    player_elemental_capacity: clampElementalCapacity(data.player_elemental_capacity ?? data.playerElementalCapacity ?? 1)
  };
}

export function clampElementalCapacity(value) {
  const parsed = parseInt(value ?? 1, 10);
  if (!Number.isFinite(parsed)) return 1;
  return Math.max(0, Math.min(6, parsed));
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
