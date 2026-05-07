import { store } from '../../data/store.js?v=1778164258';
import { createGameMap, createMapNode, createMapConnection, createEventCondition, createEventOption, createEventOutcome } from '../../data/models.js?v=1778164258';
import { showConfirmModal } from '../components/modal.js?v=1778164258';

export function renderMapEditor(container) {
  let maps = store.getAll('maps');
  let events = store.getAll('events');
  let enemies = store.getAll('enemies');
  let factions = store.getAll('factions');
  let flags = store.getAll('flags');
  
  let consumables = store.getAll('consumables');
  let equipment = store.getAll('equipment');
  let keyItems = store.getAll('keyItems');
  
  let allItems = [
    ...consumables.map(c => ({...c, _typeLabel: 'Consumable'})),
    ...equipment.map(e => ({...e, _typeLabel: 'Equipment'})),
    ...keyItems.map(k => ({...k, _typeLabel: 'Key Item'}))
  ];
  
  let selectedMapId = null;
  let selectedNodeId = null;
  let dragNode = null;
  let dragStartPos = { x: 0, y: 0 };
  let isConnecting = false;
  let connectionStartNode = null;
  let mousePos = { x: 0, y: 0 };
  let selectedConnectionId = null;
  let loadedImages = {};
  
  let panX = 0;
  let panY = 0;
  let zoom = 1;
  let isPanning = false;
  let panStart = { x: 0, y: 0 };

  const STATS = ['health', 'strength', 'dexterity', 'energy', 'handsize'];

  const NODE_RADIUS = 20;

  function render() {
    const selectedMap = maps.find(m => m.id === selectedMapId) || null;
    const overworld = maps.find(m => m.isOverworld);

    container.innerHTML = `
      <div class="editor-header">
        <h2>Map Editor (Node Graph)</h2>
        <div>
           ${!overworld ? `<button id="btn-create-overworld" class="primary">+ Create Overworld</button>` : `<button id="btn-create-submap">+ Create Submap</button>`}
        </div>
      </div>
      <div class="editor-body split-pane">
        
        <!-- List Pane (Hierarchy) -->
        <div class="pane-list" style="width: 250px;">
          <div class="list-toolbar">
             <strong>Map Hierarchy</strong>
          </div>
          <div class="item-list">
             ${renderMapTree(overworld)}
          </div>
        </div>

        <!-- Canvas Pane -->
        <div class="pane-form" style="position:relative; display:flex; flex-direction:column; padding: 0;">
          ${selectedMap ? `
            <div style="padding: 16px; border-bottom: 1px solid var(--border); display:flex; gap: 16px; background:var(--bg-surface); flex-wrap:wrap;">
              <input type="text" id="map-name" value="${selectedMap.name}" placeholder="Map Name" style="flex:1; min-width:150px;" />
              <div style="display:flex; align-items:center; gap:8px;">
                <input type="text" id="map-bg" value="${selectedMap.backgroundImage || ''}" placeholder="e.g. assets/maps/overworld.png" style="flex:2; min-width:200px; font-size:0.85em;" />
                <input type="file" id="map-bg-upload" accept="image/*" style="width: 200px; font-size:0.8em;" />
              </div>
              ${selectedMap.isOverworld ? `<span style="align-self:center; color:var(--accent);">★ Overworld</span>` : `
                 <button id="btn-delete-map" class="danger">Delete Map</button>
              `}
            </div>
            <div style="padding: 8px 16px; background: #111; font-size: 0.8em; color:var(--text-secondary); display:flex; justify-content:space-between;">
               <span>Dbl-click: create node · Shift+drag: connect · Click arrow: select connection</span>
               <span>Nodes: ${selectedMap.nodes.length} | Connections: ${selectedMap.connections.length}</span>
            </div>
            
            <div style="flex:1; display:flex;">
               <!-- Canvas Area -->
               <div style="flex:1; position:relative; overflow:hidden;" id="canvas-container">
                  <canvas id="map-canvas" style="background:#1a1a1a; cursor:crosshair; width:100%; height:100%; display:block;"></canvas>
               </div>
               
               <!-- Node / Connection Inspector -->
               ${selectedNodeId ? renderNodeInspector(selectedMap.nodes.find(n => n.id === selectedNodeId)) : 
                 selectedConnectionId ? renderConnectionInspector(selectedMap.connections.find(c => c.id === selectedConnectionId), selectedMap) : `
                 <div style="width: 280px; background:var(--bg-surface); border-left:1px solid var(--border); padding:16px;">
                    <div class="empty-state">Select a node or connection</div>
                 </div>
               `}
            </div>
          ` : `<div class="empty-state" style="padding: 32px;">Select or create a map to edit.</div>`}
        </div>

      </div>
    `;

    attachEvents();
    if (selectedMap) {
      initCanvas();
    }
  }

  function renderMapTree(mapNode, depth = 0) {
     if (!mapNode) return '<div style="padding:16px; color:var(--text-secondary);">No maps exist.</div>';
     
     let html = `
       <div class="list-item ${mapNode.id === selectedMapId ? 'selected' : ''}" data-id="${mapNode.id}" style="padding-left: ${16 + depth * 16}px;">
         ${depth > 0 ? '↳ ' : ''}<strong style="color: ${mapNode.name ? 'inherit' : 'var(--text-secondary)'}">${mapNode.name || 'Unnamed Map'}</strong>
       </div>
     `;

     // Find children where a node links to this map
     const childMaps = maps.filter(m => m.parentMapId === mapNode.id);
     childMaps.forEach(child => {
        html += renderMapTree(child, depth + 1);
     });

     // Floating unlinked maps
     if (depth === 0) {
        const unlinked = maps.filter(m => !m.isOverworld && !m.parentMapId);
        if (unlinked.length > 0) {
           html += `<div style="padding: 8px 16px; color:var(--text-secondary); font-size:0.8em; margin-top:16px; border-top:1px solid var(--border);">Unlinked Maps</div>`;
           unlinked.forEach(u => {
              html += `
                 <div class="list-item ${u.id === selectedMapId ? 'selected' : ''}" data-id="${u.id}" style="padding-left: 16px;">
                    <strong style="color: ${u.name ? 'inherit' : 'var(--text-secondary)'}">${u.name || 'Unnamed Map'}</strong>
                 </div>
              `;
           });
        }
     }

     return html;
  }

  function renderNodeInspector(node) {
     if (!node) return '';
     if (!node.options) node.options = [];

     return `
        <div style="width: 350px; background:var(--bg-surface); border-left:1px solid var(--border); padding:16px; display:flex; flex-direction:column; overflow-y:auto;">
           <h3>Location Inspector</h3>
           
           <div class="form-group">
             <label>Name</label>
             <input type="text" id="node-label" value="${node.label}" placeholder="e.g. Old Oak Crossroads" />
           </div>

           <div class="form-row" style="display:flex; gap:8px;">
             <div class="form-group" style="flex:1;">
               <label>X Pos</label>
               <input type="number" id="node-x" value="${Math.round(node.x)}" />
             </div>
             <div class="form-group" style="flex:1;">
               <label>Y Pos</label>
               <input type="number" id="node-y" value="${Math.round(node.y)}" />
             </div>
           </div>

           <div class="form-group">
             <label>Description</label>
             <textarea id="node-desc" rows="2" placeholder="What the player sees...">${node.description || ''}</textarea>
           </div>

           <div style="margin-top:16px;">
             <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:8px;">
               <label style="color:var(--accent); margin:0;">Options (Choices)</label>
               <button id="btn-add-node-opt" style="font-size:0.8em;">+ Add Option</button>
             </div>
             ${node.options.length === 0 ? '<div style="color:var(--text-secondary); font-size:0.85em;">No options yet.</div>' : ''}
             ${node.options.map((opt, oi) => `
               <div style="background:#1a1a1a; border:1px solid var(--border); border-radius:4px; padding:8px; margin-bottom:8px;">
                 <div style="display:flex; gap:4px; margin-bottom:6px;">
                   <input type="text" class="node-opt-text" data-oi="${oi}" value="${opt.text}" placeholder="Option text" style="flex:1; font-size:0.85em;" />
                   <select class="node-opt-lock-type" data-oi="${oi}" style="width: 80px; font-size:0.8em; padding:2px;">
                     <option value="soft" ${opt.lockType === 'soft' ? 'selected' : ''}>Soft Lock</option>
                     <option value="hard" ${opt.lockType === 'hard' ? 'selected' : ''}>Hard Lock</option>
                   </select>
                   <button class="btn-move-node-opt-up" data-oi="${oi}" ${oi === 0 ? 'disabled' : ''} style="padding:2px 4px;">▲</button>
                   <button class="btn-move-node-opt-down" data-oi="${oi}" ${oi === node.options.length - 1 ? 'disabled' : ''} style="padding:2px 4px;">▼</button>
                   <button class="danger btn-rm-node-opt" data-oi="${oi}" style="padding:2px 6px;">X</button>
                 </div>

                 <div style="margin-bottom:4px;">
                   <span style="font-size:0.75em; color:var(--accent);">Conditions</span>
                   ${opt.conditions.map((c, ci) => `
                     <div style="display:flex; gap:3px; margin-top:3px; font-size:0.8em;">
                       <select class="noc-type" data-oi="${oi}" data-ci="${ci}" style="flex:1;">
                         ${renderConditionTypeOptions(c.type)}
                       </select>
                       ${renderConditionTarget(c, oi, ci, 'noc')}
                       ${renderConditionOpAndVal(c, oi, ci, 'noc')}
                       <button class="danger btn-rm-noc" data-oi="${oi}" data-ci="${ci}" style="padding:1px 4px;">x</button>
                     </div>
                   `).join('')}
                   <button class="btn-add-noc" data-oi="${oi}" style="font-size:0.75em; margin-top:3px;">+ Condition</button>
                 </div>

                 <div>
                   <span style="font-size:0.75em; color:#87ceeb;">Outcomes</span>
                   ${opt.outcomes.map((o, oui) => `
                     <div style="display:flex; gap:3px; margin-top:3px; font-size:0.8em;">
                       <select class="noo-type" data-oi="${oi}" data-oui="${oui}" style="flex:1;">
                         ${renderOutcomeTypeOptions(o.type)}
                       </select>
                       ${renderOutcomeTarget(o, oi, oui)}
                       ${renderOutcomeVal(o, oi, oui)}
                       <button class="danger btn-rm-noo" data-oi="${oi}" data-oui="${oui}" style="padding:1px 4px;">x</button>
                     </div>
                   `).join('')}
                   <button class="btn-add-noo" data-oi="${oi}" style="font-size:0.75em; margin-top:3px;">+ Outcome</button>
                 </div>
               </div>
             `).join('')}
           </div>

           <div style="margin-top: auto; padding-top: 16px;">
             <button id="btn-delete-node" class="danger">Delete Node</button>
           </div>
        </div>
     `;
  }

  function renderConditionTypeOptions(selected) {
     const types = [
       ['hasMoney','Has Money'],['hasStat','Has Stat'],
       ['hasConsumable','Has Consumable'],['hasEquipment','Has Equipment'],
       ['hasKeyItem','Has Key Item'],['lacksKeyItem','Lacks Key Item'],
       ['hasFactionRank','Has Faction Rank'],['checkFlag','Check Flag']
     ];
     return types.map(([v,l]) => `<option value="${v}" ${selected===v?'selected':''}>${l}</option>`).join('');
  }

  function renderOpOptions(selected) {
     return ['>=','<=','=='].map(v => `<option value="${v}" ${selected===v?'selected':''}>${v.replace('<','&lt;').replace('>','&gt;')}</option>`).join('');
  }

  function renderConditionTarget(cond, oi, ci, prefix) {
     if (cond.type === 'hasStat') {
        return `<select class="${prefix}-target" data-oi="${oi}" data-ci="${ci}" style="flex:1;">
          ${STATS.map(s => `<option value="${s}" ${cond.target===s?'selected':''}>${s}</option>`).join('')}
        </select>`;
     } else if (['hasConsumable','lacksConsumable','hasEquipment','lacksEquipment','hasKeyItem','lacksKeyItem'].includes(cond.type)) {
        return `<select class="${prefix}-target" data-oi="${oi}" data-ci="${ci}" style="flex:1;">
          <option value="">--</option>
          ${allItems.map(i => `<option value="${i.id}" ${cond.target===i.id?'selected':''}>${i.name}</option>`).join('')}
        </select>`;
     } else if (cond.type === 'hasFactionRank') {
        return `<select class="${prefix}-target" data-oi="${oi}" data-ci="${ci}" style="flex:1;">
          <option value="">--</option>
          ${factions.map(f => `<option value="${f.id}" ${cond.target===f.id?'selected':''}>${f.name}</option>`).join('')}
        </select>`;
     } else if (cond.type === 'checkFlag') {
        return `<select class="${prefix}-target" data-oi="${oi}" data-ci="${ci}" style="flex:1;">
          <option value="">--</option>
          ${flags.map(f => `<option value="${f.name}" ${cond.target===f.name?'selected':''}>${f.name}</option>`).join('')}
        </select>`;
     }
     return `<input type="hidden" class="${prefix}-target" data-oi="${oi}" data-ci="${ci}" value="" />`;
  }

  function renderConditionOpAndVal(cond, oi, ci, prefix) {
     if (['hasMoney', 'hasStat', 'hasConsumable', 'hasEquipment', 'hasKeyItem'].includes(cond.type)) {
        return `
          <select class="${prefix}-op" data-oi="${oi}" data-ci="${ci}" style="width:40px;">${renderOpOptions(cond.operator)}</select>
          <input type="number" class="${prefix}-val" data-oi="${oi}" data-ci="${ci}" value="${cond.value}" style="width:40px;" />
        `;
     } else if (cond.type === 'checkFlag') {
        return `
          <input type="hidden" class="${prefix}-op" data-oi="${oi}" data-ci="${ci}" value="==" />
          <select class="${prefix}-val" data-oi="${oi}" data-ci="${ci}" style="width:50px;">
            <option value="true" ${String(cond.value).toLowerCase() === 'true' ? 'selected' : ''}>ON</option>
            <option value="false" ${String(cond.value).toLowerCase() === 'false' ? 'selected' : ''}>OFF</option>
          </select>
        `;
     }
     return `
        <input type="hidden" class="${prefix}-op" data-oi="${oi}" data-ci="${ci}" value="==" />
        <input type="hidden" class="${prefix}-val" data-oi="${oi}" data-ci="${ci}" value="" />
     `;
  }

  function renderOutcomeTypeOptions(selected) {
     const types = [
       ['text','Show Text'],['addConsumable','Add Consumable'],['removeConsumable','Remove Consumable'],
       ['addEquipment','Add Equipment'],['removeEquipment','Remove Equipment'],
       ['addKeyItem','Add Key Item'],['removeKeyItem','Remove Key Item'],
       ['addCard','Add Card'],['removeCard','Remove Card'],
       ['addMoney','Add Money'],['removeMoney','Remove Money'],
       ['damage','Damage'],['heal','Heal'],['modifyStat','Modify Stat'],
       ['travelToMap','Travel to Map'],['startCombat','Start Combat'],['startEvent','Start Event'],
       ['setFlag','Set Flag']
     ];
     return types.map(([v,l]) => `<option value="${v}" ${selected===v?'selected':''}>${l}</option>`).join('');
  }

  function renderOutcomeTarget(out, oi, oui) {
     if (['addConsumable','removeConsumable','addEquipment','removeEquipment','addKeyItem','removeKeyItem'].includes(out.type)) {
        return `<select class="noo-target" data-oi="${oi}" data-oui="${oui}" style="flex:1;">
          <option value="">--</option>
          ${allItems.map(i => `<option value="${i.id}" ${out.target===i.id?'selected':''}>${i.name}</option>`).join('')}
        </select>`;
     } else if (out.type === 'modifyStat') {
        return `<select class="noo-target" data-oi="${oi}" data-oui="${oui}" style="flex:1;">
          ${STATS.map(s => `<option value="${s}" ${out.target===s?'selected':''}>${s}</option>`).join('')}
        </select>`;
     } else if (out.type === 'travelToMap') {
        return `<select class="noo-target" data-oi="${oi}" data-oui="${oui}" style="flex:1;">
          <option value="">--</option>
          ${gameMaps.map(m => `<option value="${m.id}" ${out.target===m.id?'selected':''}>${m.name}</option>`).join('')}
        </select>`;
     } else if (out.type === 'startCombat') {
        return `<select class="noo-target" data-oi="${oi}" data-oui="${oui}" style="flex:1;">
          <option value="">--</option>
          ${enemies.map(e => `<option value="${e.id}" ${out.target===e.id?'selected':''}>${e.name}</option>`).join('')}
        </select>`;
     } else if (out.type === 'startEvent') {
        return `<select class="noo-target" data-oi="${oi}" data-oui="${oui}" style="flex:1;">
          <option value="">--</option>
          ${events.map(e => `<option value="${e.id}" ${out.target===e.id?'selected':''}>${e.name}</option>`).join('')}
        </select>`;
     } else if (out.type === 'setFlag') {
        return `<select class="noo-target" data-oi="${oi}" data-oui="${oui}" style="flex:1;">
          <option value="">--</option>
          ${flags.map(f => `<option value="${f.name}" ${out.target===f.name?'selected':''}>${f.name}</option>`).join('')}
        </select>`;
     } else if (['addMoney', 'removeMoney', 'damage', 'heal'].includes(out.type)) {
        return `<input type="hidden" class="noo-target" data-oi="${oi}" data-oui="${oui}" value="" />`;
     } else if (['addCard', 'removeCard'].includes(out.type)) {
        return `<input type="text" class="noo-target" data-oi="${oi}" data-oui="${oui}" value="${out.target}" placeholder="Card ID" style="flex:1;" />`;
     } else if (out.type === 'text') {
        return `<input type="hidden" class="noo-target" data-oi="${oi}" data-oui="${oui}" value="" />`;
     }
     return `<input type="text" class="noo-target" data-oi="${oi}" data-oui="${oui}" value="${out.target}" placeholder="target" style="flex:1;" />`;
  }

  function renderOutcomeVal(out, oi, oui) {
     if (['travelToMap', 'startEvent', 'startCombat', 'addCard', 'removeCard'].includes(out.type)) {
        return `<input type="hidden" class="noo-val" data-oi="${oi}" data-oui="${oui}" value="" />`;
     } else if (out.type === 'setFlag') {
        return `
          <select class="noo-val" data-oi="${oi}" data-oui="${oui}" style="width:50px;">
            <option value="true" ${String(out.value).toLowerCase() === 'true' ? 'selected' : ''}>ON</option>
            <option value="false" ${String(out.value).toLowerCase() === 'false' ? 'selected' : ''}>OFF</option>
          </select>
        `;
     } else if (out.type === 'text') {
        return `<input type="text" class="noo-val" data-oi="${oi}" data-oui="${oui}" value="${out.value}" placeholder="log text..." style="flex:1;" />`;
     }
     // Default for money, stats, damage, heal
     return `<input type="number" class="noo-val" data-oi="${oi}" data-oui="${oui}" value="${out.value}" style="width:40px;" placeholder="val" />`;
  }

  function renderConnectionInspector(conn, map) {
     if (!conn) return '';
     const fromNode = map.nodes.find(n => n.id === conn.fromNodeId);
     const toNode = map.nodes.find(n => n.id === conn.toNodeId);
     if (!conn.conditions) conn.conditions = [];

     return `
        <div style="width: 280px; background:var(--bg-surface); border-left:1px solid var(--border); padding:16px; display:flex; flex-direction:column; overflow-y:auto;">
           <h3>Connection Inspector</h3>
           <div style="color:var(--text-secondary); font-size:0.85em; margin-bottom:16px;">
             ${fromNode ? (fromNode.label || fromNode.type) : '?'} → ${toNode ? (toNode.label || toNode.type) : '?'}
           </div>

           <div class="form-group">
             <label>Gate Type</label>
             <select id="conn-gate-type">
               <option value="none" ${conn.gateType === 'none' ? 'selected' : ''}>None (Always Open)</option>
               <option value="soft" ${conn.gateType === 'soft' ? 'selected' : ''}>Soft (Visible but Locked)</option>
               <option value="hard" ${conn.gateType === 'hard' ? 'selected' : ''}>Hard (Hidden Until Met)</option>
             </select>
           </div>

           <div class="form-group" style="margin-top:16px;">
             <label style="color:var(--accent);">Travel Conditions</label>
             ${conn.conditions.length === 0 ? '<div style="color:var(--text-secondary); font-size:0.85em; margin-bottom:8px;">No conditions — path is open.</div>' : ''}
             ${conn.conditions.map((cond, idx) => `
                  <div style="background:#1a1a1a; padding:8px; border:1px solid var(--border); margin-bottom:6px; border-radius:4px;">
                    <div style="display:flex; gap:4px; margin-bottom:4px;">
                      <select class="conn-cond-type" data-ci="${idx}" style="flex:1; font-size:0.85em;">
                        ${renderConditionTypeOptions(cond.type)}
                      </select>
                      <button class="danger btn-remove-conn-cond" data-ci="${idx}" style="padding:2px 6px;">X</button>
                    </div>
                    <div style="display:flex; gap:4px;">
                      ${renderConditionTarget(cond, null, idx, 'conn-cond')}
                      ${renderConditionOpAndVal(cond, null, idx, 'conn-cond')}
                    </div>
                  </div>
                `).join('')}
             <button id="btn-add-conn-cond" style="font-size:0.85em; margin-top:4px;">+ Add Condition</button>
           </div>

           <div style="margin-top:auto; padding-top:16px; display:flex; gap:8px;">
             <button id="btn-delete-conn" class="danger" style="flex:1;">Delete Connection</button>
           </div>
        </div>
     `;
  }

  function initCanvas() {
     const canvas = document.getElementById('map-canvas');
     const container = document.getElementById('canvas-container');
     if (!canvas || !container) return;

     // Sync size
     function resize() {
        canvas.width = container.clientWidth;
        canvas.height = container.clientHeight;
        drawCanvas();
     }
     window.addEventListener('resize', resize);
     resize();

     function screenToWorld(x, y) {
        return { x: (x - panX) / zoom, y: (y - panY) / zoom };
     }

     canvas.addEventListener('contextmenu', e => e.preventDefault());

     canvas.addEventListener('wheel', (e) => {
         e.preventDefault();
         if (e.ctrlKey) {
             // Pinch zoom or Ctrl+Scroll
             const rect = canvas.getBoundingClientRect();
             const mouseX = e.clientX - rect.left;
             const mouseY = e.clientY - rect.top;
             
             const zoomIntensity = e.deltaY * -0.01;
             const newZoom = Math.max(0.1, Math.min(zoom * Math.exp(zoomIntensity), 5));
             
             panX = mouseX - (mouseX - panX) * (newZoom / zoom);
             panY = mouseY - (mouseY - panY) * (newZoom / zoom);
             zoom = newZoom;
         } else {
             // Two-finger pan or regular scroll
             panX -= e.deltaX;
             panY -= e.deltaY;
         }
         drawCanvas();
     });

     canvas.addEventListener('mousedown', (e) => {
        if (e.button === 1 || e.button === 2) {
            e.preventDefault();
            isPanning = true;
            panStart = { x: e.clientX - panX, y: e.clientY - panY };
            return;
        }

        const rect = canvas.getBoundingClientRect();
        const sx = e.clientX - rect.left;
        const sy = e.clientY - rect.top;
        const { x, y } = screenToWorld(sx, sy);

        const map = maps.find(m => m.id === selectedMapId);
        const clickedNode = map.nodes.find(n => Math.hypot(n.x - x, n.y - y) <= NODE_RADIUS);

        if (e.shiftKey && clickedNode) {
           isConnecting = true;
           connectionStartNode = clickedNode;
           mousePos = { x, y };
        } else if (clickedNode) {
           selectedNodeId = clickedNode.id;
           selectedConnectionId = null;
           dragNode = clickedNode;
           dragStartPos = { x, y };
           render();
        } else {
           const clickedConn = findConnectionNear(map, x, y);
           if (clickedConn) {
              selectedConnectionId = clickedConn.id;
              selectedNodeId = null;
              render();
           } else if (selectedNodeId || selectedConnectionId) {
              selectedNodeId = null;
              selectedConnectionId = null;
              render();
           } else {
              selectedNodeId = null;
              selectedConnectionId = null;
              drawCanvas();
           }
        }
     });

     canvas.addEventListener('mousemove', (e) => {
        if (isPanning) {
            panX = e.clientX - panStart.x;
            panY = e.clientY - panStart.y;
            drawCanvas();
            return;
        }

        const rect = canvas.getBoundingClientRect();
        const sx = e.clientX - rect.left;
        const sy = e.clientY - rect.top;
        const { x, y } = screenToWorld(sx, sy);
        mousePos = { x, y };

        if (isConnecting) {
           drawCanvas();
        } else if (dragNode) {
           dragNode.x += x - dragStartPos.x;
           dragNode.y += y - dragStartPos.y;
           dragStartPos = { x, y };
           
           // Update inspector if open
           const xInput = document.getElementById('node-x');
           const yInput = document.getElementById('node-y');
           if (xInput) xInput.value = Math.round(dragNode.x);
           if (yInput) yInput.value = Math.round(dragNode.y);
           
           drawCanvas();
        }
     });

     canvas.addEventListener('mouseup', (e) => {
        if (isPanning) {
            isPanning = false;
            return;
        }

        const map = maps.find(m => m.id === selectedMapId);
        if (isConnecting && connectionStartNode) {
           const rect = canvas.getBoundingClientRect();
           const sx = e.clientX - rect.left;
           const sy = e.clientY - rect.top;
           const { x, y } = screenToWorld(sx, sy);
           const targetNode = map.nodes.find(n => Math.hypot(n.x - x, n.y - y) <= NODE_RADIUS);

           if (targetNode && targetNode.id !== connectionStartNode.id) {
              const exists = map.connections.find(c => c.fromNodeId === connectionStartNode.id && c.toNodeId === targetNode.id);
              if (!exists) {
                 map.connections.push(createMapConnection(connectionStartNode.id, targetNode.id));
                 store.save('maps', map);
              }
           }
        } else if (dragNode) {
           store.save('maps', map);
        }

        isConnecting = false;
        connectionStartNode = null;
        dragNode = null;
        drawCanvas();
     });

     canvas.addEventListener('dblclick', (e) => {
        const rect = canvas.getBoundingClientRect();
        const sx = e.clientX - rect.left;
        const sy = e.clientY - rect.top;
        const { x, y } = screenToWorld(sx, sy);

        const map = maps.find(m => m.id === selectedMapId);
        
        const clickedNode = map.nodes.find(n => Math.hypot(n.x - x, n.y - y) <= NODE_RADIUS);
        if (clickedNode) return;

        const node = createMapNode({ x, y });
        map.nodes.push(node);
        store.save('maps', map);
        selectedNodeId = node.id;
        render();
     });
     
     // initial draw
     drawCanvas();
  }

  function drawCanvas() {
     const canvas = document.getElementById('map-canvas');
     if (!canvas) return;
     const ctx = canvas.getContext('2d');
     const map = maps.find(m => m.id === selectedMapId);
     if (!map) return;

     ctx.clearRect(0, 0, canvas.width, canvas.height);

     ctx.save();
     ctx.translate(panX, panY);
     ctx.scale(zoom, zoom);

     let imgWidth = canvas.width / zoom;
     let imgHeight = canvas.height / zoom;

     if (map.backgroundImage) {
        if (loadedImages[map.backgroundImage] === undefined) {
           loadedImages[map.backgroundImage] = null; // Mark as loading
           const img = new Image();
           img.onload = () => {
              loadedImages[map.backgroundImage] = img;
              drawCanvas(); // Redraw once loaded
           };
           img.src = '/game/' + map.backgroundImage + '?v=' + Date.now();
        } else if (loadedImages[map.backgroundImage] !== null) {
           const img = loadedImages[map.backgroundImage];
           imgWidth = img.width;
           imgHeight = img.height;
           ctx.drawImage(img, 0, 0);
        }
     }



     // Draw connections
     map.connections.forEach(conn => {
        const from = map.nodes.find(n => n.id === conn.fromNodeId);
        const to = map.nodes.find(n => n.id === conn.toNodeId);
        if (from && to) {
           const isSelected = conn.id === selectedConnectionId;
           const hasConditions = conn.conditions && conn.conditions.length > 0;
           const gateType = conn.gateType || 'none';
           drawArrow(ctx, from.x, from.y, to.x, to.y, { isSelected, hasConditions, gateType });
        }
     });

     // Draw active connection line
     if (isConnecting && connectionStartNode) {
        ctx.beginPath();
        ctx.moveTo(connectionStartNode.x, connectionStartNode.y);
        ctx.lineTo(mousePos.x, mousePos.y);
        ctx.strokeStyle = '#fff';
        ctx.lineWidth = 2;
        ctx.setLineDash([5, 5]);
        ctx.stroke();
        ctx.setLineDash([]);
     }

     // Draw nodes
     map.nodes.forEach(node => {
        ctx.beginPath();
        ctx.arc(node.x, node.y, NODE_RADIUS, 0, Math.PI * 2);
        
        // Color based on content: has options = teal, empty = grey
        const hasContent = node.options && node.options.length > 0;
        ctx.fillStyle = hasContent ? '#26a69a' : '#616161';
        ctx.fill();

        ctx.strokeStyle = node.id === selectedNodeId ? '#fff' : '#000';
        ctx.lineWidth = (node.id === selectedNodeId ? 3 : 2) / zoom;
        ctx.stroke();

        // Label
        ctx.fillStyle = '#fff';
        ctx.font = '12px sans-serif';
        ctx.textAlign = 'center';
        ctx.fillText(node.label || '•', node.x, node.y + NODE_RADIUS + 16);
     });

     ctx.restore();
  }

  function drawArrow(ctx, fromX, fromY, toX, toY, opts = {}) {
     const headlen = 10;
     const dx = toX - fromX;
     const dy = toY - fromY;
     const angle = Math.atan2(dy, dx);
     
     const targetX = toX - NODE_RADIUS * Math.cos(angle);
     const targetY = toY - NODE_RADIUS * Math.sin(angle);

     // Style based on gate type
     let color = '#aaa';
     let dash = [];
     if (opts.isSelected) {
        color = '#fff';
     } else if (opts.gateType === 'hard' && opts.hasConditions) {
        color = '#f44336';
        dash = [3, 3];
     } else if (opts.gateType === 'soft' && opts.hasConditions) {
        color = '#ff9800';
        dash = [8, 4];
     }

     ctx.beginPath();
     ctx.setLineDash(dash);
     ctx.moveTo(fromX, fromY);
     ctx.lineTo(targetX, targetY);
     ctx.strokeStyle = color;
     ctx.lineWidth = opts.isSelected ? 3 : 2;
     ctx.stroke();
     ctx.setLineDash([]);

     // Arrowhead
     ctx.beginPath();
     ctx.moveTo(targetX, targetY);
     ctx.lineTo(targetX - headlen * Math.cos(angle - Math.PI / 6), targetY - headlen * Math.sin(angle - Math.PI / 6));
     ctx.lineTo(targetX - headlen * Math.cos(angle + Math.PI / 6), targetY - headlen * Math.sin(angle + Math.PI / 6));
     ctx.fillStyle = color;
     ctx.fill();

     // Lock icon for gated connections
     if (opts.hasConditions && !opts.isSelected) {
        const midX = (fromX + toX) / 2;
        const midY = (fromY + toY) / 2;
        ctx.font = '14px sans-serif';
        ctx.fillStyle = color;
        ctx.textAlign = 'center';
        ctx.fillText('🔒', midX, midY - 8);
     }
  }

  // Find connection closest to point (within threshold)
  function findConnectionNear(map, px, py, threshold = 12) {
     let best = null;
     let bestDist = threshold;
     map.connections.forEach(conn => {
        const from = map.nodes.find(n => n.id === conn.fromNodeId);
        const to = map.nodes.find(n => n.id === conn.toNodeId);
        if (!from || !to) return;
        const dist = pointToSegmentDist(px, py, from.x, from.y, to.x, to.y);
        if (dist < bestDist) {
           bestDist = dist;
           best = conn;
        }
     });
     return best;
  }

  function pointToSegmentDist(px, py, ax, ay, bx, by) {
     const dx = bx - ax, dy = by - ay;
     const lenSq = dx * dx + dy * dy;
     if (lenSq === 0) return Math.hypot(px - ax, py - ay);
     let t = ((px - ax) * dx + (py - ay) * dy) / lenSq;
     t = Math.max(0, Math.min(1, t));
     return Math.hypot(px - (ax + t * dx), py - (ay + t * dy));
  }

  function attachEvents() {
    container.querySelector('#btn-create-overworld')?.addEventListener('click', () => {
      const m = createGameMap({ name: 'Overworld', isOverworld: true });
      store.save('maps', m);
      maps = store.getAll('maps');
      selectedMapId = m.id;
      render();
    });

    container.querySelector('#btn-create-submap')?.addEventListener('click', () => {
      const parentId = maps.find(m => m.id === selectedMapId)?.id || null;
      const m = createGameMap({ name: 'New Region/Dungeon', isOverworld: false, parentMapId: parentId });
      store.save('maps', m);
      maps = store.getAll('maps');
      selectedMapId = m.id;
      render();
    });

    container.querySelectorAll('.list-item').forEach(el => {
      el.addEventListener('click', (e) => {
        selectedMapId = e.currentTarget.dataset.id;
        selectedNodeId = null;
        selectedConnectionId = null;
        render();
      });
    });

    const nameInput = container.querySelector('#map-name');
    if (nameInput) {
      nameInput.addEventListener('blur', () => {
         const m = maps.find(x => x.id === selectedMapId);
         m.name = nameInput.value;
         store.save('maps', m);
         render();
      });

      // Background image path
      const bgInput = container.querySelector('#map-bg');
      const bgUpload = container.querySelector('#map-bg-upload');
      
      if (bgInput) {
        bgInput.addEventListener('blur', () => {
           const m = maps.find(x => x.id === selectedMapId);
           m.backgroundImage = bgInput.value;
           store.save('maps', m);
           drawCanvas();
        });
      }

      if (bgUpload) {
         bgUpload.addEventListener('change', async (e) => {
             const file = e.target.files[0];
             if (!file) return;
             try {
                 await fetch('/upload-image', {
                     method: 'POST',
                     headers: { 'X-Filename': file.name },
                     body: file
                 });
                 const m = maps.find(x => x.id === selectedMapId);
                 m.backgroundImage = `assets/maps/${file.name}`;
                 store.save('maps', m);
                 render();
             } catch (err) {
                 alert("Upload failed. Make sure python server is running.");
             }
         });
      }

      container.querySelector('#btn-delete-map')?.addEventListener('click', () => {
        showConfirmModal('Are you sure you want to delete this map and ALL its nodes?', () => {
           maps.forEach(child => {
              if (child.parentMapId === selectedMapId) {
                 child.parentMapId = null;
                 store.save('maps', child);
              }
           });
           store.remove('maps', selectedMapId);
           maps = store.getAll('maps');
           selectedMapId = null;
           render();
        });
      });
    }

    // Node (location) inspector
    const nodeLabel = container.querySelector('#node-label');
    if (nodeLabel) {
       const saveNode = () => {
          const map = maps.find(m => m.id === selectedMapId);
          const n = map.nodes.find(x => x.id === selectedNodeId);
          if (!n) return;
          
          n.label = container.querySelector('#node-label').value;
          n.x = parseFloat(container.querySelector('#node-x').value) || n.x;
          n.y = parseFloat(container.querySelector('#node-y').value) || n.y;
          n.description = container.querySelector('#node-desc')?.value || '';

          // Save option texts and lockType
          container.querySelectorAll('.node-opt-text').forEach(inp => {
             const oi = parseInt(inp.dataset.oi);
             n.options[oi].text = inp.value;
          });
          container.querySelectorAll('.node-opt-lock-type').forEach(sel => {
             const oi = parseInt(sel.dataset.oi);
             n.options[oi].lockType = sel.value;
          });

          // Save conditions
          container.querySelectorAll('.noc-type').forEach(sel => {
             const oi = parseInt(sel.dataset.oi);
             const ci = parseInt(sel.dataset.ci);
             const c = n.options[oi].conditions[ci];
             c.type = sel.value;
             const t = container.querySelector(`.noc-target[data-oi="${oi}"][data-ci="${ci}"]`);
             if (t) c.target = t.value;
             const op = container.querySelector(`.noc-op[data-oi="${oi}"][data-ci="${ci}"]`);
             if (op) c.operator = op.value;
             const v = container.querySelector(`.noc-val[data-oi="${oi}"][data-ci="${ci}"]`);
             if (v) c.value = v.value;
          });

          // Save outcomes
          container.querySelectorAll('.noo-type').forEach(sel => {
             const oi = parseInt(sel.dataset.oi);
             const oui = parseInt(sel.dataset.oui);
             const o = n.options[oi].outcomes[oui];
             o.type = sel.value;
             const t = container.querySelector(`.noo-target[data-oi="${oi}"][data-oui="${oui}"]`);
             if (t) o.target = t.value;
             const v = container.querySelector(`.noo-val[data-oi="${oi}"][data-oui="${oui}"]`);
             if (v) o.value = v.value;
          });

          store.save('maps', map);
       };

       nodeLabel.addEventListener('blur', () => { saveNode(); drawCanvas(); });
       container.querySelector('#node-x')?.addEventListener('input', () => { saveNode(); drawCanvas(); });
       container.querySelector('#node-y')?.addEventListener('input', () => { saveNode(); drawCanvas(); });
       container.querySelector('#node-desc')?.addEventListener('blur', () => { saveNode(); });

       // Option text changes
       container.querySelectorAll('.node-opt-text, .noc-val, .noc-target, .noc-op, .noo-val, .noo-target').forEach(el => {
          el.addEventListener('blur', () => { saveNode(); });
          el.addEventListener('change', () => { saveNode(); });
       });

       // Structural changes redraw
       container.querySelectorAll('.noc-type, .noo-type').forEach(sel => {
          sel.addEventListener('change', () => { saveNode(); render(); });
       });

       // Add/remove options
       container.querySelector('#btn-add-node-opt')?.addEventListener('click', () => {
          const map = maps.find(m => m.id === selectedMapId);
          const n = map.nodes.find(x => x.id === selectedNodeId);
          if (!n.options) n.options = [];
          n.options.push(createEventOption());
          store.save('maps', map);
          render();
       });

       container.querySelectorAll('.btn-rm-node-opt').forEach(btn => {
          btn.addEventListener('click', (ev) => {
             showConfirmModal('Delete this option?', () => {
                const oi = parseInt(ev.currentTarget.dataset.oi);
                const map = maps.find(m => m.id === selectedMapId);
                const n = map.nodes.find(x => x.id === selectedNodeId);
                n.options.splice(oi, 1);
                store.save('maps', map);
                render();
             });
          });
       });

       container.querySelectorAll('.btn-move-node-opt-up').forEach(btn => {
          btn.addEventListener('click', (ev) => {
             const oi = parseInt(ev.currentTarget.dataset.oi);
             if (oi > 0) {
                 const map = maps.find(m => m.id === selectedMapId);
                 const n = map.nodes.find(x => x.id === selectedNodeId);
                 const temp = n.options[oi - 1];
                 n.options[oi - 1] = n.options[oi];
                 n.options[oi] = temp;
                 store.save('maps', map);
                 render();
             }
          });
       });

       container.querySelectorAll('.btn-move-node-opt-down').forEach(btn => {
          btn.addEventListener('click', (ev) => {
             const oi = parseInt(ev.currentTarget.dataset.oi);
             const map = maps.find(m => m.id === selectedMapId);
             const n = map.nodes.find(x => x.id === selectedNodeId);
             if (oi < n.options.length - 1) {
                 const temp = n.options[oi + 1];
                 n.options[oi + 1] = n.options[oi];
                 n.options[oi] = temp;
                 store.save('maps', map);
                 render();
             }
          });
       });

       // Add/remove conditions
       container.querySelectorAll('.btn-add-noc').forEach(btn => {
          btn.addEventListener('click', (ev) => {
             const oi = parseInt(ev.currentTarget.dataset.oi);
             const map = maps.find(m => m.id === selectedMapId);
             const n = map.nodes.find(x => x.id === selectedNodeId);
             n.options[oi].conditions.push(createEventCondition());
             store.save('maps', map);
             render();
          });
       });
       container.querySelectorAll('.btn-rm-noc').forEach(btn => {
          btn.addEventListener('click', (ev) => {
             const oi = parseInt(ev.currentTarget.dataset.oi);
             const ci = parseInt(ev.currentTarget.dataset.ci);
             const map = maps.find(m => m.id === selectedMapId);
             const n = map.nodes.find(x => x.id === selectedNodeId);
             n.options[oi].conditions.splice(ci, 1);
             store.save('maps', map);
             render();
          });
       });

       // Add/remove outcomes
       container.querySelectorAll('.btn-add-noo').forEach(btn => {
          btn.addEventListener('click', (ev) => {
             const oi = parseInt(ev.currentTarget.dataset.oi);
             const map = maps.find(m => m.id === selectedMapId);
             const n = map.nodes.find(x => x.id === selectedNodeId);
             n.options[oi].outcomes.push(createEventOutcome());
             store.save('maps', map);
             render();
          });
       });
       container.querySelectorAll('.btn-rm-noo').forEach(btn => {
          btn.addEventListener('click', (ev) => {
             const oi = parseInt(ev.currentTarget.dataset.oi);
             const oui = parseInt(ev.currentTarget.dataset.oui);
             const map = maps.find(m => m.id === selectedMapId);
             const n = map.nodes.find(x => x.id === selectedNodeId);
             n.options[oi].outcomes.splice(oui, 1);
             store.save('maps', map);
             render();
          });
       });

       container.querySelector('#btn-delete-node').addEventListener('click', () => {
          showConfirmModal('Delete this location?', () => {
             const map = maps.find(m => m.id === selectedMapId);
             map.nodes = map.nodes.filter(n => n.id !== selectedNodeId);
             map.connections = map.connections.filter(c => c.fromNodeId !== selectedNodeId && c.toNodeId !== selectedNodeId);
             store.save('maps', map);
             selectedNodeId = null;
             render();
          });
       });
    }

    // Connection inspector
    const connGateType = container.querySelector('#conn-gate-type');
    if (connGateType) {
       const saveConn = () => {
          const map = maps.find(m => m.id === selectedMapId);
          const conn = map.connections.find(c => c.id === selectedConnectionId);
          if (!conn) return;

          conn.gateType = container.querySelector('#conn-gate-type').value;

          // Save conditions
          container.querySelectorAll('.conn-cond-type').forEach(sel => {
             const idx = parseInt(sel.dataset.ci);
             const cond = conn.conditions[idx];
             cond.type = sel.value;
             const targetEl = container.querySelector(`.conn-cond-target[data-ci="${idx}"]`);
             if (targetEl) cond.target = targetEl.value;
             const opEl = container.querySelector(`.conn-cond-op[data-ci="${idx}"]`);
             if (opEl) cond.operator = opEl.value;
             const valEl = container.querySelector(`.conn-cond-val[data-ci="${idx}"]`);
             if (valEl) cond.value = valEl.value;
          });

          store.save('maps', map);
       };

       connGateType.addEventListener('change', () => { saveConn(); drawCanvas(); });

       // Condition field changes
       container.querySelectorAll('.conn-cond-type').forEach(sel => {
          sel.addEventListener('change', () => { saveConn(); render(); });
       });
       container.querySelectorAll('.conn-cond-target, .conn-cond-op, .conn-cond-val').forEach(el => {
          el.addEventListener('blur', () => { saveConn(); });
          el.addEventListener('change', () => { saveConn(); });
       });

       container.querySelector('#btn-add-conn-cond')?.addEventListener('click', () => {
          const map = maps.find(m => m.id === selectedMapId);
          const conn = map.connections.find(c => c.id === selectedConnectionId);
          if (!conn.conditions) conn.conditions = [];
          conn.conditions.push(createEventCondition());
          store.save('maps', map);
          render();
       });

       container.querySelectorAll('.btn-remove-conn-cond').forEach(btn => {
          btn.addEventListener('click', (ev) => {
             const idx = parseInt(ev.currentTarget.dataset.ci);
             const map = maps.find(m => m.id === selectedMapId);
             const conn = map.connections.find(c => c.id === selectedConnectionId);
             conn.conditions.splice(idx, 1);
             store.save('maps', map);
             render();
          });
       });

       container.querySelector('#btn-delete-conn')?.addEventListener('click', () => {
          showConfirmModal('Delete this connection?', () => {
             const map = maps.find(m => m.id === selectedMapId);
             map.connections = map.connections.filter(c => c.id !== selectedConnectionId);
             store.save('maps', map);
             selectedConnectionId = null;
             render();
          });
       });
    }

  }

  // Ensure an overworld map exists by default if empty? No, user explicitly clicks create in UI.
  // We just render.
  render();
}
