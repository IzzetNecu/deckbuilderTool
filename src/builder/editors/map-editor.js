import { store } from '../../data/store.js';
import { createGameMap, createMapNode, createMapConnection } from '../../data/models.js';
import { showConfirmModal } from '../components/modal.js';

export function renderMapEditor(container) {
  let maps = store.getAll('maps');
  let events = store.getAll('events');
  let enemies = store.getAll('enemies');
  
  let selectedMapId = null;
  let selectedNodeId = null;
  let dragNode = null;
  let dragStartPos = { x: 0, y: 0 };
  let isConnecting = false;
  let connectionStartNode = null;
  let mousePos = { x: 0, y: 0 };

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
            <div style="padding: 16px; border-bottom: 1px solid var(--border); display:flex; gap: 16px; background:var(--bg-surface);">
              <input type="text" id="map-name" value="${selectedMap.name}" placeholder="Map Name" style="flex:1;" />
              ${selectedMap.isOverworld ? `<span style="align-self:center; color:var(--accent);">★ Overworld</span>` : `
                 <button id="btn-delete-map" class="danger">Delete Map</button>
              `}
            </div>
            <div style="padding: 8px 16px; background: #111; font-size: 0.8em; color:var(--text-secondary); display:flex; justify-content:space-between;">
               <span>Double-click empty space to create node. Shift+drag between nodes to connect.</span>
               <span>Nodes: ${selectedMap.nodes.length} | Connections: ${selectedMap.connections.length}</span>
            </div>
            
            <div style="flex:1; display:flex;">
               <!-- Canvas Area -->
               <div style="flex:1; position:relative; overflow:hidden;" id="canvas-container">
                  <canvas id="map-canvas" style="background:#1a1a1a; cursor:crosshair; width:100%; height:100%; display:block;"></canvas>
               </div>
               
               <!-- Node Inspector -->
               ${selectedNodeId ? renderNodeInspector(selectedMap.nodes.find(n => n.id === selectedNodeId)) : `
                 <div style="width: 250px; background:var(--bg-surface); border-left:1px solid var(--border); padding:16px;">
                    <div class="empty-state">Select a node to inspect</div>
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

     // Content linking based on type
     let linkHtml = '';
     if (node.type === 'event') {
        linkHtml = `
          <div class="form-group">
            <label>Linked Event</label>
            <select id="node-link">
              <option value="">-- Select Event --</option>
              ${events.map(e => `<option value="${e.id}" ${node.linkedId === e.id ? 'selected' : ''}>${e.name}</option>`).join('')}
            </select>
          </div>
        `;
     } else if (node.type === 'combat' || node.type === 'boss') {
        linkHtml = `
          <div class="form-group">
            <label>Linked Enemy</label>
            <select id="node-link">
              <option value="">-- Select Enemy --</option>
              ${enemies.map(e => `<option value="${e.id}" ${node.linkedId === e.id ? 'selected' : ''}>${e.name}</option>`).join('')}
            </select>
          </div>
        `;
     } else if (node.type === 'submap') {
        const availableSubmaps = maps.filter(m => !m.isOverworld && m.id !== selectedMapId);
        linkHtml = `
          <div class="form-group">
            <label>Linked Sub-Map</label>
            <select id="node-link">
              <option value="">-- Select Map --</option>
              ${availableSubmaps.map(m => `<option value="${m.id}" ${node.linkedId === m.id ? 'selected' : ''}>${m.name}</option>`).join('')}
            </select>
          </div>
        `;
     }

     return `
        <div style="width: 250px; background:var(--bg-surface); border-left:1px solid var(--border); padding:16px; display:flex; flex-direction:column;">
           <h3>Node Inspector</h3>
           
           <div class="form-group">
             <label>Label</label>
             <input type="text" id="node-label" value="${node.label}" placeholder="(Optional) visual label" />
           </div>

           <div class="form-group">
             <label>Type</label>
             <select id="node-type">
               <option value="start" ${node.type === 'start' ? 'selected' : ''}>Start Node</option>
               <option value="event" ${node.type === 'event' ? 'selected' : ''}>Event / Story</option>
               <option value="combat" ${node.type === 'combat' ? 'selected' : ''}>Combat (Normal)</option>
               <option value="boss" ${node.type === 'boss' ? 'selected' : ''}>Boss Combat</option>
               <option value="shop" ${node.type === 'shop' ? 'selected' : ''}>Shop / Merchant</option>
               <option value="rest" ${node.type === 'rest' ? 'selected' : ''}>Rest Site</option>
               <option value="submap" ${node.type === 'submap' ? 'selected' : ''}>Sub-Map (Dungeon)</option>
             </select>
           </div>

           ${linkHtml}

           <div style="margin-top: auto; padding-top: 16px;">
             <button id="btn-delete-node" class="danger">Delete Node</button>
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
           dragNode = clickedNode;
           dragStartPos = { x, y };
           render(); // update inspector
        } else {
           selectedNodeId = null;
           render(); // clear inspector
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

        const node = createMapNode({ x, y, mapId: selectedMapId, type: map.nodes.length === 0 ? 'start' : 'combat' });
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
        if (from && to) drawArrow(ctx, from.x, from.y, to.x, to.y);
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
        
        // Colors based on type
        switch(node.type) {
           case 'start': ctx.fillStyle = '#4caf50'; break;
           case 'event': ctx.fillStyle = '#9c27b0'; break;
           case 'combat': ctx.fillStyle = '#f44336'; break;
           case 'boss': ctx.fillStyle = '#b71c1c'; break;
           case 'shop': ctx.fillStyle = '#ffeb3b'; break;
           case 'rest': ctx.fillStyle = '#2196f3'; break;
           case 'submap': ctx.fillStyle = '#ff9800'; break;
           default: ctx.fillStyle = '#fff';
        }
        ctx.fill();

        ctx.strokeStyle = node.id === selectedNodeId ? '#fff' : '#000';
        ctx.lineWidth = node.id === selectedNodeId ? 3 : 2;
        ctx.stroke();

        // Label
        ctx.fillStyle = '#fff';
        ctx.font = '12px sans-serif';
        ctx.textAlign = 'center';
        ctx.fillText(node.label || node.type.toUpperCase(), node.x, node.y + NODE_RADIUS + 16);
     });
  }

  function drawArrow(ctx, fromX, fromY, toX, toY) {
     const headlen = 10;
     const dx = toX - fromX;
     const dy = toY - fromY;
     const angle = Math.atan2(dy, dx);
     
     // Stop drawing at the edge of the target node
     const targetX = toX - NODE_RADIUS * Math.cos(angle);
     const targetY = toY - NODE_RADIUS * Math.sin(angle);

     ctx.beginPath();
     ctx.moveTo(fromX, fromY);
     ctx.lineTo(targetX, targetY);
     ctx.strokeStyle = '#aaa';
     ctx.lineWidth = 2;
     ctx.stroke();

     // Arrowhead
     ctx.beginPath();
     ctx.moveTo(targetX, targetY);
     ctx.lineTo(targetX - headlen * Math.cos(angle - Math.PI / 6), targetY - headlen * Math.sin(angle - Math.PI / 6));
     ctx.lineTo(targetX - headlen * Math.cos(angle + Math.PI / 6), targetY - headlen * Math.sin(angle + Math.PI / 6));
     ctx.fillStyle = '#aaa';
     ctx.fill();
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

      container.querySelector('#btn-delete-map')?.addEventListener('click', () => {
        showConfirmModal('Are you sure you want to delete this map and ALL its nodes?', () => {
           // Also un-parent any children
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

    // Node inspector
    const typeSelect = container.querySelector('#node-type');
    if (typeSelect) {
       const saveNode = () => {
          const map = maps.find(m => m.id === selectedMapId);
          const n = map.nodes.find(x => x.id === selectedNodeId);
          
          n.type = container.querySelector('#node-type').value;
          n.label = container.querySelector('#node-label').value;
          
          const linkSel = container.querySelector('#node-link');
          n.linkedId = linkSel ? linkSel.value : null;

          store.save('maps', map);
       };

       container.querySelector('#node-label').addEventListener('blur', () => { saveNode(); drawCanvas(); });
       container.querySelector('#node-type').addEventListener('change', () => { saveNode(); render(); });
       
       const nodeLink = container.querySelector('#node-link');
       if (nodeLink) {
         nodeLink.addEventListener('change', () => {
            saveNode();
            
            // If submap, link bidirectionally (set child parentMapId to this map)
            const map = maps.find(m => m.id === selectedMapId);
            const n = map.nodes.find(x => x.id === selectedNodeId);
            if (n.type === 'submap' && n.linkedId) {
               const child = maps.find(m => m.id === n.linkedId);
               if (child) {
                  child.parentMapId = selectedMapId;
                  store.save('maps', child);
               }
            }
            render();
         });
       }

       container.querySelector('#btn-delete-node').addEventListener('click', () => {
          const map = maps.find(m => m.id === selectedMapId);
          map.nodes = map.nodes.filter(n => n.id !== selectedNodeId);
          map.connections = map.connections.filter(c => c.fromNodeId !== selectedNodeId && c.toNodeId !== selectedNodeId);
          store.save('maps', map);
          selectedNodeId = null;
          render();
       });
    }

  }

  // Ensure an overworld map exists by default if empty? No, user explicitly clicks create in UI.
  // We just render.
  render();
}
