import { store } from '../../data/store.js?v=1778179374';
import { createCard } from '../../data/models.js?v=1778179374';
import { showConfirmModal } from '../components/modal.js?v=1778179374';
import { PREDEFINED_BUFFS } from './buff-editor.js?v=1778179374';

const EFFECT_TYPES = [
  ['damage', 'Damage'],
  ['block', 'Block'],
  ['heal', 'Heal'],
  ['draw', 'Draw'],
  ['discard', 'Discard'],
  ['gain_energy', 'Gain Energy'],
  ['modify_insight', 'Modify Insight'],
  ['apply_status', 'Apply Status']
];

const TARGETING_OPTIONS = [
  ['self', 'Self'],
  ['single_enemy', 'Single Enemy'],
  ['none', 'No Target'],
  ['all_enemies', 'All Enemies'],
  ['random_enemy', 'Random Enemy']
];

const EFFECT_TARGETS = [
  ['self', 'Self'],
  ['enemy', 'Enemy'],
  ['all_enemies', 'All Enemies']
];

const SCALING_OPTIONS = ['none', 'strength', 'dexterity', 'insight'];
const NON_ELEMENTAL_STATUS_IDS = new Set(['buff_block', 'buff_strength', 'buff_dexterity', 'buff_insight', 'buff_energy']);
const APPLY_STATUS_OPTIONS = PREDEFINED_BUFFS.filter(buff => !NON_ELEMENTAL_STATUS_IDS.has(buff.id));

export function renderCardEditor(container) {
  let cards = store.getAll('cards');
  let factions = store.getAll('factions');
  let selectedId = null;

  function render() {
    const selectedCard = cards.find(card => card.id === selectedId) || null;
    const pane = container.querySelector('.pane-form');
    const scrollTop = pane ? pane.scrollTop : 0;

    container.innerHTML = `
      <div class="editor-header">
        <h2>Card Editor</h2>
        <div style="display:flex; gap:8px;">
          <button id="btn-card-help" style="background:var(--bg-surface); border:1px solid var(--border); border-radius:50%; width:32px; height:32px; font-size:1em; cursor:pointer; color:var(--text-secondary);" title="How to create a card">?</button>
          <button id="btn-create-card" class="primary">+ New Card</button>
        </div>
      </div>
      <div class="editor-body split-pane">
        <div class="pane-list">
          <div class="item-list">
            ${cards.map(card => `
              <div class="list-item ${card.id === selectedId ? 'selected' : ''}" data-id="${card.id}">
                <strong style="color:${card.name ? 'inherit' : 'var(--text-secondary)'}">${card.name || 'Unnamed Card'}</strong>
                <div style="font-size:0.8em; color:var(--text-secondary); margin-top:4px;">
                  ${card.type} • Cost: ${card.cost}
                </div>
              </div>
            `).join('')}
            ${cards.length === 0 ? `<div style="padding:16px; color:var(--text-secondary); text-align:center;">No cards created yet.</div>` : ''}
          </div>
        </div>
        <div class="pane-form" style="display:flex; gap:32px;">
          ${selectedCard ? renderForm(selectedCard) : `<div class="empty-state" style="flex:1;">Select or create a card to edit.</div>`}
          ${selectedCard ? renderPreview(selectedCard) : ''}
        </div>
      </div>
    `;

    attachEvents();
    requestAnimationFrame(() => {
      const nextPane = container.querySelector('.pane-form');
      if (nextPane) nextPane.scrollTop = scrollTop;
    });
  }

  function renderForm(card) {
    const normalizedEffects = normalizeEffects(card.effects);
    return `
      <div style="flex:1; max-width:600px;">
        <div class="form-row">
          <div class="form-group">
            <label>Name</label>
            <input type="text" id="card-name" value="${card.name}" placeholder="e.g. Strike" />
          </div>
          <div class="form-group">
            <label>Cost</label>
            <input type="number" id="card-cost" value="${card.cost}" min="0" max="10" />
          </div>
        </div>

        <div class="form-row">
          <div class="form-group">
            <label>Type</label>
            <select id="card-type">
              <option value="attack" ${card.type === 'attack' ? 'selected' : ''}>Attack</option>
              <option value="defend" ${card.type === 'defend' ? 'selected' : ''}>Defend</option>
              <option value="skill" ${card.type === 'skill' ? 'selected' : ''}>Skill</option>
              <option value="power" ${card.type === 'power' ? 'selected' : ''}>Power</option>
            </select>
          </div>
          <div class="form-group">
            <label>Rarity</label>
            <select id="card-rarity">
              <option value="common" ${card.rarity === 'common' ? 'selected' : ''}>Common</option>
              <option value="uncommon" ${card.rarity === 'uncommon' ? 'selected' : ''}>Uncommon</option>
              <option value="rare" ${card.rarity === 'rare' ? 'selected' : ''}>Rare</option>
            </select>
          </div>
          <div class="form-group">
            <label>Faction (Optional)</label>
            <select id="card-faction">
              <option value="">None / Neutral</option>
              ${factions.map(faction => `<option value="${faction.id}" ${card.factionId === faction.id ? 'selected' : ''}>${faction.name}</option>`).join('')}
            </select>
          </div>
        </div>

        <div class="form-row">
          <div class="form-group">
            <label>Targeting</label>
            <select id="card-targeting">
              ${TARGETING_OPTIONS.map(([value, label]) => `<option value="${value}" ${getTargeting(card) === value ? 'selected' : ''}>${label}</option>`).join('')}
            </select>
          </div>
        </div>

        <div class="form-group">
          <label>Description</label>
          <textarea id="card-desc" rows="3" placeholder="e.g. Deal {damage} damage.">${card.description}</textarea>
          ${normalizedEffects.length > 0 ? `
            <div style="font-size:0.78em; color:var(--accent); margin-top:5px;">
              Available tokens: ${[...new Set(normalizedEffects.map(effect => effect.type))].map(token => `<code style="background:#1a1a1a;padding:1px 4px;border-radius:3px;">{${token}}</code>`).join(' ')}
            </div>
          ` : ''}
        </div>

        <div class="form-group">
          <label>Combat Effects</label>
          <div class="dynamic-list" id="effects-list">
            ${normalizedEffects.map((effect, index) => `
              <div class="dynamic-item" style="display:grid; grid-template-columns: 1fr 0.65fr 0.75fr 0.75fr 1fr auto; gap:6px; align-items:center;">
                <select class="effect-type" data-index="${index}">
                  ${EFFECT_TYPES.map(([value, label]) => `<option value="${value}" ${effect.type === value ? 'selected' : ''}>${label}</option>`).join('')}
                </select>
                <input type="number" class="effect-amount" data-index="${index}" value="${effect.amount}" />
                <select class="effect-target" data-index="${index}">
                  ${EFFECT_TARGETS.map(([value, label]) => `<option value="${value}" ${effect.target === value ? 'selected' : ''}>${label}</option>`).join('')}
                </select>
                <select class="effect-scaling" data-index="${index}">
                  ${SCALING_OPTIONS.map(value => `<option value="${value}" ${effect.scaling === value ? 'selected' : ''}>${value === 'none' ? 'No Scaling' : value}</option>`).join('')}
                </select>
                <select class="effect-status-id" data-index="${index}" ${effect.type === 'apply_status' ? '' : 'disabled'} style="${effect.type === 'apply_status' ? '' : 'opacity:0.55;'}">
                  ${APPLY_STATUS_OPTIONS.map(buff => `<option value="${buff.id}" ${effect.statusId === buff.id ? 'selected' : ''}>${buff.name}</option>`).join('')}
                </select>
                <button class="danger btn-remove-effect" data-index="${index}">X</button>
              </div>
            `).join('')}
            <div style="margin-top:8px;">
              <button id="btn-add-effect">Add Effect</button>
            </div>
          </div>
        </div>

        <div style="margin-top:32px; padding-top:16px; border-top:1px solid var(--border); display:flex; justify-content:space-between;">
          <button id="btn-delete-card" class="danger">Delete Card</button>
        </div>
      </div>
    `;
  }

  function renderPreview(card) {
    const factionColor = card.factionId ? (factions.find(faction => faction.id === card.factionId)?.color || '#555') : '#555';
    const rareColor = card.rarity === 'rare' ? '#ffd700' : (card.rarity === 'uncommon' ? '#87ceeb' : '#fff');
    return `
      <div style="width:250px; background-color:var(--bg-surface); padding:16px; border-radius:8px; border-top:4px solid ${factionColor}; border-bottom:2px solid ${rareColor};">
        <h4 style="color:var(--text-secondary); margin-bottom:16px;">Live Preview</h4>
        <div style="width:200px; height:300px; background-color:#222; border-radius:8px; border:2px solid #444; position:relative; display:flex; flex-direction:column;">
          <div style="display:flex; justify-content:space-between; align-items:center; padding:8px; background-color:${factionColor}33; border-bottom:1px solid #444; border-radius:8px 8px 0 0;">
            <strong style="font-size:14px; text-shadow:1px 1px 2px #000;">${card.name || 'Unnamed'}</strong>
            <div style="width:24px; height:24px; border-radius:50%; background:#111; color:${rareColor}; display:flex; align-items:center; justify-content:center; font-weight:bold; border:1px solid ${factionColor};">
              ${card.cost}
            </div>
          </div>
          <div style="flex:1; display:flex; align-items:center; justify-content:center; border-bottom:1px solid #444; color:#666; font-size:12px;">
            [Art Placeholder]
          </div>
          <div style="text-align:center; padding:4px; font-size:10px; text-transform:uppercase; letter-spacing:1px; background:#1a1a1a;">
            ${card.type} • ${getTargeting(card)}
          </div>
          <div style="height:100px; padding:8px; text-align:center; font-size:12px; display:flex; align-items:center; justify-content:center;">
            ${resolveDescription(card.description, normalizeEffects(card.effects)) || '<span style="color:#555">No description</span>'}
          </div>
        </div>
      </div>
    `;
  }

  function attachEvents() {
    container.querySelector('#btn-card-help')?.addEventListener('click', openHelpPopup);

    container.querySelector('#btn-create-card')?.addEventListener('click', () => {
      const card = createCard();
      store.save('cards', card);
      cards = store.getAll('cards');
      selectedId = card.id;
      render();
    });

    container.querySelectorAll('.list-item').forEach(item => {
      item.addEventListener('click', event => {
        selectedId = event.currentTarget.dataset.id;
        render();
      });
    });

    if (!container.querySelector('#card-name')) return;

    const onChange = () => {
      const card = cards.find(entry => entry.id === selectedId);
      if (!card) return;
      card.name = container.querySelector('#card-name').value;
      card.cost = parseInt(container.querySelector('#card-cost').value, 10) || 0;
      card.type = container.querySelector('#card-type').value;
      card.rarity = container.querySelector('#card-rarity').value;
      card.factionId = container.querySelector('#card-faction').value;
      card.description = container.querySelector('#card-desc').value;
      card.targeting = container.querySelector('#card-targeting').value;
      card.requiresTarget = card.targeting === 'single_enemy';
      card.effects = Array.from(container.querySelectorAll('.effect-type')).map((field, index) => ({
        type: field.value,
        amount: parseInt(container.querySelector(`.effect-amount[data-index="${index}"]`).value, 10) || 0,
        target: container.querySelector(`.effect-target[data-index="${index}"]`).value,
        scaling: container.querySelector(`.effect-scaling[data-index="${index}"]`).value,
        statusId: field.value === 'apply_status'
          ? container.querySelector(`.effect-status-id[data-index="${index}"]`).value
          : ''
      }));
      store.save('cards', card);
    };

    container.querySelectorAll('input, textarea, select').forEach(field => {
      field.addEventListener('change', () => {
        onChange();
        render();
      });
      field.addEventListener('blur', onChange);
      field.addEventListener('input', () => {
        onChange();
        renderPreviewOnly();
      });
    });

    container.querySelector('#btn-add-effect')?.addEventListener('click', () => {
      const card = cards.find(entry => entry.id === selectedId);
      const effects = normalizeEffects(card.effects);
      effects.push({ type: 'damage', amount: 0, target: 'enemy', scaling: 'none' });
      card.effects = effects;
      store.save('cards', card);
      render();
    });

    container.querySelectorAll('.btn-remove-effect').forEach(button => {
      button.addEventListener('click', event => {
        const card = cards.find(entry => entry.id === selectedId);
        const effects = normalizeEffects(card.effects);
        effects.splice(parseInt(event.currentTarget.dataset.index, 10), 1);
        card.effects = effects;
        store.save('cards', card);
        render();
      });
    });

    container.querySelector('#btn-delete-card')?.addEventListener('click', () => {
      showConfirmModal('Are you sure you want to delete this card?', () => {
        store.remove('cards', selectedId);
        cards = store.getAll('cards');
        selectedId = null;
        render();
      });
    });
  }

  function renderPreviewOnly() {
    const card = cards.find(entry => entry.id === selectedId);
    if (!card) return;
    const previewContainer = container.querySelector('.pane-form')?.children?.[1];
    if (previewContainer) previewContainer.outerHTML = renderPreview(card);
  }

  function normalizeEffects(effects) {
    return (effects || []).map(effect => {
      if (typeof effect === 'string') {
        return legacyToStructured({ value: effect, scalesWith: 'none' });
      }
      if (effect && typeof effect === 'object' && 'type' in effect) {
        const type = normalizeEffectType(effect.type || 'damage');
        return {
          type,
          amount: readEffectAmount(effect),
          target: effect.target || inferTarget(type),
          scaling: effect.scaling || effect.scalesWith || 'none',
          statusId: type === 'apply_status' ? String(effect.statusId || APPLY_STATUS_OPTIONS[0]?.id || '') : ''
        };
      }
      return legacyToStructured(effect);
    });
  }

  function legacyToStructured(effect) {
    const [legacyType, rawAmount] = String(effect.value || '').split(':');
    const type = normalizeEffectType(legacyType);
    return {
      type,
      amount: parseInt(rawAmount ?? 0, 10) || 0,
      target: inferTarget(type),
      scaling: effect.scalesWith || 'none',
      statusId: ''
    };
  }

  function normalizeEffectType(type) {
    const normalized = String(type || '').trim();
    if (!normalized) return 'damage';
    const legacyMap = {
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
    return legacyMap[normalized.toUpperCase()] || normalized.toLowerCase();
  }

  function readEffectAmount(effect) {
    const numericAmount = parseInt(effect.amount ?? '', 10);
    if (Number.isFinite(numericAmount)) return numericAmount;
    const value = String(effect.value || '');
    const [, rawAmount = value] = value.split(':');
    return parseInt(rawAmount ?? 0, 10) || 0;
  }

  function inferTarget(type) {
    if (type === 'damage') return 'enemy';
    return 'self';
  }

  function getTargeting(card) {
    return card.targeting || (card.requiresTarget ? 'single_enemy' : 'self');
  }

  function resolveDescription(description, effects) {
    if (!description) return description;
    let result = description;
    effects.forEach(effect => {
      const amount = String(effect.amount);
      result = result.split(`{${effect.type}}`).join(amount);
      result = result.split(`{${legacyTokenForEffect(effect.type)}}`).join(amount);
    });
    return result;
  }

  function legacyTokenForEffect(type) {
    const map = {
      damage: 'ATTACK',
      block: 'DEFEND',
      heal: 'HEAL',
      draw: 'DRAW',
      discard: 'DISCARD',
      gain_energy: 'GAIN_ENERGY',
      modify_insight: 'INSIGHT'
    };
    return map[type] || String(type).toUpperCase();
  }

  function openHelpPopup() {
    document.getElementById('card-help-overlay')?.remove();

    const overlay = document.createElement('div');
    overlay.id = 'card-help-overlay';
    overlay.style.cssText = `
      position: fixed; inset: 0; z-index: 9999;
      background: rgba(0,0,0,0.6);
      display: flex; align-items: center; justify-content: center;
    `;

    overlay.innerHTML = `
      <div id="card-help-popup" style="
        background: var(--bg-surface);
        border: 1px solid var(--border);
        border-radius: 12px;
        padding: 32px;
        max-width: 560px;
        width: 90%;
        max-height: 80vh;
        overflow-y: auto;
        position: relative;
        box-shadow: 0 8px 40px rgba(0,0,0,0.6);
      ">
        <button id="card-help-close" style="
          position: absolute; top: 16px; right: 16px;
          background: none; border: none; color: var(--text-secondary);
          font-size: 1.3em; cursor: pointer; line-height: 1;
        ">X</button>
        <h2 style="margin-bottom: 8px;">How to Create a Card</h2>
        <p style="color:var(--text-secondary); margin-bottom: 24px; font-size:0.9em;">
          Cards now use explicit targeting and structured effects. Description text is only presentation.
        </p>
        <p style="color:var(--text-secondary); font-size:0.88em;">
          Use tokens like <code>{damage}</code>, <code>{block}</code>, or <code>{draw}</code> in the description to mirror the authored effects.
        </p>
      </div>
    `;

    overlay.addEventListener('click', event => {
      if (event.target === overlay) overlay.remove();
    });
    overlay.querySelector('#card-help-close').addEventListener('click', () => overlay.remove());
    document.body.appendChild(overlay);
  }

  render();
}
