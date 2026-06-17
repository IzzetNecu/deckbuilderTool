import { store } from '../../data/store.js?v=1779267161';
import { normalizeElementalAffinityCatalog } from '../../data/models.js?v=1779267161';
import { captureEditorScroll } from '../components/scroll.js?v=1779267161';

export function renderElementalAffinityEditor(container) {
  let affinities = normalizeElementalAffinityCatalog(store.getAll('elemental_affinities'));
  let selectedId = affinities[0]?.id || 1;

  function render() {
    const selected = affinities.find(entry => entry.id === selectedId) || affinities[0];
    const restoreScroll = captureEditorScroll(container);
    container.innerHTML = `
      <div class="editor-header">
        <h2>Elemental Affinities</h2>
      </div>
      <div class="editor-body split-pane">
        <div class="pane-list">
          <div class="item-list">
            ${affinities.map(affinity => `
              <div class="list-item ${affinity.id === selectedId ? 'selected' : ''}" data-id="${affinity.id}">
                <strong>${affinity.name}</strong>
                <div style="font-size:0.8em; color:var(--text-secondary); margin-top:4px;">
                  ${affinity.key} • ${affinity.color}
                </div>
              </div>
            `).join('')}
          </div>
        </div>
        <div class="pane-form" style="display:flex; gap:32px;">
          ${selected ? renderForm(selected) : ''}
          ${selected ? renderPreview(selected) : ''}
        </div>
      </div>
    `;
    attachEvents();
    restoreScroll();
  }

  function renderForm(affinity) {
    return `
      <div style="flex:1; max-width:620px;">
        <div class="form-row">
          <div class="form-group">
            <label>Fixed ID</label>
            <input type="number" value="${affinity.id}" disabled />
          </div>
          <div class="form-group">
            <label>Fixed Key</label>
            <input type="text" value="${affinity.key}" disabled />
          </div>
        </div>
        <div class="form-row">
          <div class="form-group">
            <label>Display Name</label>
            <input type="text" id="affinity-name" value="${affinity.name}" />
          </div>
          <div class="form-group">
            <label>Color</label>
            <input type="color" id="affinity-color" value="${affinity.color}" />
          </div>
        </div>
        <div class="form-group">
          <label>Description</label>
          <textarea id="affinity-description" rows="4">${affinity.description || ''}</textarea>
        </div>
      </div>
    `;
  }

  function renderPreview(affinity) {
    const background = `conic-gradient(from 0deg at 50% 50%, ${darkenHex(affinity.color, 0.28)} 0deg, ${darkenHex(affinity.color, 0.28)} 360deg)`;
    return `
      <div style="width:250px; background-color:var(--bg-surface); padding:16px; border-radius:8px; border-top:4px solid ${affinity.color};">
        <h4 style="color:var(--text-secondary); margin-bottom:16px;">Frame Showcase</h4>
        <div style="width:200px; height:300px; background:${background}; border-radius:10px; border:3px solid ${affinity.color}; display:flex; flex-direction:column; overflow:hidden; padding:8px; gap:3px; box-sizing:border-box;">
          <div style="padding:7px 8px; background:rgba(10,9,14,0.94); border:1px solid ${affinity.color}; border-radius:9px 9px 0 0; display:flex; justify-content:space-between; gap:8px; align-items:center;">
            <strong style="min-width:0; overflow:hidden; text-overflow:ellipsis; white-space:nowrap;">${affinity.name}</strong>
            <span style="width:24px; height:24px; flex:0 0 24px; border-radius:50%; background:#111; border:1px solid ${affinity.color}; display:inline-flex; align-items:center; justify-content:center;">1</span>
          </div>
          <div style="height:124px; display:flex; align-items:center; justify-content:center; color:var(--text-secondary); background:rgba(12,12,16,0.82); border:1px solid ${affinity.color}; border-radius:0;">Card Art</div>
          <div style="text-align:center; padding:4px; font-size:10px; text-transform:uppercase; letter-spacing:1px; background:rgba(10,9,14,0.92); border:1px solid ${affinity.color}; border-radius:0;">Skill • Self</div>
          <div style="flex:1; min-height:78px; padding:8px; text-align:center; font-size:12px; display:flex; align-items:center; justify-content:center; background:rgba(10,9,14,0.94); border:1px solid ${affinity.color}; border-radius:0 0 9px 9px;">Card text stays readable here.</div>
        </div>
      </div>
    `;
  }

  function darkenHex(hex, amount) {
    const value = String(hex || '').replace('#', '');
    if (!/^[0-9a-fA-F]{6}$/.test(value)) return '#22202a';
    const channels = [0, 2, 4].map(index => parseInt(value.slice(index, index + 2), 16));
    const darkened = channels.map(channel => Math.max(0, Math.min(255, Math.round(channel * (1 - amount)))));
    return `#${darkened.map(channel => channel.toString(16).padStart(2, '0')).join('')}`;
  }

  function attachEvents() {
    container.querySelectorAll('.list-item').forEach(item => {
      item.addEventListener('click', event => {
        selectedId = parseInt(event.currentTarget.dataset.id, 10);
        render();
      });
    });
    const nameInput = container.querySelector('#affinity-name');
    if (!nameInput) return;
    const onChange = () => {
      const affinity = affinities.find(entry => entry.id === selectedId);
      if (!affinity) return;
      affinity.name = nameInput.value.trim() || affinity.key;
      affinity.color = container.querySelector('#affinity-color').value;
      affinity.description = container.querySelector('#affinity-description').value;
      affinities = normalizeElementalAffinityCatalog(affinities);
      store.saveAll('elemental_affinities', affinities);
    };
    container.querySelectorAll('input, textarea').forEach(field => {
      field.addEventListener('change', () => {
        onChange();
        render();
      });
      field.addEventListener('blur', onChange);
    });
  }

  render();
}
