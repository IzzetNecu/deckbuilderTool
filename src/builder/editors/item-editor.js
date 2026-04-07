import { store } from '../../data/store.js';
import { createItem } from '../../data/models.js';
import { showConfirmModal } from '../components/modal.js';

export function renderItemEditor(container) {
  let items = store.getAll('items');
  let selectedId = null;

  function render() {
    const selectedItem = items.find(i => i.id === selectedId) || null;

    container.innerHTML = `
      <div class="editor-header">
        <h2>Item Editor</h2>
        <button id="btn-create-item" class="primary">+ New Item</button>
      </div>
      <div class="editor-body split-pane">
        
        <!-- List Pane -->
        <div class="pane-list">
          <div class="item-list">
            ${items.map(i => `
              <div class="list-item ${i.id === selectedId ? 'selected' : ''}" data-id="${i.id}">
                <strong style="color: ${i.name ? 'inherit' : 'var(--text-secondary)'}">${i.name || 'Unnamed Item'}</strong>
                <div style="font-size: 0.8em; color: var(--text-secondary); margin-top: 4px;">
                  ${i.type} • Value: ${i.value}g
                </div>
              </div>
            `).join('')}
            ${items.length === 0 ? `<div style="padding:16px; color:var(--text-secondary); text-align:center;">No items created yet.</div>` : ''}
          </div>
        </div>

        <!-- Form Pane -->
        <div class="pane-form">
          ${selectedItem ? renderForm(selectedItem) : `<div class="empty-state">Select or create an item to edit.</div>`}
        </div>

      </div>
    `;

    attachEvents();
  }

  function renderForm(item) {
    return `
      <div style="max-width: 600px;">
        <div class="form-row">
          <div class="form-group">
            <label>Name</label>
            <input type="text" id="item-name" value="${item.name}" placeholder="e.g. Health Potion" />
          </div>
          <div class="form-group">
            <label>Gold Value</label>
            <input type="number" id="item-value" value="${item.value}" min="0" />
          </div>
        </div>
        
        <div class="form-row">
          <div class="form-group">
            <label>Type</label>
            <select id="item-type">
              <option value="consumable" ${item.type === 'consumable' ? 'selected' : ''}>Consumable</option>
              <option value="weapon" ${item.type === 'weapon' ? 'selected' : ''}>Weapon</option>
              <option value="armor" ${item.type === 'armor' ? 'selected' : ''}>Armor</option>
              <option value="key" ${item.type === 'key' ? 'selected' : ''}>Key Item</option>
            </select>
          </div>
          <div class="form-group">
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
          <label>Description</label>
          <textarea id="item-desc" rows="3">${item.description}</textarea>
        </div>

        <div class="form-group">
          <label>Mechanic Effects (Internal Logic)</label>
          <div class="dynamic-list" id="effects-list">
            ${item.effects.map((eff, index) => `
              <div class="dynamic-item">
                <input type="text" value="${eff}" class="effect-input" data-index="${index}" placeholder="e.g. HEAL:10 or STAT_MAXHP:5" />
                <button class="danger btn-remove-effect" data-index="${index}">X</button>
              </div>
            `).join('')}
            <div style="margin-top: 8px;">
              <button id="btn-add-effect">Add Effect</button>
            </div>
          </div>
        </div>

        <div style="margin-top: 32px; padding-top: 16px; border-top: 1px solid var(--border); display: flex; justify-content: space-between;">
          <button id="btn-delete-item" class="danger">Delete Item</button>
        </div>
      </div>
    `;
  }

  function attachEvents() {
    container.querySelector('#btn-create-item')?.addEventListener('click', () => {
      const i = createItem();
      store.save('items', i);
      items = store.getAll('items');
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
      const onChange = () => {
        const i = items.find(x => x.id === selectedId);
        i.name = container.querySelector('#item-name').value;
        i.value = parseInt(container.querySelector('#item-value').value, 10);
        i.type = container.querySelector('#item-type').value;
        i.rarity = container.querySelector('#item-rarity').value;
        i.description = container.querySelector('#item-desc').value;
        
        const effInputs = container.querySelectorAll('.effect-input');
        i.effects = Array.from(effInputs).map(inp => inp.value);

        store.save('items', i);
      };

      ['#item-name', '#item-value', '#item-desc'].forEach(id => {
         container.querySelector(id).addEventListener('blur', () => { onChange(); render(); });
      });
      ['#item-type', '#item-rarity'].forEach(id => {
         container.querySelector(id).addEventListener('change', () => { onChange(); render(); });
      });

      container.querySelectorAll('.effect-input').forEach(inp => {
        inp.addEventListener('change', onChange);
      });

      container.querySelector('#btn-add-effect').addEventListener('click', () => {
         const i = items.find(x => x.id === selectedId);
         i.effects.push('');
         store.save('items', i);
         render();
      });

      container.querySelectorAll('.btn-remove-effect').forEach(btn => {
         btn.addEventListener('click', (e) => {
            const index = parseInt(e.currentTarget.dataset.index);
            const i = items.find(x => x.id === selectedId);
            i.effects.splice(index, 1);
            store.save('items', i);
            render();
         });
      });

      container.querySelector('#btn-delete-item').addEventListener('click', () => {
        showConfirmModal('Are you sure you want to delete this item?', () => {
           store.remove('items', selectedId);
           items = store.getAll('items');
           selectedId = null;
           render();
        });
      });
    }
  }

  render();
}
