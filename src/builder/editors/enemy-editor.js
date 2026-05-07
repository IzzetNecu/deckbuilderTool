import { store } from '../../data/store.js?v=1778177534';
import { createEnemy } from '../../data/models.js?v=1778177534';
import { showConfirmModal } from '../components/modal.js?v=1778177534';

export function renderEnemyEditor(container) {
  let enemies = store.getAll('enemies');
  let factions = store.getAll('factions');
  let allCards = store.getAll('cards');
  let deckTemplates = store.getAll('deckTemplates');
  
  let consumables = store.getAll('consumables');
  let equipment = store.getAll('equipment');
  let keyItems = store.getAll('keyItems');
  
  let allItems = [
    ...consumables.map(c => ({...c, _typeLabel: 'Consumable'})),
    ...equipment.map(e => ({...e, _typeLabel: 'Equipment'})),
    ...keyItems.map(k => ({...k, _typeLabel: 'Key Item'}))
  ];
  let selectedId = null;

  function render() {
    const selectedEnemy = enemies.find(e => e.id === selectedId) || null;

    container.innerHTML = `
      <div class="editor-header">
        <h2>Enemy Editor</h2>
        <button id="btn-create-enemy" class="primary">+ New Enemy</button>
      </div>
      <div class="editor-body split-pane">
        
        <!-- List Pane -->
        <div class="pane-list">
          <div class="item-list">
            ${enemies.map(e => `
              <div class="list-item ${e.id === selectedId ? 'selected' : ''}" data-id="${e.id}">
                <strong style="color: ${e.name ? 'inherit' : 'var(--text-secondary)'}">${e.name || 'Unnamed Enemy'}</strong>
                <div style="font-size: 0.8em; color: var(--text-secondary); margin-top: 4px;">
                  HP: ${e.hp}
                </div>
              </div>
            `).join('')}
            ${enemies.length === 0 ? `<div style="padding:16px; color:var(--text-secondary); text-align:center;">No enemies created yet.</div>` : ''}
          </div>
        </div>

        <!-- Form Pane -->
        <div class="pane-form">
          ${selectedEnemy ? renderForm(selectedEnemy) : `<div class="empty-state">Select or create an enemy to edit.</div>`}
        </div>

      </div>
    `;

    attachEvents();
  }

  function renderForm(enemy) {
    return `
      <div style="max-width: 800px; display: flex; gap: 32px;">
        <!-- Left Column: Core Stats -->
        <div style="flex: 1;">
          <h3 style="margin-top:0;">Basic Properties</h3>
          <div class="form-row">
            <div class="form-group">
              <label>Name</label>
              <input type="text" id="enemy-name" value="${enemy.name}" placeholder="e.g. Goblin" />
            </div>
            <div class="form-group">
              <label>Max HP</label>
              <input type="number" id="enemy-hp" value="${enemy.hp}" min="1" />
            </div>
            <div class="form-group">
              <label>Cards Drawn / Turn</label>
              <input type="number" id="enemy-hand-size" value="${enemy.hand_size ?? 3}" min="1" max="20" />
            </div>
          </div>

          <div class="form-group">
            <label>Faction (Optional)</label>
            <select id="enemy-faction">
              <option value="">None / Neutral</option>
              ${factions.map(f => `<option value="${f.id}" ${enemy.factionId === f.id ? 'selected' : ''}>${f.name}</option>`).join('')}
            </select>
          </div>

          <div class="form-group">
            <label>Description</label>
            <textarea id="enemy-desc" rows="3">${enemy.description}</textarea>
          </div>

          <div style="margin-top: 32px; padding-top: 16px; border-top: 1px solid var(--border);">
            <button id="btn-delete-enemy" class="danger">Delete Enemy</button>
          </div>
        </div>

        <!-- Right Column: Deck & Loot -->
        <div style="flex: 1; border-left: 1px solid var(--border); padding-left: 32px;">
          
          <!-- Enemy Deck Templates -->
          <div class="form-group">
            <h3 style="margin-top:0;">Deck Templates</h3>
            <label style="font-size:0.8em; color:var(--text-secondary);">All cards from selected templates are added to the enemy's deck.</label>
            <div class="dynamic-list" id="enemy-template-list" style="max-height:160px; overflow-y:auto; margin-top:6px;">
              ${(enemy.deckTemplateIds || []).map((tId, index) => {
                return `
                  <div class="dynamic-item">
                    <select class="enemy-template-select" data-index="${index}" style="flex:1;">
                      <option value="">-- Select Template --</option>
                      ${deckTemplates.map(t => `<option value="${t.id}" ${t.id === tId ? 'selected' : ''}>${t.name || 'Unnamed Template'}</option>`).join('')}
                    </select>
                    <button class="danger btn-remove-template" data-index="${index}">X</button>
                  </div>`;
              }).join('')}
              <div style="margin-top:8px;">
                <button id="btn-add-template" ${deckTemplates.length === 0 ? 'disabled title="No deck templates created yet"' : ''}>+ Add Deck Template</button>
              </div>
            </div>
          </div>

          <!-- Enemy Individual Cards -->
          <div class="form-group" style="margin-top:16px;">
             <h4 style="margin-top:0; color:var(--text-secondary); font-weight:normal;">Extra Individual Cards</h4>
             <label style="font-size: 0.8em; color:var(--text-secondary);">Additional cards on top of any templates.</label>
             <div class="dynamic-list" id="enemy-deck-list" style="max-height: 160px; overflow-y:auto;">
               ${enemy.deckIds.map((cId, index) => {
                 const card = allCards.find(c => c.id === cId);
                 return `
                    <div class="dynamic-item">
                      <select class="enemy-deck-select" data-index="${index}" style="flex:1;">
                        <option value="">-- Select Card --</option>
                        ${allCards.map(c => `<option value="${c.id}" ${c.id === cId ? 'selected' : ''}>${c.name} (${c.type})</option>`).join('')}
                      </select>
                      <button class="danger btn-remove-deck-card" data-index="${index}">X</button>
                    </div>
                 `;
               }).join('')}
               <div style="margin-top: 8px;">
                 <button id="btn-add-deck-card" ${allCards.length === 0 ? 'disabled' : ''}>+ Add Card to Deck</button>
               </div>
             </div>
          </div>

          <!-- Loot Table -->
          <div class="form-group" style="margin-top: 32px;">
             <h3>Loot Drops</h3>
             <label style="font-size: 0.8em; color:var(--text-secondary);">Guaranteed or chance drops on defeat.</label>
             <div class="dynamic-list" id="enemy-loot-list" style="max-height: 200px; overflow-y:auto;">
               ${enemy.lootTable.map((lootItem, index) => {
                 // lootItem is { type: "item"|"gold", id: itemId, amount: number, chance: number }
                 return `
                   <div style="border-bottom: 1px solid var(--border); padding-bottom: 8px; margin-bottom: 8px;">
                     <div style="display:flex; gap:8px; margin-bottom:4px;">
                        <select class="loot-type-select" data-index="${index}" style="width: 100px;">
                          <option value="item" ${lootItem.type === 'item' ? 'selected' : ''}>Item Drop</option>
                          <option value="gold" ${lootItem.type === 'gold' ? 'selected' : ''}>Gold Drop</option>
                        </select>
                        ${lootItem.type === 'item' ? `
                          <select class="loot-id-select" data-index="${index}" style="flex:1;">
                            <option value="">-- Select Item --</option>
                            ${allItems.length === 0 ? '<option value="">No items available</option>' : allItems.map(i => `<option value="${i.id}" ${i.id === lootItem.id ? 'selected' : ''}>${i.name} (${i._typeLabel})</option>`).join('')}
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
                 `;
               }).join('')}
               <div style="margin-top: 8px;">
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
      const e = createEnemy();
      store.save('enemies', e);
      enemies = store.getAll('enemies');
      selectedId = e.id;
      render();
    });

    container.querySelectorAll('.list-item').forEach(el => {
      el.addEventListener('click', (e) => {
        selectedId = e.currentTarget.dataset.id;
        render();
      });
    });

    const nameInput = container.querySelector('#enemy-name');
    if (nameInput) {
      const onChange = () => {
        const e = enemies.find(x => x.id === selectedId);
        e.name = container.querySelector('#enemy-name').value;
        e.hp = parseInt(container.querySelector('#enemy-hp').value, 10);
        e.hand_size = parseInt(container.querySelector('#enemy-hand-size').value, 10) || 3;
        e.factionId = container.querySelector('#enemy-faction').value;
        e.description = container.querySelector('#enemy-desc').value;
        
        // Build deckTemplateIds
        const templateInputs = container.querySelectorAll('.enemy-template-select');
        e.deckTemplateIds = Array.from(templateInputs).map(inp => inp.value).filter(v => v);

        // Build individual deck cards
        const deckInputs = container.querySelectorAll('.enemy-deck-select');
        e.deckIds = Array.from(deckInputs).map(inp => inp.value).filter(v => v);

        // Build loot table
        const lootBlocks = container.querySelectorAll('.loot-type-select');
        e.lootTable = Array.from(lootBlocks).map(sel => {
           const idx = sel.dataset.index;
           const type = sel.value;
           const chance = parseInt(container.querySelector(`.loot-chance-input[data-index="${idx}"]`).value, 10);
           const entry = { type, chance: isNaN(chance) ? 100 : chance };
           if (type === 'item') {
              const idSel = container.querySelector(`.loot-id-select[data-index="${idx}"]`);
              entry.id = idSel ? idSel.value : '';
           } else {
              const amtInp = container.querySelector(`.loot-amount-input[data-index="${idx}"]`);
              entry.amount = amtInp ? parseInt(amtInp.value, 10) : 10;
           }
           return entry;
        });

        store.save('enemies', e);
      };

      ['#enemy-name', '#enemy-hp', '#enemy-hand-size', '#enemy-desc'].forEach(id => {
         container.querySelector(id).addEventListener('blur', () => { onChange(); render(); });
      });
      container.querySelector('#enemy-faction').addEventListener('change', () => { onChange(); render(); });
      
      container.querySelectorAll('.enemy-deck-select, .enemy-template-select, .loot-type-select, .loot-id-select, .loot-amount-input, .loot-chance-input').forEach(inp => {
          inp.addEventListener('change', () => { onChange(); render(); });
      });

      container.querySelector('#btn-add-template')?.addEventListener('click', () => {
         const e = enemies.find(x => x.id === selectedId);
         if (!e.deckTemplateIds) e.deckTemplateIds = [];
         e.deckTemplateIds.push('');
         store.save('enemies', e);
         render();
      });

      container.querySelectorAll('.btn-remove-template').forEach(btn => {
         btn.addEventListener('click', (ev) => {
            const index = parseInt(ev.currentTarget.dataset.index);
            const e = enemies.find(x => x.id === selectedId);
            e.deckTemplateIds.splice(index, 1);
            store.save('enemies', e);
            render();
         });
      });

      container.querySelector('#btn-add-deck-card')?.addEventListener('click', () => {
         const e = enemies.find(x => x.id === selectedId);
         e.deckIds.push('');
         store.save('enemies', e);
         render();
      });

      container.querySelectorAll('.btn-remove-deck-card').forEach(btn => {
         btn.addEventListener('click', (ev) => {
            const index = parseInt(ev.currentTarget.dataset.index);
            const e = enemies.find(x => x.id === selectedId);
            e.deckIds.splice(index, 1);
            store.save('enemies', e);
            render();
         });
      });

      container.querySelector('#btn-add-loot')?.addEventListener('click', () => {
         const e = enemies.find(x => x.id === selectedId);
         e.lootTable.push({ type: 'item', id: '', chance: 100 });
         store.save('enemies', e);
         render();
      });

      container.querySelectorAll('.btn-remove-loot').forEach(btn => {
         btn.addEventListener('click', (ev) => {
            const index = parseInt(ev.currentTarget.dataset.index);
            const e = enemies.find(x => x.id === selectedId);
            e.lootTable.splice(index, 1);
            store.save('enemies', e);
            render();
         });
      });

      container.querySelector('#btn-delete-enemy').addEventListener('click', () => {
        showConfirmModal('Are you sure you want to delete this enemy?', () => {
           store.remove('enemies', selectedId);
           enemies = store.getAll('enemies');
           selectedId = null;
           render();
        });
      });
    }
  }

  render();
}
