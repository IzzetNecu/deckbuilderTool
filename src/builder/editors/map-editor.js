import { store } from '../../data/store.js?v=1778141595';
import { createGameMap, createMapNode, createMapConnection, createEventCondition, createEventOption, createEventOutcome } from '../../data/models.js?v=1778141595';
import { showConfirmModal } from '../components/modal.js?v=1778141595';

export function renderMapEditor(container) {
  let maps = store.getAll('maps');
  let events = store.getAll('events');
  let enemies = store.getAll('enemies');
  let factions = store.getAll('factions');
  let gameMaps = store.getAll('maps');
  let allItems = [
    ...store.getAll('consumables').map(c => ({...c, _typeLabel: 'Consumable'})),
    ...store.getAll('equipment').map(e => ({...e, _typeLabel: 'Equipment'})),
    ...store.getAll('keyItems').map(k => ({...k, _typeLabel: 'Key Item'}))
  ];
  
  let selectedMapId = null;
  let selectedNodeId = null;
  let dragNode = null;
  let dragStartPos = { x: 0, y: 0 };
  let isConnecting = false;
  let connectionStartNode = null;
  let mousePos = { x: 0, y: 0 };
  let selectedConnectionId = null;

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
              <input type="text" id="map-bg" value="${selectedMap.backgroundImage || ''}" placeholder="Background path (e.g. res://assets/maps/overworld.png)" style="flex:2; min-width:200px; font-size:0.85em;" />
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
                       <select class="noc-op" data-oi="${oi}" data-ci="${ci}" style="width:40px;">${renderOpOptions(c.operator)}</select>
                       <input type="text" class="noc-val" data-oi="${oi}" data-ci="${ci}" value="${c.value}" style="width:35px;" />
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
                       <input type="text" class="noo-val" data-oi="${oi}" data-oui="${oui}" value="${o.value}" style="width:35px;" placeholder="val" />
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
       ['hasFactionRank','Has Faction Rank']
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
     }
     return `<input type="hidden" class="${prefix}-target" data-oi="${oi}" data-ci="${ci}" value="" />`;
  }

  function renderOutcomeTypeOptions(selected) {
     const types = [
       ['text','Show Text'],['addConsumable','Add Consumable'],['removeConsumable','Remove Consumable'],
       ['addEquipment','Add Equipment'],['removeEquipment','Remove Equipment'],
       ['addKeyItem','Add Key Item'],['removeKeyItem','Remove Key Item'],
       ['addCard','Add Card'],['removeCard','Remove Card'],
       ['addMoney','Add Money'],['removeMoney','Remove Money'],
       ['damage','Damage'],['heal','Heal'],['modifyStat','Modify Stat'],
       ['travelToMap','Travel to Map'],['startCombat','Start Combat'],['startEvent','Start Event']
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
     }
     return `<input type="text" class="noo-target" data-oi="${oi}" data-oui="${oui}" value="${out.target}" placeholder="text" style="flex:1;" />`;
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
             ${conn.conditions.map((cond, idx) => {
                let targetHTML = '';
                if (cond.type === 'hasStat') {
                   targetHTML = `<select class="conn-cond-target" data-idx="${idx}" style="flex:1;">
                     ${STATS.map(s => `<option value="${s}" ${cond.target === s ? 'selected' : ''}>${s}</option>`).join('')}
                   </select>`;
                } else if (['hasConsumable','lacksConsumable','hasEquipment','lacksEquipment','hasKeyItem','lacksKeyItem'].includes(cond.type)) {
                   targetHTML = `<select class="conn-cond-target" data-idx="${idx}" style="flex:1;">
                     <option value="">-- Item --</option>
                     ${allItems.map(i => `<option value="${i.id}" ${cond.target === i.id ? 'selected' : ''}>${i.name} (${i._typeLabel})</option>`).join('')}
                   </select>`;
                } else if (cond.type === 'hasFactionRank') {
                   targetHTML = `<select class="conn-cond-target" data-idx="${idx}" style="flex:1;">
                     <option value="">-- Faction --</option>
                     ${factions.map(f => `<option value="${f.id}" ${cond.target === f.id ? 'selected' : ''}>${f.name}</option>`).join('')}
                   </select>`;
                } else {
                   targetHTML = `<input type="hidden" class="conn-cond-target" data-idx="${idx}" value="" />`;
                }
                return `
                  <div style="background:#1a1a1a; padding:8px; border:1px solid var(--border); margin-bottom:6px; border-radius:4px;">
                    <div style="display:flex; gap:4px; margin-bottom:4px;">
                      <select class="conn-cond-type" data-idx="${idx}" style="flex:1; font-size:0.85em;">
                        <option value="hasMoney" ${cond.type === 'hasMoney' ? 'selected' : ''}>Has Money</option>
                        <option value="hasStat" ${cond.type === 'hasStat' ? 'selected' : ''}>Has Stat</option>
                        <option value="hasConsumable" ${cond.type === 'hasConsumable' ? 'selected' : ''}>Has Consumable</option>
                        <option value="hasEquipment" ${cond.type === 'hasEquipment' ? 'selected' : ''}>Has Equipment</option>
                        <option value="hasKeyItem" ${cond.type === 'hasKeyItem' ? 'selected' : ''}>Has Key Item</option>
                        <option value="lacksKeyItem" ${cond.type === 'lacksKeyItem' ? 'selected' : ''}>Lacks Key Item</option>
                        <option value="hasFactionRank" ${cond.type === 'hasFactionRank' ? 'selected' : ''}>Has Faction Rank</option>
                      </select>
                      <button class="danger btn-remove-conn-cond" data-idx="${idx}" style="padding:2px 6px;">X</button>
                    </div>
                    <div style="display:flex; gap:4px;">
                      ${targetHTML}
                      <select class="conn-cond-op" data-idx="${idx}" style="width:50px;">
                        <option value=">=" ${cond.operator === '>=' ? 'selected' : ''}>&gt;=</option>
                        <option value="<=" ${cond.operator === '<=' ? 'selected' : ''}>&lt;=</option>
                        <option value="==" ${cond.operator === '==' ? 'selected' : ''}>==</option>
                      </select>
                      <input type="text" class="conn-cond-val" data-idx="${idx}" value="${cond.value}" placeholder="Val" style="width:50px;" />
                    </div>
                  </div>
                `;
             }).join('')}
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

     canvas.addEventListener('mousedown', (e) => {
        const rect = canvas.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;

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
           // Check if clicking near a connection line
           const clickedConn = findConnectionNear(map, x, y);
           if (clickedConn) {
              selectedConnectionId = clickedConn.id;
              selectedNodeId = null;
              render();
           } else if (selectedNodeId || selectedConnectionId) {
              // Only re-render if we're deselecting something
              selectedNodeId = null;
              selectedConnectionId = null;
              render();
           } else {
              // Update state without re-rendering the whole UI
              selectedNodeId = null;
              selectedConnectionId = null;
              drawCanvas();
           }
        }
     });

     canvas.addEventListener('mousemove', (e) => {
        const rect = canvas.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;
        mousePos = { x, y };

        if (isConnecting) {
           drawCanvas();
        } else if (dragNode) {
           dragNode.x += x - dragStartPos.x;
           dragNode.y += y - dragStartPos.y;
           dragStartPos = { x, y };
           drawCanvas();
        }
     });

     canvas.addEventListener('mouseup', (e) => {
        const map = maps.find(m => m.id === selectedMapId);
        if (isConnecting && connectionStartNode) {
           const rect = canvas.getBoundingClientRect();
           const x = e.clientX - rect.left;
           const y = e.clientY - rect.top;
           const targetNode = map.nodes.find(n => Math.hypot(n.x - x, n.y - y) <= NODE_RADIUS);

           if (targetNode && targetNode.id !== connectionStartNode.id) {
              // Avoid duplicates
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
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;

        const map = maps.find(m => m.id === selectedMapId);
        
        // Don't create if clicking an existing node
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

     // Draw grid
     ctx.strokeStyle = '#333';
     ctx.lineWidth = 1;
     for (let x = 0; x < canvas.width; x += 50) { ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, canvas.height); ctx.stroke(); }
     for (let y = 0; y < canvas.height; y += 50) { ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(canvas.width, y); ctx.stroke(); }

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
        ctx.lineWidth = node.id === selectedNodeId ? 3 : 2;
        ctx.stroke();

        // Label
        ctx.fillStyle = '#fff';
        ctx.font = '12px sans-serif';
        ctx.textAlign = 'center';
        ctx.fillText(node.label || '•', node.x, node.y + NODE_RADIUS + 16);
     });
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
      if (bgInput) {
        bgInput.addEventListener('blur', () => {
           const m = maps.find(x => x.id === selectedMapId);
           m.backgroundImage = bgInput.value;
           store.save('maps', m);
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
          n.description = container.querySelector('#node-desc')?.value || '';

          // Save option texts
          container.querySelectorAll('.node-opt-text').forEach(inp => {
             const oi = parseInt(inp.dataset.oi);
             n.options[oi].text = inp.value;
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
             const idx = parseInt(sel.dataset.idx);
             const cond = conn.conditions[idx];
             cond.type = sel.value;
             const targetEl = container.querySelector(`.conn-cond-target[data-idx="${idx}"]`);
             if (targetEl) cond.target = targetEl.value;
             const opEl = container.querySelector(`.conn-cond-op[data-idx="${idx}"]`);
             if (opEl) cond.operator = opEl.value;
             const valEl = container.querySelector(`.conn-cond-val[data-idx="${idx}"]`);
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
             const idx = parseInt(ev.currentTarget.dataset.idx);
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
