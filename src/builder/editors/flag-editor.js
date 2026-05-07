import { store } from '../../data/store.js?v=1778176485';
import { createFlag } from '../../data/models.js?v=1778176485';
import { showConfirmModal } from '../components/modal.js?v=1778176485';

export function renderFlagEditor(container) {
  let flags = store.getAll('flags');
  let selectedId = null;

  function render() {
    const selectedFlag = flags.find(f => f.id === selectedId) || null;

    container.innerHTML = `
      <div class="editor-header">
        <h2>Flag Editor</h2>
        <button id="btn-create-flag" class="primary">+ New Flag</button>
      </div>
      <div class="editor-body split-pane">
        
        <!-- List Pane -->
        <div class="pane-list">
          <div class="item-list">
            ${flags.map(f => `
              <div class="list-item ${f.id === selectedId ? 'selected' : ''}" data-id="${f.id}">
                <strong style="color: ${f.name ? 'inherit' : 'var(--text-secondary)'}">${f.name || 'Unnamed Flag'}</strong>
              </div>
            `).join('')}
            ${flags.length === 0 ? `<div style="padding:16px; color:var(--text-secondary); text-align:center;">No flags created yet.</div>` : ''}
          </div>
        </div>

        <!-- Form Pane -->
        <div class="pane-form">
          ${selectedFlag ? renderForm(selectedFlag) : `<div class="empty-state">Select or create a flag to edit.</div>`}
        </div>

      </div>
    `;

    attachEvents();
  }

  function renderForm(flag) {
    return `
      <div style="max-width: 600px;">
        <div class="form-group">
          <label>Name (Internal ID used in logic)</label>
          <input type="text" id="flag-name" value="${flag.name}" placeholder="e.g. rescued_blacksmith" />
          <div style="font-size:0.8em; color:var(--text-secondary); margin-top:4px;">Avoid spaces. Use underscores.</div>
        </div>

        <div class="form-group">
          <label>Description</label>
          <textarea id="flag-desc" rows="3" placeholder="Description for your reference">${flag.description || ''}</textarea>
        </div>

        <div class="form-group">
          <label>Default Value</label>
          <select id="flag-default">
            <option value="false" ${flag.defaultValue === false ? 'selected' : ''}>OFF (False)</option>
            <option value="true" ${flag.defaultValue === true ? 'selected' : ''}>ON (True)</option>
          </select>
        </div>

        <div style="margin-top: 32px; padding-top: 16px; border-top: 1px solid var(--border); display: flex; justify-content: space-between;">
          <button id="btn-delete-flag" class="danger">Delete Flag</button>
        </div>
      </div>
    `;
  }

  function attachEvents() {
    container.querySelector('#btn-create-flag')?.addEventListener('click', () => {
      const f = createFlag();
      store.save('flags', f);
      flags = store.getAll('flags');
      selectedId = f.id;
      render();
    });

    container.querySelectorAll('.list-item').forEach(el => {
      el.addEventListener('click', (e) => {
        selectedId = e.currentTarget.dataset.id;
        render();
      });
    });

    const nameInput = container.querySelector('#flag-name');
    if (nameInput) {
      const onChange = () => {
        const f = flags.find(x => x.id === selectedId);
        f.name = container.querySelector('#flag-name').value;
        f.description = container.querySelector('#flag-desc').value;
        f.defaultValue = container.querySelector('#flag-default').value === 'true';
        store.save('flags', f);
      };

      ['#flag-name', '#flag-desc', '#flag-default'].forEach(id => {
         const el = container.querySelector(id);
         if (el.tagName === 'SELECT') {
            el.addEventListener('change', () => { onChange(); render(); });
         } else {
            el.addEventListener('blur', () => { onChange(); render(); });
         }
      });

      container.querySelector('#btn-delete-flag').addEventListener('click', () => {
        showConfirmModal('Are you sure you want to delete this flag?', () => {
           store.remove('flags', selectedId);
           flags = store.getAll('flags');
           selectedId = null;
           render();
        });
      });
    }
  }

  render();
}
