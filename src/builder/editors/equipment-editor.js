import { store } from '../../data/store.js?v=1778169189';
import { createEquipment, createEquipmentCondition } from '../../data/models.js?v=1778169189';
import { showConfirmModal } from '../components/modal.js?v=1778169189';

export function renderEquipmentEditor(container) {
  let equipment = store.getAll('equipment');
  let cards = store.getAll('cards');
  let selectedId = null;

  const STATS = ['health', 'strength', 'dexterity', 'energy', 'handsize'];

  function render() {
    const selectedItem = equipment.find(i => i.id === selectedId) || null;

    container.innerHTML = `
      <div class="editor-header">
        <h2>Equipment Editor</h2>
        <button id="btn-create-item" class="primary">+ New Equipment</button>
      </div>
      <div class="editor-body split-pane">
        
        <!-- List Pane -->
        <div class="pane-list">
          <div class="item-list">
            ${equipment.map(i => `
              <div class="list-item ${i.id === selectedId ? 'selected' : ''}" data-id="${i.id}">
                <strong style="color: ${i.name ? 'inherit' : 'var(--text-secondary)'}">${i.name || 'Unnamed Equipment'}</strong>
                <div style="font-size: 0.8em; color: var(--text-secondary); margin-top: 4px;">
                  ${i.type} • Value: ${i.value}g
                </div>
              </div>
            `).join('')}
            ${equipment.length === 0 ? `<div style="padding:16px; color:var(--text-secondary); text-align:center;">No equipment created yet.</div>` : ''}
          </div>
        </div>

        <!-- Form Pane -->
        <div class="pane-form">
          ${selectedItem ? renderForm(selectedItem) : `<div class="empty-state">Select or create equipment to edit.</div>`}
        </div>

      </div>
    `;

    attachEvents();
  }

  function renderForm(item) {
    if (!item.cardIds) item.cardIds = [];
    if (!item.conditions) item.conditions = [];

    return `
      <div style="max-width: 800px; display:flex; gap:32px;">
        <!-- Left Column: Basic Info -->
        <div style="flex: 1;">
          <div class="form-row">
            <div class="form-group">
              <label>Name</label>
              <input type="text" id="item-name" value="${item.name}" placeholder="e.g. Iron Sword" />
            </div>
          </div>
          
          <div class="form-row">
            <div class="form-group" style="width:50%;">
              <label>Gold Value</label>
              <input type="number" id="item-value" value="${item.value}" min="0" />
            </div>
            <div class="form-group" style="width:50%;">
              <label>Rarity</label>
              <select id="item-rarity">
                <option value="common" ${item.rarity === 'common' ? 'selected' : ''}>Common</option>
                <option value="uncommon" ${item.rarity === 'uncommon' ? 'selected' : ''}>Uncommon</option>
                <option value="rare" ${item.rarity === 'rare' ? 'selected' : ''}>Rare</option>
                <option value="legendary" ${item.rarity === 'legendary' ? 'selected' : ''}>Legendary</option>
              </select>
            </div>
          </div>
          
          <div class="form-group">
            <label>Equipment Slot Type</label>
            <select id="item-type">
              <option value="onehandedWeapon" ${item.type === 'onehandedWeapon' ? 'selected' : ''}>One-Handed Weapon</option>
              <option value="twohandedWeapon" ${item.type === 'twohandedWeapon' ? 'selected' : ''}>Two-Handed Weapon</option>
              <option value="offHand" ${item.type === 'offHand' ? 'selected' : ''}>Off-Hand (Shield/Tome)</option>
              <option value="head" ${item.type === 'head' ? 'selected' : ''}>Head</option>
              <option value="armor" ${item.type === 'armor' ? 'selected' : ''}>Armor</option>
              <option value="legs" ${item.type === 'legs' ? 'selected' : ''}>Legs</option>
              <option value="ring" ${item.type === 'ring' ? 'selected' : ''}>Ring</option>
              <option value="amulet" ${item.type === 'amulet' ? 'selected' : ''}>Amulet</option>
            </select>
          </div>

          <div class="form-group">
            <label>Description</label>
            <textarea id="item-desc" rows="3">${item.description}</textarea>
          </div>

          <div class="form-group" style="margin-top: 16px;">
            <label>Passive Mechanic Effects</label>
            <div class="dynamic-list" id="effects-list">
              ${item.effects.map((eff, index) => `
                <div class="dynamic-item">
                  <input type="text" value="${eff}" class="effect-input" data-index="${index}" placeholder="e.g. STAT_STRENGTH:1" />
                  <button class="danger btn-remove-effect" data-index="${index}">X</button>
                </div>
              `).join('')}
              <div style="margin-top: 8px;">
                <button id="btn-add-effect">+ Add Effect</button>
              </div>
            </div>
          </div>

          <div style="margin-top: 32px; padding-top: 16px; border-top: 1px solid var(--border);">
            <button id="btn-delete-item" class="danger">Delete Equipment</button>
          </div>
        </div>

        <!-- Right Column: Cards & Conditions -->
        <div style="flex: 1; border-left: 1px solid var(--border); padding-left: 32px;">
          
          <!-- Associated Cards -->
          <div class="form-group">
            <label style="color:#87ceeb);">Cards Added While Equipped</label>
            <div style="background: var(--bg-surface); border: 1px solid var(--border); border-radius: 4px; padding: 8px; margin-bottom: 8px;">
              ${item.cardIds.length === 0 ? '<div style="color:var(--text-secondary); font-size:0.9em;">No cards assigned.</div>' : ''}
              ${item.cardIds.map((cid, idx) => {
                 const c = cards.find(x => x.id === cid);
                 return `
                   <div style="display:flex; justify-content:space-between; margin-bottom: 4px;">
                     <span>${c ? c.name : 'Unknown Card'}</span>
                     <button class="danger btn-remove-card" data-idx="${idx}" style="padding: 2px 6px;">X</button>
                   </div>
                 `;
              }).join('')}
            </div>
            <div style="display:flex; gap: 8px;">
              <select id="select-add-card" style="flex:1;">
                 <option value="">-- Add Card --</option>
                 ${cards.map(c => `<option value="${c.id}">${c.name}</option>`).join('')}
              </select>
              <button id="btn-add-card">Add</button>
            </div>
          </div>

          <!-- Conditions -->
          <div class="form-group" style="margin-top: 32px;">
            <label style="color:var(--accent);">Equip Requirements (Conditions)</label>
            ${item.conditions.length === 0 ? '<div style="color:var(--text-secondary); font-size:0.9em; margin-bottom: 8px;">No requirements.</div>' : ''}
            
            ${item.conditions.map((cond, idx) => `
               <div style="background: var(--bg-surface); padding: 8px; border: 1px solid var(--border); margin-bottom: 8px; border-radius: 4px;">
                  <div style="display:flex; gap: 4px; margin-bottom:4px;">
                     <select class="cond-type" data-idx="${idx}" style="width: 100%;">
                       <option value="hasStat" ${cond.type === 'hasStat' ? 'selected' : ''}>Requires Stat</option>
                     </select>
                     <button class="danger btn-remove-cond" data-idx="${idx}">X</button>
                  </div>
                  <div style="display:flex; gap: 4px;">
                     ${cond.type === 'hasStat' ? `
                       <select class="cond-target" data-idx="${idx}" style="flex:1;">
                         ${STATS.map(s => `<option value="${s}" ${cond.target === s ? 'selected' : ''}>${s}</option>`).join('')}
                       </select>
                     ` : ''}
                     <select class="cond-operator" data-idx="${idx}" style="width: 50px;">
                        <option value=">=" ${cond.operator === '>=' ? 'selected' : ''}>&gt;=</option>
                        <option value="<=" ${cond.operator === '<=' ? 'selected' : ''}>&lt;=</option>
                        <option value="==" ${cond.operator === '==' ? 'selected' : ''}>==</option>
                     </select>
                     <input type="text" class="cond-val" data-idx="${idx}" value="${cond.value}" placeholder="Val" style="width: 60px;" />
                  </div>
               </div>
            `).join('')}
            <button id="btn-add-cond" style="margin-top: 8px;">+ Add Requirement</button>
          </div>

        </div>
      </div>
    `;
  }

  function attachEvents() {
    container.querySelector('#btn-create-item')?.addEventListener('click', () => {
      const i = createEquipment();
      store.save('equipment', i);
      equipment = store.getAll('equipment');
      selectedId = i.id;
      render();
    });

    container.querySelectorAll('.list-item').forEach(el => {
      el.addEventListener('click', (e) => {
        selectedId = e.currentTarget.dataset.id;
        render();
      });
    });

    const nameInput = container.querySelector('#item-name');
    if (nameInput) {
      const saveItem = () => {
        const i = equipment.find(x => x.id === selectedId);
        i.name = container.querySelector('#item-name').value;
        i.value = parseInt(container.querySelector('#item-value').value, 10);
        i.type = container.querySelector('#item-type').value;
        i.rarity = container.querySelector('#item-rarity').value;
        i.description = container.querySelector('#item-desc').value;
        
        const effInputs = container.querySelectorAll('.effect-input');
        i.effects = Array.from(effInputs).map(inp => inp.value);

        // Conditions
        container.querySelectorAll('.cond-type').forEach(sel => {
           const idx = parseInt(sel.dataset.idx);
           const cond = i.conditions[idx];
           cond.type = sel.value;
           cond.operator = container.querySelector(`.cond-operator[data-idx="${idx}"]`).value;
           cond.value = container.querySelector(`.cond-val[data-idx="${idx}"]`).value;
           cond.target = container.querySelector(`.cond-target[data-idx="${idx}"]`).value;
        });

        store.save('equipment', i);
      };

      ['#item-name', '#item-value', '#item-desc'].forEach(id => {
         container.querySelector(id).addEventListener('blur', () => { saveItem(); render(); });
      });
      ['#item-type', '#item-rarity'].forEach(id => {
         container.querySelector(id).addEventListener('change', () => { saveItem(); render(); });
      });

      container.querySelectorAll('.effect-input, .cond-val').forEach(inp => {
        inp.addEventListener('blur', () => { saveItem(); render(); });
      });
      container.querySelectorAll('.cond-type, .cond-target, .cond-operator').forEach(sel => {
        sel.addEventListener('change', () => { saveItem(); render(); });
      });

      // Arrays add/remove
      container.querySelector('#btn-add-effect').addEventListener('click', () => {
         const i = equipment.find(x => x.id === selectedId);
         i.effects.push('');
         store.save('equipment', i);
         render();
      });

      container.querySelectorAll('.btn-remove-effect').forEach(btn => {
         btn.addEventListener('click', (e) => {
            const index = parseInt(e.currentTarget.dataset.index);
            const i = equipment.find(x => x.id === selectedId);
            i.effects.splice(index, 1);
            store.save('equipment', i);
            render();
         });
      });

      container.querySelector('#btn-add-card').addEventListener('click', () => {
         const val = container.querySelector('#select-add-card').value;
         if (!val) return;
         const i = equipment.find(x => x.id === selectedId);
         i.cardIds.push(val);
         store.save('equipment', i);
         render();
      });

      container.querySelectorAll('.btn-remove-card').forEach(btn => {
         btn.addEventListener('click', (e) => {
            const index = parseInt(e.currentTarget.dataset.idx);
            const i = equipment.find(x => x.id === selectedId);
            i.cardIds.splice(index, 1);
            store.save('equipment', i);
            render();
         });
      });

      container.querySelector('#btn-add-cond').addEventListener('click', () => {
         const i = equipment.find(x => x.id === selectedId);
         i.conditions.push(createEquipmentCondition());
         store.save('equipment', i);
         render();
      });

      container.querySelectorAll('.btn-remove-cond').forEach(btn => {
         btn.addEventListener('click', (e) => {
            const index = parseInt(e.currentTarget.dataset.idx);
            const i = equipment.find(x => x.id === selectedId);
            i.conditions.splice(index, 1);
            store.save('equipment', i);
            render();
         });
      });

      container.querySelector('#btn-delete-item').addEventListener('click', () => {
        showConfirmModal('Are you sure you want to delete this equipment?', () => {
           store.remove('equipment', selectedId);
           equipment = store.getAll('equipment');
           selectedId = null;
           render();
        });
      });
    }
  }

  render();
}
