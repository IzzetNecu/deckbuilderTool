import { store } from '../../data/store.js?v=1778175010';
import { createCard } from '../../data/models.js?v=1778175010';
import { showConfirmModal } from '../components/modal.js?v=1778175010';

export function renderCardEditor(container) {
  let cards = store.getAll('cards');
  let factions = store.getAll('factions');
  let selectedId = null;

  function render() {
    const selectedCard = cards.find(c => c.id === selectedId) || null;

    container.innerHTML = `
      <div class="editor-header">
        <h2>Card Editor</h2>
        <div style="display:flex; gap:8px;">
          <button id="btn-card-help" style="background:var(--bg-surface); border:1px solid var(--border); border-radius:50%; width:32px; height:32px; font-size:1em; cursor:pointer; color:var(--text-secondary);" title="How to create a card">?</button>
          <button id="btn-create-card" class="primary">+ New Card</button>
        </div>
      </div>
      <div class="editor-body split-pane">
        
        <!-- List Pane -->
        <div class="pane-list">
          <div class="item-list">
            ${cards.map(c => `
              <div class="list-item ${c.id === selectedId ? 'selected' : ''}" data-id="${c.id}">
                <strong style="color: ${c.name ? 'inherit' : 'var(--text-secondary)'}">${c.name || 'Unnamed Card'}</strong>
                <div style="font-size: 0.8em; color: var(--text-secondary); margin-top: 4px;">
                  ${c.type} • Cost: ${c.cost}
                </div>
              </div>
            `).join('')}
            ${cards.length === 0 ? `<div style="padding:16px; color:var(--text-secondary); text-align:center;">No cards created yet.</div>` : ''}
          </div>
        </div>

        <!-- Form Pane -->
        <div class="pane-form" style="display:flex; gap:32px;">
          ${selectedCard ? renderForm(selectedCard) : `<div class="empty-state" style="flex:1;">Select or create a card to edit.</div>`}
          ${selectedCard ? renderPreview(selectedCard) : ''}
        </div>

      </div>
    `;

    attachEvents();
  }

  function renderForm(card) {
    return `
      <div style="flex:1; max-width: 600px;">
        <div class="form-row">
          <div class="form-group">
            <label>Name</label>
            <input type="text" id="card-name" value="${card.name}" placeholder="e.g. Strike" />
          </div>
          <div class="form-group">
            <label>Cost</label>
            <input type="number" id="card-cost" value="${card.cost}" min="0" max="10" />
          </div>
        </div>
        
        <div class="form-row">
          <div class="form-group">
            <label>Type</label>
            <select id="card-type">
              <option value="attack" ${card.type === 'attack' ? 'selected' : ''}>Attack</option>
              <option value="defend" ${card.type === 'defend' ? 'selected' : ''}>Defend</option>
              <option value="skill" ${card.type === 'skill' ? 'selected' : ''}>Skill</option>
              <option value="power" ${card.type === 'power' ? 'selected' : ''}>Power</option>
            </select>
          </div>
          <div class="form-group">
            <label>Rarity</label>
            <select id="card-rarity">
              <option value="common" ${card.rarity === 'common' ? 'selected' : ''}>Common</option>
              <option value="uncommon" ${card.rarity === 'uncommon' ? 'selected' : ''}>Uncommon</option>
              <option value="rare" ${card.rarity === 'rare' ? 'selected' : ''}>Rare</option>
            </select>
          </div>
          <div class="form-group">
            <label>Faction (Optional)</label>
            <select id="card-faction">
              <option value="">None / Neutral</option>
              ${factions.map(f => `<option value="${f.id}" ${card.factionId === f.id ? 'selected' : ''}>${f.name}</option>`).join('')}
            </select>
          </div>
        </div>

        <div class="form-group">
          <label>Description (Dynamic text rendering on card)</label>
          <textarea id="card-desc" rows="3" placeholder="Deal 6 damage.">${card.description}</textarea>
        </div>

        <div class="form-group">
          <label>Mechanic Effects (Internal Logic for Godot)</label>
          <div class="dynamic-list" id="effects-list">
            ${card.effects.map((eff, index) => `
              <div class="dynamic-item">
                <input type="text" value="${eff}" class="effect-input" data-index="${index}" placeholder="e.g. DEAL_DAMAGE:6" />
                <button class="danger btn-remove-effect" data-index="${index}">X</button>
              </div>
            `).join('')}
            <div style="margin-top: 8px;">
              <button id="btn-add-effect">Add Effect</button>
            </div>
        </div>

        <div style="margin-top: 32px; padding-top: 16px; border-top: 1px solid var(--border); display: flex; justify-content: space-between;">
          <button id="btn-delete-card" class="danger">Delete Card</button>
        </div>
      </div>
    `;
  }

  function renderPreview(card) {
     const factionColor = card.factionId ? (factions.find(f => f.id === card.factionId)?.color || '#555') : '#555';
     const rareColor = card.rarity === 'rare' ? '#ffd700' : (card.rarity === 'uncommon' ? '#87ceeb' : '#fff');
     
     // Quick CSS inline mapping for card layout preview
     return `
      <div style="width: 250px; background-color: var(--bg-surface); padding: 16px; border-radius: 8px; border-top: 4px solid ${factionColor}; border-bottom: 2px solid ${rareColor};">
         <h4 style="color:var(--text-secondary); margin-bottom: 16px;">Live Preview</h4>
         
         <div style="width: 200px; height: 300px; background-color: #222; border-radius: 8px; border: 2px solid #444; position:relative; display:flex; flex-direction:column;">
            <!-- Header -->
            <div style="display:flex; justify-content:space-between; align-items:center; padding: 8px; background-color: ${factionColor}33; border-bottom:1px solid #444; border-radius: 8px 8px 0 0;">
               <strong style="font-size:14px; text-shadow:1px 1px 2px #000;">${card.name || 'Unnamed'}</strong>
               <div style="width:24px; height:24px; border-radius:50%; background:#111; color:${rareColor}; display:flex; align-items:center; justify-content:center; font-weight:bold; border:1px solid ${factionColor};">
                 ${card.cost}
               </div>
            </div>

            <!-- Image placeholder -->
            <div style="flex:1; display:flex; align-items:center; justify-content:center; border-bottom: 1px solid #444; color:#666; font-size:12px;">
              [Art Placeholder]
            </div>

            <!-- Type -->
            <div style="text-align:center; padding:4px; font-size:10px; text-transform:uppercase; letter-spacing:1px; background:#1a1a1a;">
               ${card.type}
            </div>

            <!-- Text Description -->
            <div style="height: 100px; padding: 8px; text-align:center; font-size:12px; display:flex; align-items:center; justify-content:center;">
               ${card.description || '<span style="color:#555">No description</span>'}
            </div>
         </div>
      </div>
     `;
  }

  function attachEvents() {
    container.querySelector('#btn-card-help')?.addEventListener('click', () => {
      openHelpPopup();
    });

    container.querySelector('#btn-create-card')?.addEventListener('click', () => {
      const c = createCard();
      store.save('cards', c);
      cards = store.getAll('cards');
      selectedId = c.id;
      render();
    });

    container.querySelectorAll('.list-item').forEach(el => {
      el.addEventListener('click', (e) => {
        selectedId = e.currentTarget.dataset.id;
        render();
      });
    });

    const nameInput = container.querySelector('#card-name');
    if (nameInput) {
      const onChange = () => {
        const c = cards.find(x => x.id === selectedId);
        c.name = container.querySelector('#card-name').value;
        c.cost = parseInt(container.querySelector('#card-cost').value, 10);
        c.type = container.querySelector('#card-type').value;
        c.rarity = container.querySelector('#card-rarity').value;
        c.factionId = container.querySelector('#card-faction').value;
        c.description = container.querySelector('#card-desc').value;
        
        const effInputs = container.querySelectorAll('.effect-input');
        c.effects = Array.from(effInputs).map(inp => inp.value);

        store.save('cards', c);
      };

      // update preview immediately, but list on blur to avoid focus issues
      ['#card-name', '#card-cost', '#card-desc'].forEach(id => {
         container.querySelector(id).addEventListener('input', () => { onChange(); renderPreviewOnly(); });
         container.querySelector(id).addEventListener('blur', render);
      });
      ['#card-type', '#card-rarity', '#card-faction'].forEach(id => {
         container.querySelector(id).addEventListener('change', () => { onChange(); render(); });
      });

      container.querySelectorAll('.effect-input').forEach(inp => {
        inp.addEventListener('change', onChange);
      });

      container.querySelector('#btn-add-effect').addEventListener('click', () => {
         const c = cards.find(x => x.id === selectedId);
         c.effects.push('');
         store.save('cards', c);
         render();
      });

      container.querySelectorAll('.btn-remove-effect').forEach(btn => {
         btn.addEventListener('click', (e) => {
            const index = parseInt(e.currentTarget.dataset.index);
            const c = cards.find(x => x.id === selectedId);
            c.effects.splice(index, 1);
            store.save('cards', c);
            render();
         });
      });

      container.querySelector('#btn-delete-card').addEventListener('click', () => {
        showConfirmModal('Are you sure you want to delete this card?', () => {
           store.remove('cards', selectedId);
           cards = store.getAll('cards');
           selectedId = null;
           render();
        });
      });
    }
  }

  function renderPreviewOnly() {
     // A optimization to strictly only update preview panel when typing.
     const c = cards.find(x => x.id === selectedId);
     if (c) {
        const previewContainer = container.querySelector('.pane-form').children[1];
        if (previewContainer) {
            previewContainer.outerHTML = renderPreview(c);
        }
     }
  }
  function openHelpPopup() {
    document.getElementById('card-help-overlay')?.remove();

    const overlay = document.createElement('div');
    overlay.id = 'card-help-overlay';
    overlay.style.cssText = `
      position: fixed; inset: 0; z-index: 9999;
      background: rgba(0,0,0,0.6);
      display: flex; align-items: center; justify-content: center;
    `;

    overlay.innerHTML = `
      <div id="card-help-popup" style="
        background: var(--bg-surface);
        border: 1px solid var(--border);
        border-radius: 12px;
        padding: 32px;
        max-width: 560px;
        width: 90%;
        max-height: 80vh;
        overflow-y: auto;
        position: relative;
        box-shadow: 0 8px 40px rgba(0,0,0,0.6);
      ">
        <button id="card-help-close" style="
          position: absolute; top: 16px; right: 16px;
          background: none; border: none; color: var(--text-secondary);
          font-size: 1.3em; cursor: pointer; line-height: 1;
        ">✕</button>

        <h2 style="margin-bottom: 8px;">How to Create a Card</h2>
        <p style="color:var(--text-secondary); margin-bottom: 24px; font-size:0.9em;">
          Cards are used by both the player and enemies in combat. Each card has a display side (name, description) and a mechanic side (effects).
        </p>

        <h3 style="margin-bottom: 8px; color: var(--accent);">Card Fields</h3>
        <table style="width:100%; border-collapse:collapse; font-size:0.88em; margin-bottom:24px;">
          <thead><tr style="border-bottom:1px solid var(--border);">
            <th style="text-align:left; padding:6px 8px;">Field</th>
            <th style="text-align:left; padding:6px 8px;">Description</th>
          </tr></thead>
          <tbody>
            <tr><td style="padding:6px 8px;"><strong>Name</strong></td><td style="padding:6px 8px;">Displayed on the card in-game.</td></tr>
            <tr><td style="padding:6px 8px;"><strong>Cost</strong></td><td style="padding:6px 8px;">Energy required to play. Player starts each turn with their max energy.</td></tr>
            <tr><td style="padding:6px 8px;"><strong>Type</strong></td><td style="padding:6px 8px;"><em>Attack</em> — must be dragged onto an enemy. <em>Defend / Heal / Skill</em> — dropped in the play zone.</td></tr>
            <tr><td style="padding:6px 8px;"><strong>Rarity</strong></td><td style="padding:6px 8px;">Common / Uncommon / Rare — affects card border colour in preview.</td></tr>
            <tr><td style="padding:6px 8px;"><strong>Description</strong></td><td style="padding:6px 8px;">Flavour/rules text shown on the card face. Does not affect mechanics.</td></tr>
          </tbody>
        </table>

        <h3 style="margin-bottom: 8px; color: var(--accent);">Mechanic Effects</h3>
        <p style="color:var(--text-secondary); font-size:0.88em; margin-bottom:12px;">
          Effects use the format <code style="background:#1a1a1a; padding:2px 5px; border-radius:3px;">TYPE:VALUE</code>. Each card can have multiple effects — they all fire in order when played.
        </p>
        <table style="width:100%; border-collapse:collapse; font-size:0.88em; margin-bottom:24px;">
          <thead><tr style="border-bottom:1px solid var(--border);">
            <th style="text-align:left; padding:6px 8px;">Effect</th>
            <th style="text-align:left; padding:6px 8px;">What it does</th>
            <th style="text-align:left; padding:6px 8px;">Example</th>
          </tr></thead>
          <tbody>
            <tr style="border-bottom:1px solid var(--border)33;"><td style="padding:6px 8px;"><code style="background:#1a1a1a; padding:2px 5px; border-radius:3px;">ATTACK:N</code></td><td style="padding:6px 8px;">Deal N damage to target. Player gains +Strength bonus.</td><td style="padding:6px 8px; color:var(--text-secondary);"><code>ATTACK:6</code></td></tr>
            <tr style="border-bottom:1px solid var(--border)33;"><td style="padding:6px 8px;"><code style="background:#1a1a1a; padding:2px 5px; border-radius:3px;">DEFEND:N</code></td><td style="padding:6px 8px;">Gain N block this turn. Player gains +Dexterity bonus.</td><td style="padding:6px 8px; color:var(--text-secondary);"><code>DEFEND:4</code></td></tr>
            <tr><td style="padding:6px 8px;"><code style="background:#1a1a1a; padding:2px 5px; border-radius:3px;">HEAL:N</code></td><td style="padding:6px 8px;">Restore N HP (capped at max HP).</td><td style="padding:6px 8px; color:var(--text-secondary);"><code>HEAL:3</code></td></tr>
          </tbody>
        </table>

        <p style="color:var(--text-secondary); font-size:0.82em; border-top:1px solid var(--border); padding-top:12px;">
          💡 <strong>Tip:</strong> Attack cards are identified by the <code style="background:#1a1a1a; padding:2px 4px; border-radius:3px;">ATTACK</code> effect — the game requires them to be dragged onto an enemy to play. All other effects play freely in the combat zone.
        </p>
      </div>
    `;

    overlay.addEventListener('click', (e) => {
      if (e.target === overlay) overlay.remove();
    });
    overlay.querySelector('#card-help-close').addEventListener('click', () => overlay.remove());

    document.body.appendChild(overlay);
  }

  render();
}
