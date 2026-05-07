import { store } from '../../data/store.js?v=1778151460';
import { createDeckTemplate } from '../../data/models.js?v=1778151460';
import { showConfirmModal } from '../components/modal.js?v=1778151460';

export function renderDeckEditor(container) {
  let decks = store.getAll('deckTemplates');
  let factions = store.getAll('factions');
  let allCards = store.getAll('cards');
  let selectedId = null;

  function render() {
    const selectedDeck = decks.find(d => d.id === selectedId) || null;

    container.innerHTML = `
      <div class="editor-header">
        <h2>Deck Template Editor</h2>
        <button id="btn-create-deck" class="primary">+ New Deck</button>
      </div>
      <div class="editor-body split-pane">
        
        <!-- List Pane -->
        <div class="pane-list">
          <div class="item-list">
            ${decks.map(d => `
              <div class="list-item ${d.id === selectedId ? 'selected' : ''}" data-id="${d.id}">
                <strong style="color: ${d.name ? 'inherit' : 'var(--text-secondary)'}">${d.name || 'Unnamed Deck'}</strong>
                <div style="font-size: 0.8em; color: var(--text-secondary); margin-top: 4px;">
                  ${d.cardIds ? d.cardIds.length : 0} Cards
                </div>
              </div>
            `).join('')}
            ${decks.length === 0 ? `<div style="padding:16px; color:var(--text-secondary); text-align:center;">No decks created yet.</div>` : ''}
          </div>
        </div>

        <!-- Form Pane -->
        <div class="pane-form">
          ${selectedDeck ? renderForm(selectedDeck) : `<div class="empty-state">Select or create a deck template to edit.</div>`}
        </div>

      </div>
    `;

    attachEvents();
  }

  function renderForm(deck) {
    if (!deck.cardIds) deck.cardIds = [];

    // Tally cards
    const cardCounts = {};
    deck.cardIds.forEach(id => {
       cardCounts[id] = (cardCounts[id] || 0) + 1;
    });

    return `
      <div style="max-width: 800px; display: flex; gap: 32px;">
        <div style="flex:1;">
          <h3 style="margin-top:0;">Deck Info</h3>
          <div class="form-group">
            <label>Template Name</label>
            <input type="text" id="deck-name" value="${deck.name}" placeholder="e.g. Ironclad Starter" />
          </div>
          <div class="form-group">
            <label>Associated Faction (Optional)</label>
            <select id="deck-faction">
              <option value="">None / Neutral</option>
              ${factions.map(f => `<option value="${f.id}" ${deck.factionId === f.id ? 'selected' : ''}>${f.name}</option>`).join('')}
            </select>
          </div>

          <div style="margin-top: 32px; padding-top: 16px; border-top: 1px solid var(--border);">
            <button id="btn-delete-deck" class="danger">Delete Deck</button>
          </div>
        </div>

        <div style="flex:1; border-left: 1px solid var(--border); padding-left: 32px;">
          <h3 style="margin-top:0;">Deck Contents (${deck.cardIds.length} cards)</h3>
          
          <div class="dynamic-list" style="margin-bottom: 24px; max-height: 250px; overflow-y:auto; padding: 0;">
             ${Object.keys(cardCounts).length === 0 ? `<div style="padding:16px; color:var(--text-secondary);">No cards in deck.</div>` : ''}
             ${Object.keys(cardCounts).map(cId => {
                const c = allCards.find(x => x.id === cId);
                const name = c ? c.name : 'Unknown Card';
                const count = cardCounts[cId];
                return `
                  <div style="display:flex; justify-content:space-between; padding: 8px 16px; border-bottom: 1px solid var(--border);">
                     <div><strong>${count}x</strong> ${name}</div>
                     <button class="danger btn-remove-card" data-cid="${cId}" style="padding: 2px 8px;">-1</button>
                  </div>
                `;
             }).join('')}
          </div>

          <h4>Available Cards Library</h4>
          <div style="max-height: 250px; overflow-y:auto; border: 1px solid var(--border); border-radius: 4px;">
             ${allCards.length === 0 ? `<div style="padding:16px; color:var(--text-secondary);">No cards exist yet.</div>` : ''}
             ${allCards.map(c => `
                <div style="display:flex; justify-content:space-between; padding: 8px; border-bottom: 1px solid var(--border); align-items:center;">
                   <div>
                     <strong>${c.name || 'Unnamed'}</strong> <span style="font-size:0.8em; color:var(--text-secondary);">${c.type} - Cost: ${c.cost}</span>
                   </div>
                   <button class="primary btn-add-card" data-cid="${c.id}" style="padding: 2px 8px;">+ Add</button>
                </div>
             `).join('')}
          </div>

        </div>
      </div>
    `;
  }

  function attachEvents() {
    container.querySelector('#btn-create-deck')?.addEventListener('click', () => {
      const d = createDeckTemplate();
      store.save('deckTemplates', d);
      decks = store.getAll('deckTemplates');
      selectedId = d.id;
      render();
    });

    container.querySelectorAll('.list-item').forEach(el => {
      el.addEventListener('click', (e) => {
        selectedId = e.currentTarget.dataset.id;
        render();
      });
    });

    const nameInput = container.querySelector('#deck-name');
    if (nameInput) {
      const onChange = () => {
        const d = decks.find(x => x.id === selectedId);
        d.name = container.querySelector('#deck-name').value;
        d.factionId = container.querySelector('#deck-faction').value;
        store.save('deckTemplates', d);
      };

      container.querySelector('#deck-name').addEventListener('blur', () => { onChange(); render(); });
      container.querySelector('#deck-faction').addEventListener('change', () => { onChange(); render(); });

      container.querySelectorAll('.btn-add-card').forEach(btn => {
         btn.addEventListener('click', (ev) => {
            const cid = ev.currentTarget.dataset.cid;
            const d = decks.find(x => x.id === selectedId);
            d.cardIds.push(cid);
            store.save('deckTemplates', d);
            render();
         });
      });

      container.querySelectorAll('.btn-remove-card').forEach(btn => {
         btn.addEventListener('click', (ev) => {
            const cid = ev.currentTarget.dataset.cid;
            const d = decks.find(x => x.id === selectedId);
            const index = d.cardIds.indexOf(cid);
            if (index > -1) {
               d.cardIds.splice(index, 1);
               store.save('deckTemplates', d);
               render();
            }
         });
      });

      container.querySelector('#btn-delete-deck').addEventListener('click', () => {
        showConfirmModal('Are you sure you want to delete this deck?', () => {
           store.remove('deckTemplates', selectedId);
           decks = store.getAll('deckTemplates');
           selectedId = null;
           render();
        });
      });
    }
  }

  render();
}
