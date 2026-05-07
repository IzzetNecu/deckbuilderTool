import { store } from '../../data/store.js?v=1778159200';
import { createKeyItem } from '../../data/models.js?v=1778159200';
import { showConfirmModal } from '../components/modal.js?v=1778159200';

export function renderKeyItemEditor(container) {
  let keyItems = store.getAll('keyItems');
  let selectedId = null;

  function render() {
    const selectedItem = keyItems.find(i => i.id === selectedId) || null;

    container.innerHTML = `
      <div class="editor-header">
        <h2>Key Items Editor</h2>
        <button id="btn-create-item" class="primary">+ New Key Item</button>
      </div>
      <div class="editor-body split-pane">
        
        <!-- List Pane -->
        <div class="pane-list">
          <div class="item-list">
            ${keyItems.map(i => `
              <div class="list-item ${i.id === selectedId ? 'selected' : ''}" data-id="${i.id}">
                <strong style="color: ${i.name ? 'inherit' : 'var(--text-secondary)'}">${i.name || 'Unnamed Key Item'}</strong>
              </div>
            `).join('')}
            ${keyItems.length === 0 ? `<div style="padding:16px; color:var(--text-secondary); text-align:center;">No key items created yet.</div>` : ''}
          </div>
        </div>

        <!-- Form Pane -->
        <div class="pane-form">
          ${selectedItem ? renderForm(selectedItem) : `<div class="empty-state">Select or create a key item to edit.</div>`}
        </div>

      </div>
    `;

    attachEvents();
  }

  function renderForm(item) {
    return `
      <div style="max-width: 600px;">
        <div class="form-group">
          <label>Name</label>
          <input type="text" id="item-name" value="${item.name}" placeholder="e.g. Dungeon Key" />
        </div>

        <div class="form-group">
          <label>Description</label>
          <textarea id="item-desc" rows="4">${item.description}</textarea>
        </div>

        <div style="margin-top: 32px; padding-top: 16px; border-top: 1px solid var(--border); display: flex; justify-content: space-between;">
          <button id="btn-delete-item" class="danger">Delete Key Item</button>
        </div>
      </div>
    `;
  }

  function attachEvents() {
    container.querySelector('#btn-create-item')?.addEventListener('click', () => {
      const i = createKeyItem();
      store.save('keyItems', i);
      keyItems = store.getAll('keyItems');
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
        const i = keyItems.find(x => x.id === selectedId);
        i.name = container.querySelector('#item-name').value;
        i.description = container.querySelector('#item-desc').value;
        store.save('keyItems', i);
      };

      ['#item-name', '#item-desc'].forEach(id => {
         container.querySelector(id).addEventListener('blur', () => { onChange(); render(); });
      });

      container.querySelector('#btn-delete-item').addEventListener('click', () => {
        showConfirmModal('Are you sure you want to delete this key item?', () => {
           store.remove('keyItems', selectedId);
           keyItems = store.getAll('keyItems');
           selectedId = null;
           render();
        });
      });
    }
  }

  render();
}
