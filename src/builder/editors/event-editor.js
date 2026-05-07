import { store } from '../../data/store.js?v=1778163704';
import { createEvent, createEventOption, createEventCondition, createEventOutcome } from '../../data/models.js?v=1778163704';
import { showConfirmModal } from '../components/modal.js?v=1778163704';

export function renderEventEditor(container) {
  let events = store.getAll('events');
  let consumables = store.getAll('consumables');
  let equipment = store.getAll('equipment');
  let keyItems = store.getAll('keyItems');
  
  let allItems = [
    ...consumables.map(c => ({...c, _typeLabel: 'Consumable'})),
    ...equipment.map(e => ({...e, _typeLabel: 'Equipment'})),
    ...keyItems.map(k => ({...k, _typeLabel: 'Key Item'}))
  ];
  let factions = store.getAll('factions');
  let gameMaps = store.getAll('maps');
  let flags = store.getAll('flags');
  let selectedId = null;

  const STATS = ['health', 'strength', 'dexterity', 'energy', 'handsize'];

  function render() {
    const selectedEvent = events.find(e => e.id === selectedId) || null;

    let scrollPos = 0;
    const existingPane = container.querySelector('.pane-form');
    if (existingPane) {
       scrollPos = existingPane.scrollTop;
    }

    container.innerHTML = `
      <div class="editor-header">
        <h2>Event Editor</h2>
        <button id="btn-create-event" class="primary">+ New Event</button>
      </div>
      <div class="editor-body split-pane">
        
        <!-- List Pane -->
        <div class="pane-list">
          <div class="item-list">
            ${events.map(e => `
              <div class="list-item ${e.id === selectedId ? 'selected' : ''}" data-id="${e.id}">
                <strong style="color: ${e.name ? 'inherit' : 'var(--text-secondary)'}">${e.name || 'Unnamed Event'}</strong>
                <div style="font-size: 0.8em; color: var(--text-secondary); margin-top: 4px;">
                  ${e.options ? e.options.length : 0} options
                </div>
              </div>
            `).join('')}
            ${events.length === 0 ? `<div style="padding:16px; color:var(--text-secondary); text-align:center;">No events created yet.</div>` : ''}
          </div>
        </div>

        <!-- Form Pane -->
        <div class="pane-form">
          ${selectedEvent ? renderForm(selectedEvent) : `<div class="empty-state">Select or create an event to edit.</div>`}
        </div>

      </div>
    `;

    attachEvents();

    const newPane = container.querySelector('.pane-form');
    if (newPane) {
       newPane.scrollTop = scrollPos;
    }
  }

  function renderForm(event) {
    if (!event.options) event.options = [];

    return `
      <div style="max-width: 900px;">
        <div class="form-group">
          <label>Event Name</label>
          <input type="text" id="event-name" value="${event.name}" placeholder="e.g. The Mysterious Shrine" />
        </div>
        <div class="form-group">
          <label>Event Narrative / Description</label>
          <textarea id="event-desc" rows="4" placeholder="You stumble upon a glowing text...">${event.description}</textarea>
        </div>

        <div style="margin-top: 32px;">
          <h3 style="display:flex; justify-content:space-between; align-items:center;">
            Event Options (Choices)
            <button id="btn-add-option" class="primary">+ Add Option</button>
          </h3>
          
          ${event.options.length === 0 ? `<div style="color:var(--text-secondary); font-style:italic;">No options added. The player will be stuck!</div>` : ''}

          ${event.options.map((opt, optIndex) => `
            <div style="background-color: var(--bg-surface); padding: 16px; border: 1px solid var(--border); border-radius: 8px; margin-bottom: 24px;">
              <div style="display:flex; gap: 16px; margin-bottom: 16px; align-items:flex-end;">
                 <div style="flex:1;">
                   <label>Option Button Text</label>
                   <input type="text" class="opt-text" data-opt="${optIndex}" value="${opt.text}" placeholder="e.g. Pray to the shrine" />
                 </div>
                 <div style="display:flex; gap: 4px;">
                   <button class="btn-move-opt-up" data-opt="${optIndex}" ${optIndex === 0 ? 'disabled' : ''}>▲</button>
                   <button class="btn-move-opt-down" data-opt="${optIndex}" ${optIndex === event.options.length - 1 ? 'disabled' : ''}>▼</button>
                   <button class="danger btn-remove-option" data-opt="${optIndex}" style="margin-left:8px;">Delete</button>
                 </div>
              </div>

              <!-- Conditions -->
              <div style="margin-bottom: 16px;">
                 <label style="color:var(--accent);">Conditions (Requirements to pick this option)</label>
                 ${opt.conditions.map((cond, condIndex) => renderConditionForm(cond, optIndex, condIndex)).join('')}
                 <button class="btn-add-condition" data-opt="${optIndex}" style="font-size: 0.8em; margin-top: 8px;">+ Add Condition</button>
              </div>

              <!-- Outcomes -->
              <div>
                 <label style="color:#87ceeb);">Outcomes (What happens if picked)</label>
                 ${opt.outcomes.map((out, outIndex) => renderOutcomeForm(out, optIndex, outIndex)).join('')}
                 <button class="btn-add-outcome" data-opt="${optIndex}" style="font-size: 0.8em; margin-top: 8px;">+ Add Outcome</button>
              </div>
            </div>
          `).join('')}

        </div>

        <div style="margin-top: 32px; padding-top: 16px; border-top: 1px solid var(--border); display: flex; justify-content: space-between;">
          <button id="btn-delete-event" class="danger">Delete Event</button>
        </div>
      </div>
    `;
  }

  function renderConditionForm(cond, optInd, condInd) {
     let targetHTML = '';
     if (cond.type === 'hasStat') {
        targetHTML = `
           <select class="cond-target" data-opt="${optInd}" data-cond="${condInd}" style="width:120px;">
             ${STATS.map(s => `<option value="${s}" ${cond.target === s ? 'selected' : ''}>${s}</option>`).join('')}
           </select>
        `;
     } else if (['hasConsumable', 'lacksConsumable', 'hasEquipment', 'lacksEquipment', 'hasKeyItem', 'lacksKeyItem'].includes(cond.type)) {
        targetHTML = `
           <select class="cond-target" data-opt="${optInd}" data-cond="${condInd}" style="width:150px;">
             <option value="">-- Select Item --</option>
             ${allItems.length === 0 ? '<option value="">No items available</option>' : allItems.map(i => `<option value="${i.id}" ${cond.target === i.id ? 'selected' : ''}>${i.name} (${i._typeLabel})</option>`).join('')}
           </select>
        `;
     } else if (cond.type === 'hasFactionRank') {
        targetHTML = `
           <select class="cond-target" data-opt="${optInd}" data-cond="${condInd}" style="width:150px;">
             <option value="">-- Select Faction --</option>
             ${factions.map(f => `<option value="${f.id}" ${cond.target === f.id ? 'selected' : ''}>${f.name}</option>`).join('')}
           </select>
        `;
     } else if (cond.type === 'checkFlag') {
        targetHTML = `
           <select class="cond-target" data-opt="${optInd}" data-cond="${condInd}" style="width:150px;">
             <option value="">-- Select Flag --</option>
             ${flags.map(f => `<option value="${f.name}" ${cond.target === f.name ? 'selected' : ''}>${f.name}</option>`).join('')}
           </select>
        `;
     } else {
        // hasMoney doesn't need target
        targetHTML = `<input type="hidden" class="cond-target" data-opt="${optInd}" data-cond="${condInd}" value="" />`;
     }

     let opHTML = '';
     let valHTML = '';

     if (['hasMoney', 'hasStat', 'hasConsumable', 'hasEquipment', 'hasKeyItem'].includes(cond.type)) {
        opHTML = `
           <select class="cond-operator" data-opt="${optInd}" data-cond="${condInd}" style="width: 60px;">
             <option value=">=" ${cond.operator === '>=' ? 'selected' : ''}>&gt;=</option>
             <option value="<=" ${cond.operator === '<=' ? 'selected' : ''}>&lt;=</option>
             <option value="==" ${cond.operator === '==' ? 'selected' : ''}>==</option>
           </select>
        `;
        valHTML = `<input type="number" class="cond-val" data-opt="${optInd}" data-cond="${condInd}" value="${cond.value}" placeholder="Value" style="width: 80px;" />`;
     } else if (cond.type === 'checkFlag') {
        opHTML = `<input type="hidden" class="cond-operator" data-opt="${optInd}" data-cond="${condInd}" value="==" />`;
        valHTML = `
           <select class="cond-val" data-opt="${optInd}" data-cond="${condInd}" style="width: 80px;">
             <option value="true" ${String(cond.value).toLowerCase() === 'true' ? 'selected' : ''}>IS ON</option>
             <option value="false" ${String(cond.value).toLowerCase() === 'false' ? 'selected' : ''}>IS OFF</option>
           </select>
        `;
     } else {
        opHTML = `<input type="hidden" class="cond-operator" data-opt="${optInd}" data-cond="${condInd}" value="==" />`;
        valHTML = `<input type="hidden" class="cond-val" data-opt="${optInd}" data-cond="${condInd}" value="" />`;
     }

     return `
       <div style="display:flex; gap: 8px; margin-bottom: 8px; align-items:center;">
          <select class="cond-type" data-opt="${optInd}" data-cond="${condInd}" style="width: 150px;">
            <option value="hasMoney" ${cond.type === 'hasMoney' ? 'selected' : ''}>Has Money</option>
            <option value="hasStat" ${cond.type === 'hasStat' ? 'selected' : ''}>Has Stat</option>
            <option value="hasConsumable" ${cond.type === 'hasConsumable' ? 'selected' : ''}>Has Consumable</option>
            <option value="lacksConsumable" ${cond.type === 'lacksConsumable' ? 'selected' : ''}>Lacks Consumable</option>
            <option value="hasEquipment" ${cond.type === 'hasEquipment' ? 'selected' : ''}>Has Equipment</option>
            <option value="lacksEquipment" ${cond.type === 'lacksEquipment' ? 'selected' : ''}>Lacks Equipment</option>
            <option value="hasKeyItem" ${cond.type === 'hasKeyItem' ? 'selected' : ''}>Has Key Item</option>
            <option value="lacksKeyItem" ${cond.type === 'lacksKeyItem' ? 'selected' : ''}>Lacks Key Item</option>
            <option value="hasFactionRank" ${cond.type === 'hasFactionRank' ? 'selected' : ''}>Has Faction Rank</option>
            <option value="checkFlag" ${cond.type === 'checkFlag' ? 'selected' : ''}>Check Flag</option>
          </select>
          ${targetHTML}
          ${opHTML}
          ${valHTML}
          <button class="danger btn-remove-cond" data-opt="${optInd}" data-cond="${condInd}">X</button>
       </div>
     `;
  }

   function renderOutcomeForm(out, optInd, outInd) {
     let targetHTML = '';
     let valHTML = '';

     if (['addConsumable', 'removeConsumable', 'addEquipment', 'removeEquipment', 'addKeyItem', 'removeKeyItem'].includes(out.type)) {
        targetHTML = `
           <select class="out-target" data-opt="${optInd}" data-out="${outInd}" style="width:150px;">
             <option value="">-- Select Item --</option>
             ${allItems.length === 0 ? '<option value="">No items available</option>' : allItems.map(i => `<option value="${i.id}" ${out.target === i.id ? 'selected' : ''}>${i.name} (${i._typeLabel})</option>`).join('')}
           </select>
        `;
        valHTML = `<input type="number" class="out-val" data-opt="${optInd}" data-out="${outInd}" value="${out.value}" placeholder="Amount" style="width: 80px;" />`;
     } else if (out.type === 'modifyStat') {
        targetHTML = `
           <select class="out-target" data-opt="${optInd}" data-out="${outInd}" style="width:120px;">
             ${STATS.map(s => `<option value="${s}" ${out.target === s ? 'selected' : ''}>${s}</option>`).join('')}
           </select>
        `;
        valHTML = `<input type="number" class="out-val" data-opt="${optInd}" data-out="${outInd}" value="${out.value}" placeholder="Amount" style="width: 80px;" />`;
     } else if (out.type === 'travelToMap') {
        targetHTML = `
           <select class="out-target" data-opt="${optInd}" data-out="${outInd}" style="width:150px;">
             <option value="">-- Select Map --</option>
             ${gameMaps.map(m => `<option value="${m.id}" ${out.target === m.id ? 'selected' : ''}>${m.name}${m.isOverworld ? ' (Overworld)' : ''}</option>`).join('')}
           </select>
        `;
        valHTML = `<input type="hidden" class="out-val" data-opt="${optInd}" data-out="${outInd}" value="" />`;
     } else if (out.type === 'startEvent') {
        targetHTML = `
           <select class="out-target" data-opt="${optInd}" data-out="${outInd}" style="width:150px;">
             <option value="">-- Select Event --</option>
             ${events.map(e => `<option value="${e.id}" ${out.target === e.id ? 'selected' : ''}>${e.name}</option>`).join('')}
           </select>
        `;
        valHTML = `<input type="hidden" class="out-val" data-opt="${optInd}" data-out="${outInd}" value="" />`;
     } else if (out.type === 'setFlag') {
        targetHTML = `
           <select class="out-target" data-opt="${optInd}" data-out="${outInd}" style="width:150px;">
             <option value="">-- Select Flag --</option>
             ${flags.map(f => `<option value="${f.name}" ${out.target === f.name ? 'selected' : ''}>${f.name}</option>`).join('')}
           </select>
        `;
        valHTML = `
           <select class="out-val" data-opt="${optInd}" data-out="${outInd}" style="width: 80px;">
             <option value="true" ${String(out.value).toLowerCase() === 'true' ? 'selected' : ''}>ON</option>
             <option value="false" ${String(out.value).toLowerCase() === 'false' ? 'selected' : ''}>OFF</option>
           </select>
        `;
     } else if (['addMoney', 'removeMoney', 'damage', 'heal'].includes(out.type)) {
        targetHTML = `<input type="hidden" class="out-target" data-opt="${optInd}" data-out="${outInd}" value="" />`;
        valHTML = `<input type="number" class="out-val" data-opt="${optInd}" data-out="${outInd}" value="${out.value}" placeholder="Amount" style="width: 80px;" />`;
     } else if (['addCard', 'removeCard'].includes(out.type)) {
        targetHTML = `<input type="text" class="out-target" data-opt="${optInd}" data-out="${outInd}" value="${out.target}" placeholder="Card ID" style="width: 150px;" />`;
        valHTML = `<input type="hidden" class="out-val" data-opt="${optInd}" data-out="${outInd}" value="" />`;
     } else if (out.type === 'text') {
        targetHTML = `<input type="hidden" class="out-target" data-opt="${optInd}" data-out="${outInd}" value="" />`;
        valHTML = `<input type="text" class="out-val" data-opt="${optInd}" data-out="${outInd}" value="${out.value}" placeholder="Log text..." style="flex: 1;" />`;
     } else {
        targetHTML = `<input type="text" class="out-target" data-opt="${optInd}" data-out="${outInd}" value="${out.target}" placeholder="Target ID" style="width: 150px;" />`;
        valHTML = `<input type="text" class="out-val" data-opt="${optInd}" data-out="${outInd}" value="${out.value}" placeholder="Value" style="width: 80px;" />`;
     }

     return `
       <div style="display:flex; gap: 8px; margin-bottom: 8px; align-items:center;">
          <select class="out-type" data-opt="${optInd}" data-out="${outInd}" style="width: 150px;">
            <option value="text" ${out.type === 'text' ? 'selected' : ''}>Show Text (Log)</option>
            <option value="addConsumable" ${out.type === 'addConsumable' ? 'selected' : ''}>Add Consumable</option>
            <option value="removeConsumable" ${out.type === 'removeConsumable' ? 'selected' : ''}>Remove Consumable</option>
            <option value="addEquipment" ${out.type === 'addEquipment' ? 'selected' : ''}>Add Equipment</option>
            <option value="removeEquipment" ${out.type === 'removeEquipment' ? 'selected' : ''}>Remove Equipment</option>
            <option value="addKeyItem" ${out.type === 'addKeyItem' ? 'selected' : ''}>Add Key Item</option>
            <option value="removeKeyItem" ${out.type === 'removeKeyItem' ? 'selected' : ''}>Remove Key Item</option>
            <option value="addCard" ${out.type === 'addCard' ? 'selected' : ''}>Add Card</option>
            <option value="removeCard" ${out.type === 'removeCard' ? 'selected' : ''}>Remove Card</option>
            <option value="addMoney" ${out.type === 'addMoney' ? 'selected' : ''}>Add Money</option>
            <option value="removeMoney" ${out.type === 'removeMoney' ? 'selected' : ''}>Remove Money</option>
            <option value="damage" ${out.type === 'damage' ? 'selected' : ''}>Damage Player</option>
            <option value="heal" ${out.type === 'heal' ? 'selected' : ''}>Heal Player</option>
            <option value="modifyStat" ${out.type === 'modifyStat' ? 'selected' : ''}>Modify Stat</option>
            <option value="travelToMap" ${out.type === 'travelToMap' ? 'selected' : ''}>Travel to Map</option>
            <option value="startEvent" ${out.type === 'startEvent' ? 'selected' : ''}>Start Event</option>
            <option value="setFlag" ${out.type === 'setFlag' ? 'selected' : ''}>Set Flag</option>
          </select>
          ${targetHTML}
          ${valHTML}
          <button class="danger btn-remove-out" data-opt="${optInd}" data-out="${outInd}">X</button>
       </div>
     `;
  }

  function attachEvents() {
    container.querySelector('#btn-create-event')?.addEventListener('click', () => {
      const e = createEvent();
      store.save('events', e);
      events = store.getAll('events');
      selectedId = e.id;
      render();
    });

    container.querySelectorAll('.list-item').forEach(el => {
      el.addEventListener('click', (e) => {
        selectedId = e.currentTarget.dataset.id;
        render();
      });
    });

    const nameInput = container.querySelector('#event-name');
    if (!nameInput) return;

    // A universal saver since this form is quite complex
    const saveEvent = () => {
       const e = events.find(x => x.id === selectedId);
       e.name = container.querySelector('#event-name').value;
       e.description = container.querySelector('#event-desc').value;
       
       // update options texts
       container.querySelectorAll('.opt-text').forEach(inp => {
          e.options[parseInt(inp.dataset.opt)].text = inp.value;
       });

       // update conditions
       container.querySelectorAll('.cond-type').forEach(sel => {
          const optI = parseInt(sel.dataset.opt);
          const condI = parseInt(sel.dataset.cond);
          const cond = e.options[optI].conditions[condI];
          
          cond.type = sel.value;
          cond.operator = container.querySelector(`.cond-operator[data-opt="${optI}"][data-cond="${condI}"]`).value;
          cond.value = container.querySelector(`.cond-val[data-opt="${optI}"][data-cond="${condI}"]`).value;
          
          const targetInp = container.querySelector(`.cond-target[data-opt="${optI}"][data-cond="${condI}"]`);
          if(targetInp) cond.target = targetInp.value;
       });

       // update outcomes
       container.querySelectorAll('.out-type').forEach(sel => {
          const optI = parseInt(sel.dataset.opt);
          const outI = parseInt(sel.dataset.out);
          const out = e.options[optI].outcomes[outI];
          
          out.type = sel.value;
          out.value = container.querySelector(`.out-val[data-opt="${optI}"][data-out="${outI}"]`).value;
          
          const targetInp = container.querySelector(`.out-target[data-opt="${optI}"][data-out="${outI}"]`);
          if(targetInp) out.target = targetInp.value;
       });

       store.save('events', e);
    };

    container.querySelector('#event-name').addEventListener('blur', () => { saveEvent(); render(); });
    container.querySelector('#event-desc').addEventListener('blur', () => { saveEvent(); render(); });
    
    // Any input change saves
    container.querySelectorAll('.opt-text, .cond-operator, .cond-val, .cond-target, .out-val, .out-target').forEach(inp => {
        inp.addEventListener('blur', () => { saveEvent(); render(); });
    });

    // Structual changes redraw immediately
    container.querySelectorAll('.cond-type, .out-type').forEach(sel => {
        sel.addEventListener('change', () => { saveEvent(); render(); });
    });

    container.querySelector('#btn-add-option').addEventListener('click', () => {
       const e = events.find(x => x.id === selectedId);
       e.options.push(createEventOption());
       store.save('events', e);
       render();
    });

    container.querySelectorAll('.btn-move-opt-up').forEach(btn => {
      btn.addEventListener('click', (ev) => {
         const optInd = parseInt(ev.currentTarget.dataset.opt);
         if (optInd > 0) {
            const e = events.find(x => x.id === selectedId);
            const temp = e.options[optInd - 1];
            e.options[optInd - 1] = e.options[optInd];
            e.options[optInd] = temp;
            store.save('events', e);
            render();
         }
      });
    });

    container.querySelectorAll('.btn-move-opt-down').forEach(btn => {
      btn.addEventListener('click', (ev) => {
         const optInd = parseInt(ev.currentTarget.dataset.opt);
         const e = events.find(x => x.id === selectedId);
         if (optInd < e.options.length - 1) {
            const temp = e.options[optInd + 1];
            e.options[optInd + 1] = e.options[optInd];
            e.options[optInd] = temp;
            store.save('events', e);
            render();
         }
      });
    });

    container.querySelectorAll('.btn-add-condition').forEach(btn => {
       btn.addEventListener('click', (ev) => {
          const oIdx = parseInt(ev.currentTarget.dataset.opt);
          const e = events.find(x => x.id === selectedId);
          e.options[oIdx].conditions.push(createEventCondition());
          store.save('events', e);
          render();
       });
    });

    container.querySelectorAll('.btn-add-outcome').forEach(btn => {
       btn.addEventListener('click', (ev) => {
          const oIdx = parseInt(ev.currentTarget.dataset.opt);
          const e = events.find(x => x.id === selectedId);
          e.options[oIdx].outcomes.push(createEventOutcome());
          store.save('events', e);
          render();
       });
    });

    container.querySelectorAll('.btn-remove-option').forEach(btn => {
       btn.addEventListener('click', (ev) => {
          showConfirmModal('Delete this option?', () => {
            const oIdx = parseInt(ev.currentTarget.dataset.opt);
            const e = events.find(x => x.id === selectedId);
            e.options.splice(oIdx, 1);
            store.save('events', e);
            render();
          });
       });
    });

    container.querySelectorAll('.btn-remove-cond').forEach(btn => {
       btn.addEventListener('click', (ev) => {
          const oIdx = parseInt(ev.currentTarget.dataset.opt);
          const cIdx = parseInt(ev.currentTarget.dataset.cond);
          const e = events.find(x => x.id === selectedId);
          e.options[oIdx].conditions.splice(cIdx, 1);
          store.save('events', e);
          render();
       });
    });

    container.querySelectorAll('.btn-remove-out').forEach(btn => {
       btn.addEventListener('click', (ev) => {
          const oIdx = parseInt(ev.currentTarget.dataset.opt);
          const outIdx = parseInt(ev.currentTarget.dataset.out);
          const e = events.find(x => x.id === selectedId);
          e.options[oIdx].outcomes.splice(outIdx, 1);
          store.save('events', e);
          render();
       });
    });

    container.querySelector('#btn-delete-event').addEventListener('click', () => {
      showConfirmModal('Are you sure you want to delete this event?', () => {
         store.remove('events', selectedId);
         events = store.getAll('events');
         selectedId = null;
         render();
      });
    });

  }

  render();
}
