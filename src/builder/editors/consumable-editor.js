import { store } from '../../data/store.js?v=1778160185';
import { createConsumable } from '../../data/models.js?v=1778160185';
import { showConfirmModal } from '../components/modal.js?v=1778160185';

export function renderConsumableEditor(container) {
  let consumables = store.getAll('consumables');
  let selectedId = null;

  function render() {
    const selectedItem = consumables.find(i => i.id === selectedId) || null;

    container.innerHTML = `
      <div class="editor-header">
        <h2>Consumables Editor</h2>
        <button id="btn-create-item" class="primary">+ New Consumable</button>
      </div>
      <div class="editor-body split-pane">
        
        <!-- List Pane -->
        <div class="pane-list">
          <div class="item-list">
            ${consumables.map(i => `
              <div class="list-item ${i.id === selectedId ? 'selected' : ''}" data-id="${i.id}">
                <strong style="color: ${i.name ? 'inherit' : 'var(--text-secondary)'}">${i.name || 'Unnamed Consumable'}</strong>
                <div style="font-size: 0.8em; color: var(--text-secondary); margin-top: 4px;">
                  Value: ${i.value}g • ${i.rarity}
                </div>
              </div>
            `).join('')}
            ${consumables.length === 0 ? `<div style="padding:16px; color:var(--text-secondary); text-align:center;">No consumables created yet.</div>` : ''}
          </div>
        </div>

        <!-- Form Pane -->
        <div class="pane-form">
          ${selectedItem ? renderForm(selectedItem) : `<div class="empty-state">Select or create a consumable to edit.</div>`}
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
          <button id="btn-delete-item" class="danger">Delete Consumable</button>
        </div>
      </div>
    `;
  }

  function attachEvents() {
    container.querySelector('#btn-create-item')?.addEventListener('click', () => {
      const i = createConsumable();
      store.save('consumables', i);
      consumables = store.getAll('consumables');
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
        const i = consumables.find(x => x.id === selectedId);
        i.name = container.querySelector('#item-name').value;
        i.value = parseInt(container.querySelector('#item-value').value, 10);
        i.rarity = container.querySelector('#item-rarity').value;
        i.description = container.querySelector('#item-desc').value;
        
        const effInputs = container.querySelectorAll('.effect-input');
        i.effects = Array.from(effInputs).map(inp => inp.value);

        store.save('consumables', i);
      };

      ['#item-name', '#item-value', '#item-desc'].forEach(id => {
         container.querySelector(id).addEventListener('blur', () => { onChange(); render(); });
      });
      container.querySelector('#item-rarity').addEventListener('change', () => { onChange(); render(); });

      container.querySelectorAll('.effect-input').forEach(inp => {
        inp.addEventListener('blur', () => { onChange(); render(); });
      });

      container.querySelector('#btn-add-effect').addEventListener('click', () => {
         const i = consumables.find(x => x.id === selectedId);
         i.effects.push('');
         store.save('consumables', i);
         render();
      });

      container.querySelectorAll('.btn-remove-effect').forEach(btn => {
         btn.addEventListener('click', (e) => {
            const index = parseInt(e.currentTarget.dataset.index);
            const i = consumables.find(x => x.id === selectedId);
            i.effects.splice(index, 1);
            store.save('consumables', i);
            render();
         });
      });

      container.querySelector('#btn-delete-item').addEventListener('click', () => {
        showConfirmModal('Are you sure you want to delete this consumable?', () => {
           store.remove('consumables', selectedId);
           consumables = store.getAll('consumables');
           selectedId = null;
           render();
        });
      });
    }
  }

  render();
}
