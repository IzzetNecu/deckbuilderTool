import { store } from '../../data/store.js?v=1778179374';

export const PREDEFINED_BUFFS = [
  {
    id: 'buff_block',
    name: 'Block',
    kind: 'buff',
    shortLabel: 'BLK',
    reminderText: 'Prevents incoming damage until removed or spent.'
  },
  {
    id: 'buff_strength',
    name: 'Strength',
    kind: 'buff',
    shortLabel: 'STR',
    reminderText: 'Adds to outgoing damage on scaling attacks.'
  },
  {
    id: 'buff_dexterity',
    name: 'Dexterity',
    kind: 'buff',
    shortLabel: 'DEX',
    reminderText: 'Adds to outgoing block on scaling defenses.'
  },
  {
    id: 'buff_insight',
    name: 'Insight',
    kind: 'buff',
    shortLabel: 'INS',
    reminderText: 'Reveals more upcoming enemy intent when higher than the enemy insight.'
  },
  {
    id: 'buff_energy',
    name: 'Energy',
    kind: 'buff',
    shortLabel: 'ENG',
    reminderText: 'Spent to play cards during your turn.'
  },
  {
    id: 'buff_heat',
    name: 'Heat',
    kind: 'buff',
    shortLabel: 'HEAT',
    reminderText: 'Your next damage effect gains X damage, then Heat loses half its stacks rounded down.'
  },
  {
    id: 'debuff_burning',
    name: 'Burning',
    kind: 'debuff',
    shortLabel: 'BURN',
    reminderText: 'Your next damage effect loses X damage, minimum 0, then Burning loses half its stacks rounded down.'
  },
  {
    id: 'buff_flow',
    name: 'Flow',
    kind: 'buff',
    shortLabel: 'FLOW',
    reminderText: 'Your next block effect gains X block, then Flow loses half its stacks rounded down.'
  },
  {
    id: 'debuff_slippery',
    name: 'Slippery',
    kind: 'debuff',
    shortLabel: 'SLIP',
    reminderText: 'Your next block effect loses X block, minimum 0, then Slippery loses half its stacks rounded down.'
  },
  {
    id: 'buff_regen',
    name: 'Regen',
    kind: 'buff',
    shortLabel: 'RGN',
    reminderText: 'At end of turn, heal X and lose 1 stack.'
  },
  {
    id: 'debuff_poison',
    name: 'Poison',
    kind: 'debuff',
    shortLabel: 'PSN',
    reminderText: 'At start of turn, lose X HP and lose 1 stack.'
  },
  {
    id: 'buff_haste',
    name: 'Haste',
    kind: 'buff',
    shortLabel: 'HST',
    reminderText: 'At start of turn, draw X extra cards, then lose 1 stack.'
  },
  {
    id: 'debuff_slowed',
    name: 'Slowed',
    kind: 'debuff',
    shortLabel: 'SLOW',
    reminderText: 'At start of turn, draw X fewer cards, minimum 0, then lose 1 stack.'
  },
  {
    id: 'buff_scaled',
    name: 'Scaled',
    kind: 'buff',
    shortLabel: 'SCL',
    reminderText: 'At end of turn, gain X block and lose 1 stack.'
  },
  {
    id: 'debuff_chill',
    name: 'Chill',
    kind: 'debuff',
    shortLabel: 'CHILL',
    reminderText: 'At end of turn, lose X block, minimum 0, and lose 1 stack.'
  },
  {
    id: 'buff_energized',
    name: 'Energized',
    kind: 'buff',
    shortLabel: 'AMP',
    reminderText: 'Your next played card resolves its full effect list twice, then lose 1 stack.'
  },
  {
    id: 'debuff_jolted',
    name: 'Jolted',
    kind: 'debuff',
    shortLabel: 'JOLT',
    reminderText: 'After your next played card resolves, lose 1 energy and lose 1 stack.'
  }
];

export function renderBuffEditor(container) {
  let buffs = ensurePredefinedBuffs();
  let selectedId = buffs[0]?.id || null;

  function render() {
    const selectedBuff = buffs.find(buff => buff.id === selectedId) || null;
    container.innerHTML = `
      <div class="editor-header">
        <h2>Buffs & Debuffs</h2>
      </div>
      <div class="editor-body split-pane">
        <div class="pane-list">
          <div class="item-list">
            ${buffs.map(buff => `
              <div class="list-item ${buff.id === selectedId ? 'selected' : ''}" data-id="${buff.id}">
                <strong>${buff.name || 'Unnamed Status'}</strong>
                <div style="font-size:0.8em; color:var(--text-secondary); margin-top:4px;">
                  ${(buff.kind || 'buff')} • ${(buff.shortLabel || 'No label')}
                </div>
              </div>
            `).join('')}
            ${buffs.length === 0 ? `<div style="padding:16px; color:var(--text-secondary); text-align:center;">No buff or debuff definitions yet.</div>` : ''}
          </div>
        </div>
        <div class="pane-form">
          ${selectedBuff ? renderForm(selectedBuff) : `<div class="empty-state">Select a predefined buff or debuff definition to edit its icon.</div>`}
        </div>
      </div>
    `;

    attachEvents();
  }

  function renderForm(buff) {
    return `
      <div style="max-width:840px; display:flex; gap:32px;">
        <div style="flex:1;">
          <div class="form-row">
            <div class="form-group">
              <label>Name</label>
              <input type="text" value="${buff.name}" readonly />
            </div>
            <div class="form-group">
              <label>Type</label>
              <input type="text" value="${buff.kind}" readonly />
            </div>
            <div class="form-group">
              <label>Short Label</label>
              <input type="text" value="${buff.shortLabel || ''}" readonly />
            </div>
          </div>

          <div class="form-group">
            <label>Effect / Reminder Text</label>
            <textarea rows="4" readonly>${buff.reminderText || ''}</textarea>
          </div>

          <div class="form-row">
            <div class="form-group" style="flex:2;">
              <label>Icon Image Path</label>
              <input type="text" id="buff-icon-image" value="${buff.iconImage || ''}" placeholder="e.g. assets/ui/strength.png" />
            </div>
            <div class="form-group">
              <label>Upload Icon</label>
              <input type="file" id="buff-icon-upload" accept="image/*" />
            </div>
          </div>
        </div>

        <div style="width:240px; border-left:1px solid var(--border); padding-left:32px;">
          <h3 style="margin-top:0;">Preview</h3>
          <div style="display:flex; gap:12px; align-items:center; padding:16px; border:1px solid var(--border); border-radius:12px; background:var(--bg-surface);">
            <div style="width:52px; height:52px; border-radius:14px; border:1px solid var(--border); background:${buff.kind === 'debuff' ? 'rgba(160,55,55,0.25)' : 'rgba(70,120,70,0.22)'}; display:flex; align-items:center; justify-content:center; overflow:hidden;">
              ${buff.iconImage ? `<img src="/game/${buff.iconImage}" alt="" style="max-width:100%; max-height:100%; object-fit:cover;" />` : `<span style="font-size:0.78em; color:var(--text-secondary); letter-spacing:0.08em;">${buff.shortLabel || 'ICON'}</span>`}
            </div>
            <div style="min-width:0;">
              <strong>${buff.name || 'Unnamed Status'}</strong>
              <div style="font-size:0.78em; color:var(--text-secondary); margin-top:4px;">${buff.reminderText || 'No reminder text yet.'}</div>
            </div>
          </div>
        </div>
      </div>
    `;
  }

  function attachEvents() {
    container.querySelectorAll('.list-item').forEach(item => {
      item.addEventListener('click', event => {
        selectedId = event.currentTarget.dataset.id;
        render();
      });
    });

    if (!container.querySelector('#buff-icon-image')) return;

    const onChange = () => {
      const buff = buffs.find(entry => entry.id === selectedId);
      if (!buff) return;
      buff.iconImage = container.querySelector('#buff-icon-image').value;
      store.save('buffs', buff);
    };

    container.querySelectorAll('#buff-icon-image').forEach(field => {
      field.addEventListener('change', () => {
        onChange();
        render();
      });
      field.addEventListener('blur', onChange);
    });

    container.querySelector('#buff-icon-upload')?.addEventListener('change', async event => {
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
        const buff = buffs.find(entry => entry.id === selectedId);
        buff.iconImage = `assets/ui/${file.name}`;
        store.save('buffs', buff);
        render();
      } catch (err) {
        alert('Upload failed. Make sure the python server is running.');
      }
    });

  }

  render();
}

function ensurePredefinedBuffs() {
  const persisted = store.getAll('buffs');
  const persistedById = new Map(persisted.map(buff => [buff.id, buff]));
  const merged = PREDEFINED_BUFFS.map(buff => ({
    ...buff,
    iconImage: persistedById.get(buff.id)?.iconImage || ''
  }));
  localStorage.setItem('gamebuilder_buffs', JSON.stringify(merged));
  return merged;
}
