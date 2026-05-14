import { store } from '../../data/store.js?v=1778179374';
import { createPlayer } from '../../data/models.js?v=1778179374';
import { showConfirmModal } from '../components/modal.js?v=1778179374';

export function renderPlayerEditor(container) {
  let players = store.getAll('players');
  let cards = store.getAll('cards');
  let consumables = store.getAll('consumables');
  let equipment = store.getAll('equipment');
  let keyItems = store.getAll('keyItems');
  let selectedId = players[0]?.id || null;

  function render() {
    const selectedPlayer = players.find(player => player.id === selectedId) || null;
    container.innerHTML = `
      <div class="editor-header">
        <h2>Player Editor</h2>
        <button id="btn-create-player" class="primary">+ New Player</button>
      </div>
      <div class="editor-body split-pane">
        <div class="pane-list">
          <div class="item-list">
            ${players.map(player => `
              <div class="list-item ${player.id === selectedId ? 'selected' : ''}" data-id="${player.id}">
                <strong>${player.name || 'Unnamed Player'}</strong>
                <div style="font-size:0.8em; color:var(--text-secondary); margin-top:4px;">
                  HP: ${player.baseStats?.maxHealth ?? 20} • Energy: ${player.baseStats?.maxEnergy ?? 3}
                </div>
              </div>
            `).join('')}
            ${players.length === 0 ? `<div style="padding:16px; color:var(--text-secondary); text-align:center;">No players created yet.</div>` : ''}
          </div>
        </div>
        <div class="pane-form">
          ${selectedPlayer ? renderForm(selectedPlayer) : `<div class="empty-state">Select or create a player to edit.</div>`}
        </div>
      </div>
    `;

    attachEvents();
  }

  function renderForm(player) {
    return `
      <div style="max-width: 900px;">
        <div class="form-row">
          <div class="form-group">
            <label>Name</label>
            <input type="text" id="player-name" value="${player.name}" />
          </div>
        </div>
        <div class="form-row">
          <div class="form-group" style="flex:2;">
            <label>Portrait Image Path</label>
            <input type="text" id="player-portrait-image" value="${player.portraitImage || ''}" placeholder="e.g. assets/ui/player-portrait.png" />
          </div>
          <div class="form-group">
            <label>Upload Portrait</label>
            <input type="file" id="player-portrait-upload" accept="image/*" />
          </div>
        </div>
        <div class="form-row">
          <div class="form-group">
            <label>Max Health</label>
            <input type="number" id="player-max-health" value="${player.baseStats.maxHealth}" min="1" />
          </div>
          <div class="form-group">
            <label>Strength</label>
            <input type="number" id="player-strength" value="${player.baseStats.strength}" min="0" />
          </div>
          <div class="form-group">
            <label>Dexterity</label>
            <input type="number" id="player-dexterity" value="${player.baseStats.dexterity}" min="0" />
          </div>
          <div class="form-group">
            <label>Insight</label>
            <input type="number" id="player-insight" value="${player.baseStats.insight}" min="0" />
          </div>
          <div class="form-group">
            <label>Max Energy</label>
            <input type="number" id="player-max-energy" value="${player.baseStats.maxEnergy}" min="0" />
          </div>
          <div class="form-group">
            <label>Hand Size</label>
            <input type="number" id="player-hand-size" value="${player.baseStats.handSize}" min="1" />
          </div>
        </div>

        <div class="form-group">
          <label>Starting Deck</label>
          <div class="dynamic-list">
            ${(player.startingDeck || []).map((cardId, index) => `
              <div class="dynamic-item">
                <select class="player-deck-card" data-index="${index}" style="flex:1;">
                  <option value="">-- Select Card --</option>
                  ${cards.map(card => `<option value="${card.id}" ${card.id === cardId ? 'selected' : ''}>${card.name || 'Unnamed Card'} (${card.type})</option>`).join('')}
                </select>
                <button class="danger btn-remove-player-deck-card" data-index="${index}">X</button>
              </div>
            `).join('')}
            <div style="margin-top:8px;">
              <button id="btn-add-player-deck-card" ${cards.length === 0 ? 'disabled' : ''}>+ Add Card</button>
            </div>
          </div>
        </div>

        <div class="form-row">
          <div class="form-group">
            <label>Starting Consumables</label>
            <input type="text" id="player-consumables" value="${(player.startingInventory.consumables || []).join(', ')}" placeholder="${consumables.map(item => item.id).join(', ')}" />
          </div>
          <div class="form-group">
            <label>Starting Equipment</label>
            <input type="text" id="player-equipment" value="${(player.startingInventory.equipment || []).join(', ')}" placeholder="${equipment.map(item => item.id).join(', ')}" />
          </div>
          <div class="form-group">
            <label>Starting Key Items</label>
            <input type="text" id="player-key-items" value="${(player.startingInventory.keyItems || []).join(', ')}" placeholder="${keyItems.map(item => item.id).join(', ')}" />
          </div>
        </div>

        <div style="margin-top: 32px; padding-top: 16px; border-top: 1px solid var(--border);">
          <button id="btn-delete-player" class="danger">Delete Player</button>
        </div>
      </div>
    `;
  }

  function attachEvents() {
    container.querySelector('#btn-create-player')?.addEventListener('click', () => {
      const player = createPlayer();
      store.save('players', player);
      players = store.getAll('players');
      selectedId = player.id;
      render();
    });

    container.querySelectorAll('.list-item').forEach(item => {
      item.addEventListener('click', event => {
        selectedId = event.currentTarget.dataset.id;
        render();
      });
    });

    if (!container.querySelector('#player-name')) return;

    const onChange = () => {
      const player = players.find(entry => entry.id === selectedId);
      if (!player) return;
      player.name = container.querySelector('#player-name').value;
      player.portraitImage = container.querySelector('#player-portrait-image').value;
      player.baseStats = {
        maxHealth: parseInt(container.querySelector('#player-max-health').value, 10) || 20,
        strength: parseInt(container.querySelector('#player-strength').value, 10) || 0,
        dexterity: parseInt(container.querySelector('#player-dexterity').value, 10) || 0,
        insight: parseInt(container.querySelector('#player-insight').value, 10) || 0,
        maxEnergy: parseInt(container.querySelector('#player-max-energy').value, 10) || 3,
        handSize: parseInt(container.querySelector('#player-hand-size').value, 10) || 5
      };
      player.startingDeck = Array.from(container.querySelectorAll('.player-deck-card')).map(select => select.value).filter(Boolean);
      player.startingInventory = {
        consumables: parseCsv(container.querySelector('#player-consumables').value),
        equipment: parseCsv(container.querySelector('#player-equipment').value),
        keyItems: parseCsv(container.querySelector('#player-key-items').value)
      };
      store.save('players', player);
    };

    container.querySelectorAll('input, select').forEach(field => {
      field.addEventListener('change', onChange);
      field.addEventListener('blur', onChange);
    });

    container.querySelector('#player-portrait-upload')?.addEventListener('change', async event => {
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
        const player = players.find(entry => entry.id === selectedId);
        player.portraitImage = `assets/ui/${file.name}`;
        store.save('players', player);
        render();
      } catch (err) {
        alert('Upload failed. Make sure the python server is running.');
      }
    });

    container.querySelector('#btn-add-player-deck-card')?.addEventListener('click', () => {
      const player = players.find(entry => entry.id === selectedId);
      player.startingDeck.push('');
      store.save('players', player);
      render();
    });

    container.querySelectorAll('.btn-remove-player-deck-card').forEach(button => {
      button.addEventListener('click', event => {
        const player = players.find(entry => entry.id === selectedId);
        player.startingDeck.splice(parseInt(event.currentTarget.dataset.index, 10), 1);
        store.save('players', player);
        render();
      });
    });

    container.querySelector('#btn-delete-player')?.addEventListener('click', () => {
      showConfirmModal('Are you sure you want to delete this player?', () => {
        store.remove('players', selectedId);
        players = store.getAll('players');
        selectedId = players[0]?.id || null;
        render();
      });
    });
  }

  function parseCsv(value) {
    return value.split(',').map(entry => entry.trim()).filter(Boolean);
  }

  render();
}
