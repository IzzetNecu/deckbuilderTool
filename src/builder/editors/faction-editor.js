import { store } from '../../data/store.js?v=1778159383';
import { createFaction } from '../../data/models.js?v=1778159383';
import { showConfirmModal } from '../components/modal.js?v=1778159383';

export function renderFactionEditor(container) {
  let factions = store.getAll('factions');
  let selectedId = null;

  function render() {
    const selectedFaction = factions.find(f => f.id === selectedId) || null;

    container.innerHTML = `
      <div class="editor-header">
        <h2>Faction Editor</h2>
        <button id="btn-create-faction" class="primary">+ New Faction</button>
      </div>
      <div class="editor-body split-pane">
        
        <!-- List Pane -->
        <div class="pane-list">
          <div class="item-list">
            ${factions.map(f => `
              <div class="list-item ${f.id === selectedId ? 'selected' : ''}" data-id="${f.id}">
                <div style="display:flex; align-items:center; gap:8px;">
                  <div style="width:16px; height:16px; border-radius:50%; background-color:${f.color}"></div>
                  <strong style="color: ${f.name ? 'inherit' : 'var(--text-secondary)'}">${f.name || 'Unnamed Faction'}</strong>
                </div>
              </div>
            `).join('')}
            ${factions.length === 0 ? `<div style="padding:16px; color:var(--text-secondary); text-align:center;">No factions created yet.</div>` : ''}
          </div>
        </div>

        <!-- Form Pane -->
        <div class="pane-form">
          ${selectedFaction ? renderForm(selectedFaction) : `<div class="empty-state">Select or create a faction to edit.</div>`}
        </div>

      </div>
    `;

    attachEvents();
  }

  function renderForm(faction) {
    return `
      <div class="form-group">
        <label>Name</label>
        <input type="text" id="faction-name" value="${faction.name}" placeholder="e.g. Ironclad" />
      </div>
      <div class="form-group">
        <label>Description</label>
        <textarea id="faction-desc" rows="3" placeholder="Description of the faction...">${faction.description}</textarea>
      </div>
      <div class="form-group">
        <label>Theme Color</label>
        <input type="color" id="faction-color" value="${faction.color}" style="width: 100px; padding: 0; cursor: pointer; height: 32px;" />
      </div>

      <div class="form-group">
        <label>Faction Ranks (Tiers)</label>
        <div class="dynamic-list" id="ranks-list">
          ${faction.ranks.map((rank, index) => `
            <div class="dynamic-item">
              <span style="width: 24px; color: var(--text-secondary);">${index + 1}.</span>
              <input type="text" value="${rank}" class="rank-input" data-index="${index}" placeholder="Rank name (e.g. Initiate)" />
              <button class="danger btn-remove-rank" data-index="${index}">X</button>
            </div>
          `).join('')}
          <div style="margin-top: 8px;">
            <button id="btn-add-rank">Add Rank</button>
          </div>
        </div>
      </div>

      <div style="margin-top: 32px; padding-top: 16px; border-top: 1px solid var(--border); display: flex; justify-content: space-between;">
        <button id="btn-delete-faction" class="danger">Delete Faction</button>
      </div>
    `;
  }

  function attachEvents() {
    // Create new
    container.querySelector('#btn-create-faction')?.addEventListener('click', () => {
      const newFaction = createFaction();
      store.save('factions', newFaction);
      factions = store.getAll('factions');
      selectedId = newFaction.id;
      render();
    });

    // Select item
    container.querySelectorAll('.list-item').forEach(el => {
      el.addEventListener('click', (e) => {
        selectedId = e.currentTarget.dataset.id;
        render();
      });
    });

    // Form inputs updates
    const nameInput = container.querySelector('#faction-name');
    if (nameInput) {
      const onChange = () => {
        const faction = factions.find(f => f.id === selectedId);
        faction.name = container.querySelector('#faction-name').value;
        faction.description = container.querySelector('#faction-desc').value;
        faction.color = container.querySelector('#faction-color').value;
        
        // collect ranks
        const rankInputs = container.querySelectorAll('.rank-input');
        faction.ranks = Array.from(rankInputs).map(inp => inp.value);

        store.save('factions', faction);
      };

      container.querySelector('#faction-name').addEventListener('input', () => {
         onChange(); 
         // Force list re-render just to update the text in list inline, 
         // but that causes focus loss. Let's do it on blur for name.
      });
      container.querySelector('#faction-name').addEventListener('blur', render);
      container.querySelector('#faction-desc').addEventListener('change', onChange);
      container.querySelector('#faction-color').addEventListener('input', () => { onChange(); render(); });

      container.querySelectorAll('.rank-input').forEach(inp => {
        inp.addEventListener('change', onChange);
      });

      container.querySelector('#btn-add-rank').addEventListener('click', () => {
         const faction = factions.find(f => f.id === selectedId);
         faction.ranks.push('');
         store.save('factions', faction);
         render();
      });

      container.querySelectorAll('.btn-remove-rank').forEach(btn => {
         btn.addEventListener('click', (e) => {
            const index = parseInt(e.currentTarget.dataset.index);
            const faction = factions.find(f => f.id === selectedId);
            faction.ranks.splice(index, 1);
            store.save('factions', faction);
            render();
         });
      });

      container.querySelector('#btn-delete-faction').addEventListener('click', () => {
        showConfirmModal('Are you sure you want to delete this faction?', () => {
           store.remove('factions', selectedId);
           factions = store.getAll('factions');
           selectedId = null;
           render();
        });
      });
    }
  }

  // Initial render
  render();
}
