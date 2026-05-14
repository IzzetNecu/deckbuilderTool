import { store } from '../../data/store.js?v=1778179374';
import { createEnemy } from '../../data/models.js?v=1778179374';
import { showConfirmModal } from '../components/modal.js?v=1778179374';

export function renderEnemyEditor(container) {
  let enemies = store.getAll('enemies');
  let factions = store.getAll('factions');
  let allCards = store.getAll('cards');
  let deckTemplates = store.getAll('deckTemplates');
  let consumables = store.getAll('consumables');
  let equipment = store.getAll('equipment');
  let keyItems = store.getAll('keyItems');
  let allItems = [
    ...consumables.map(item => ({ ...item, _typeLabel: 'Consumable' })),
    ...equipment.map(item => ({ ...item, _typeLabel: 'Equipment' })),
    ...keyItems.map(item => ({ ...item, _typeLabel: 'Key Item' }))
  ];
  let selectedId = null;

  function render() {
    const selectedEnemy = enemies.find(enemy => enemy.id === selectedId) || null;
    const pane = container.querySelector('.pane-form');
    const scrollTop = pane ? pane.scrollTop : 0;

    container.innerHTML = `
      <div class="editor-header">
        <h2>Enemy Editor</h2>
        <button id="btn-create-enemy" class="primary">+ New Enemy</button>
      </div>
      <div class="editor-body split-pane">
        <div class="pane-list">
          <div class="item-list">
            ${enemies.map(enemy => `
              <div class="list-item ${enemy.id === selectedId ? 'selected' : ''}" data-id="${enemy.id}">
                <strong style="color:${enemy.name ? 'inherit' : 'var(--text-secondary)'}">${enemy.name || 'Unnamed Enemy'}</strong>
                <div style="font-size:0.8em; color:var(--text-secondary); margin-top:4px;">
                  HP: ${getStats(enemy).maxHealth} • Insight: ${getStats(enemy).insight}
                </div>
              </div>
            `).join('')}
            ${enemies.length === 0 ? `<div style="padding:16px; color:var(--text-secondary); text-align:center;">No enemies created yet.</div>` : ''}
          </div>
        </div>
        <div class="pane-form">
          ${selectedEnemy ? renderForm(selectedEnemy) : `<div class="empty-state">Select or create an enemy to edit.</div>`}
        </div>
      </div>
    `;

    attachEvents();
    requestAnimationFrame(() => {
      const nextPane = container.querySelector('.pane-form');
      if (nextPane) nextPane.scrollTop = scrollTop;
    });
  }

  function renderForm(enemy) {
    const stats = getStats(enemy);
    return `
      <div style="max-width:800px; display:flex; gap:32px;">
        <div style="flex:1;">
          <h3 style="margin-top:0;">Basic Properties</h3>
          <div class="form-row">
            <div class="form-group">
              <label>Name</label>
              <input type="text" id="enemy-name" value="${enemy.name}" placeholder="e.g. Bandit" />
            </div>
            <div class="form-group">
              <label>Cards Drawn / Round</label>
              <input type="number" id="enemy-hand-size" value="${enemy.handSize ?? enemy.hand_size ?? 2}" min="1" max="20" />
            </div>
          </div>

          <div class="form-row">
            <div class="form-group" style="flex:2;">
              <label>Portrait Image Path</label>
              <input type="text" id="enemy-portrait-image" value="${enemy.portraitImage || ''}" placeholder="e.g. assets/ui/enemy-portrait.png" />
            </div>
            <div class="form-group">
              <label>Upload Portrait</label>
              <input type="file" id="enemy-portrait-upload" accept="image/*" />
            </div>
          </div>

          <div class="form-row">
            <div class="form-group">
              <label>Max HP</label>
              <input type="number" id="enemy-hp" value="${stats.maxHealth}" min="1" />
            </div>
            <div class="form-group">
              <label>Strength</label>
              <input type="number" id="enemy-strength" value="${stats.strength}" min="0" />
            </div>
            <div class="form-group">
              <label>Dexterity</label>
              <input type="number" id="enemy-dexterity" value="${stats.dexterity}" min="0" />
            </div>
            <div class="form-group">
              <label>Insight</label>
              <input type="number" id="enemy-insight" value="${stats.insight}" min="0" />
            </div>
          </div>

          <div class="form-row">
            <div class="form-group">
              <label>Faction (Optional)</label>
              <select id="enemy-faction">
                <option value="">None / Neutral</option>
                ${factions.map(faction => `<option value="${faction.id}" ${enemy.factionId === faction.id ? 'selected' : ''}>${faction.name}</option>`).join('')}
              </select>
            </div>
            <div class="form-group">
              <label>Intent Mode</label>
              <select id="enemy-intent-mode">
                <option value="deck" ${enemy.intentMode === 'deck' ? 'selected' : ''}>Deck</option>
              </select>
            </div>
            <div class="form-group">
              <label>Intent Preview Baseline</label>
              <input type="number" id="enemy-intent-preview-count" value="${enemy.intentPreviewCount ?? 0}" min="0" />
            </div>
          </div>

          <div class="form-group">
            <label>Description</label>
            <textarea id="enemy-desc" rows="3">${enemy.description}</textarea>
          </div>

          <div style="margin-top:32px; padding-top:16px; border-top:1px solid var(--border);">
            <button id="btn-delete-enemy" class="danger">Delete Enemy</button>
          </div>
        </div>

        <div style="flex:1; border-left:1px solid var(--border); padding-left:32px;">
          <div class="form-group">
            <h3 style="margin-top:0;">Deck Templates</h3>
            <div class="dynamic-list">
              ${(enemy.deckTemplateIds || []).map((templateId, index) => `
                <div class="dynamic-item">
                  <select class="enemy-template-select" data-index="${index}" style="flex:1;">
                    <option value="">-- Select Template --</option>
                    ${deckTemplates.map(template => `<option value="${template.id}" ${template.id === templateId ? 'selected' : ''}>${template.name || 'Unnamed Template'}</option>`).join('')}
                  </select>
                  <button class="danger btn-remove-template" data-index="${index}">X</button>
                </div>
              `).join('')}
              <div style="margin-top:8px;">
                <button id="btn-add-template" ${deckTemplates.length === 0 ? 'disabled' : ''}>+ Add Deck Template</button>
              </div>
            </div>
          </div>

          <div class="form-group" style="margin-top:16px;">
            <h4 style="margin-top:0; color:var(--text-secondary); font-weight:normal;">Extra Individual Cards</h4>
            <div class="dynamic-list">
              ${(enemy.deckIds || []).map((cardId, index) => `
                <div class="dynamic-item">
                  <select class="enemy-deck-select" data-index="${index}" style="flex:1;">
                    <option value="">-- Select Card --</option>
                    ${allCards.map(card => `<option value="${card.id}" ${card.id === cardId ? 'selected' : ''}>${card.name || 'Unnamed Card'} (${card.type})</option>`).join('')}
                  </select>
                  <button class="danger btn-remove-deck-card" data-index="${index}">X</button>
                </div>
              `).join('')}
              <div style="margin-top:8px;">
                <button id="btn-add-deck-card" ${allCards.length === 0 ? 'disabled' : ''}>+ Add Card to Deck</button>
              </div>
            </div>
          </div>

          <div class="form-group" style="margin-top:32px;">
            <h3>Loot Drops</h3>
            <div class="dynamic-list">
              ${(enemy.lootTable || []).map((lootItem, index) => `
                <div style="border-bottom:1px solid var(--border); padding-bottom:8px; margin-bottom:8px;">
                  <div style="display:flex; gap:8px; margin-bottom:4px;">
                    <select class="loot-type-select" data-index="${index}" style="width:100px;">
                      <option value="item" ${lootItem.type === 'item' ? 'selected' : ''}>Item Drop</option>
                      <option value="gold" ${lootItem.type === 'gold' ? 'selected' : ''}>Gold Drop</option>
                    </select>
                    ${lootItem.type === 'item' ? `
                      <select class="loot-id-select" data-index="${index}" style="flex:1;">
                        <option value="">-- Select Item --</option>
                        ${allItems.map(item => `<option value="${item.id}" ${item.id === lootItem.id ? 'selected' : ''}>${item.name} (${item._typeLabel})</option>`).join('')}
                      </select>
                    ` : `
                      <input type="number" class="loot-amount-input" data-index="${index}" value="${lootItem.amount || 10}" style="flex:1;" placeholder="Amount" />
                    `}
                    <button class="danger btn-remove-loot" data-index="${index}">X</button>
                  </div>
                  <div style="display:flex; gap:8px; align-items:center;">
                    <label style="margin:0;">Drop Chance %</label>
                    <input type="number" class="loot-chance-input" data-index="${index}" value="${lootItem.chance || 100}" min="1" max="100" style="width:80px;" />
                  </div>
                </div>
              `).join('')}
              <div style="margin-top:8px;">
                <button id="btn-add-loot">+ Add Loot Entry</button>
              </div>
            </div>
          </div>
        </div>
      </div>
    `;
  }

  function attachEvents() {
    container.querySelector('#btn-create-enemy')?.addEventListener('click', () => {
      const enemy = createEnemy();
      store.save('enemies', enemy);
      enemies = store.getAll('enemies');
      selectedId = enemy.id;
      render();
    });

    container.querySelectorAll('.list-item').forEach(item => {
      item.addEventListener('click', event => {
        selectedId = event.currentTarget.dataset.id;
        render();
      });
    });

    if (!container.querySelector('#enemy-name')) return;

    const onChange = () => {
      const enemy = enemies.find(entry => entry.id === selectedId);
      if (!enemy) return;
      enemy.name = container.querySelector('#enemy-name').value;
      enemy.portraitImage = container.querySelector('#enemy-portrait-image').value;
      enemy.description = container.querySelector('#enemy-desc').value;
      enemy.factionId = container.querySelector('#enemy-faction').value;
      enemy.intentMode = container.querySelector('#enemy-intent-mode').value;
      enemy.intentPreviewCount = parseInt(container.querySelector('#enemy-intent-preview-count').value, 10) || 0;
      enemy.handSize = parseInt(container.querySelector('#enemy-hand-size').value, 10) || 2;
      enemy.hand_size = enemy.handSize;
      enemy.hp = parseInt(container.querySelector('#enemy-hp').value, 10) || 10;
      enemy.stats = {
        maxHealth: enemy.hp,
        strength: parseInt(container.querySelector('#enemy-strength').value, 10) || 0,
        dexterity: parseInt(container.querySelector('#enemy-dexterity').value, 10) || 0,
        insight: parseInt(container.querySelector('#enemy-insight').value, 10) || 0
      };
      enemy.deckTemplateIds = Array.from(container.querySelectorAll('.enemy-template-select')).map(select => select.value).filter(Boolean);
      enemy.deckIds = Array.from(container.querySelectorAll('.enemy-deck-select')).map(select => select.value).filter(Boolean);
      enemy.lootTable = Array.from(container.querySelectorAll('.loot-type-select')).map(select => {
        const index = select.dataset.index;
        const type = select.value;
        const chance = parseInt(container.querySelector(`.loot-chance-input[data-index="${index}"]`).value, 10);
        const entry = { type, chance: isNaN(chance) ? 100 : chance };
        if (type === 'item') {
          entry.id = container.querySelector(`.loot-id-select[data-index="${index}"]`)?.value || '';
        } else {
          entry.amount = parseInt(container.querySelector(`.loot-amount-input[data-index="${index}"]`)?.value ?? 10, 10) || 10;
        }
        return entry;
      });
      store.save('enemies', enemy);
    };

    container.querySelectorAll('input, textarea, select').forEach(field => {
      field.addEventListener('change', () => {
        onChange();
        render();
      });
      field.addEventListener('blur', onChange);
    });

    container.querySelector('#enemy-portrait-upload')?.addEventListener('change', async event => {
      const file = event.target.files[0];
      if (!file) return;
      try {
        await fetch('/upload-image', {
          method: 'POST',
          headers: {
            'X-Filename': file.name,
            'X-Upload-Subdir': 'ui'
          },
          body: file
        });
        const enemy = enemies.find(entry => entry.id === selectedId);
        enemy.portraitImage = `assets/ui/${file.name}`;
        store.save('enemies', enemy);
        render();
      } catch (err) {
        alert('Upload failed. Make sure the python server is running.');
      }
    });

    container.querySelector('#btn-add-template')?.addEventListener('click', () => {
      const enemy = enemies.find(entry => entry.id === selectedId);
      enemy.deckTemplateIds = enemy.deckTemplateIds || [];
      enemy.deckTemplateIds.push('');
      store.save('enemies', enemy);
      render();
    });

    container.querySelectorAll('.btn-remove-template').forEach(button => {
      button.addEventListener('click', event => {
        const enemy = enemies.find(entry => entry.id === selectedId);
        enemy.deckTemplateIds.splice(parseInt(event.currentTarget.dataset.index, 10), 1);
        store.save('enemies', enemy);
        render();
      });
    });

    container.querySelector('#btn-add-deck-card')?.addEventListener('click', () => {
      const enemy = enemies.find(entry => entry.id === selectedId);
      enemy.deckIds = enemy.deckIds || [];
      enemy.deckIds.push('');
      store.save('enemies', enemy);
      render();
    });

    container.querySelectorAll('.btn-remove-deck-card').forEach(button => {
      button.addEventListener('click', event => {
        const enemy = enemies.find(entry => entry.id === selectedId);
        enemy.deckIds.splice(parseInt(event.currentTarget.dataset.index, 10), 1);
        store.save('enemies', enemy);
        render();
      });
    });

    container.querySelector('#btn-add-loot')?.addEventListener('click', () => {
      const enemy = enemies.find(entry => entry.id === selectedId);
      enemy.lootTable = enemy.lootTable || [];
      enemy.lootTable.push({ type: 'item', id: '', chance: 100 });
      store.save('enemies', enemy);
      render();
    });

    container.querySelectorAll('.btn-remove-loot').forEach(button => {
      button.addEventListener('click', event => {
        const enemy = enemies.find(entry => entry.id === selectedId);
        enemy.lootTable.splice(parseInt(event.currentTarget.dataset.index, 10), 1);
        store.save('enemies', enemy);
        render();
      });
    });

    container.querySelector('#btn-delete-enemy')?.addEventListener('click', () => {
      showConfirmModal('Are you sure you want to delete this enemy?', () => {
        store.remove('enemies', selectedId);
        enemies = store.getAll('enemies');
        selectedId = null;
        render();
      });
    });
  }

  function getStats(enemy) {
    return {
      maxHealth: enemy.stats?.maxHealth ?? enemy.hp ?? 10,
      strength: enemy.stats?.strength ?? 0,
      dexterity: enemy.stats?.dexterity ?? 0,
      insight: enemy.stats?.insight ?? 0
    };
  }

  render();
}
