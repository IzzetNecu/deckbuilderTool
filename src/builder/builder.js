import { renderFactionEditor } from './editors/faction-editor.js?v=1778175010';
import { renderCardEditor } from './editors/card-editor.js?v=1778175010';
import { renderConsumableEditor } from './editors/consumable-editor.js?v=1778175010';
import { renderEquipmentEditor } from './editors/equipment-editor.js?v=1778175010';
import { renderKeyItemEditor } from './editors/keyitem-editor.js?v=1778175010';
import { renderEnemyEditor } from './editors/enemy-editor.js?v=1778175010';
import { renderEventEditor } from './editors/event-editor.js?v=1778175010';
import { renderDeckEditor } from './editors/deck-editor.js?v=1778175010';
import { renderMapEditor } from './editors/map-editor.js?v=1778175010';
import { renderFlagEditor } from './editors/flag-editor.js?v=1778175010';
import { store } from '../data/store.js?v=1778175010';

export function initBuilder(container) {
  container.innerHTML = `
    <div class="builder-layout">
      <!-- Sidebar -->
      <nav class="sidebar">
        <div class="sidebar-header">
          <h2>Game Builder</h2>
          <div style="font-size: 0.8em; color: var(--text-secondary); margin-top: 4px;">Web Authoring Tool</div>
        </div>
        <div class="sidebar-nav">
          <div class="nav-item active" data-tab="factions">Factions</div>
          <div class="nav-item" data-tab="cards">Cards</div>
          <div class="nav-item" data-tab="consumables">Consumables</div>
          <div class="nav-item" data-tab="equipment">Equipment</div>
          <div class="nav-item" data-tab="keyItems">Key Items</div>
          <div class="nav-item" data-tab="enemies">Enemies</div>
          <div class="nav-item" data-tab="events">Events</div>
          <div class="nav-item" data-tab="decks">Deck Templates</div>
          <div class="nav-item" data-tab="maps">Maps</div>
          <div class="nav-item" data-tab="flags">Flags</div>
        </div>
        <div style="padding: var(--spacing-md); border-top: 1px solid var(--border);">
          <button id="btn-export-data" style="width:100%; margin-bottom: 8px;">Export JSON</button>
          <button id="btn-import-data" style="width:100%;">Import JSON</button>
        </div>
      </nav>
      
      <!-- Main Content Area -->
      <main class="main-content" id="editor-container">
        <!-- Editor views will be injected here -->
      </main>
    </div>
  `;

  const navItems = container.querySelectorAll('.nav-item');
  const editorContainer = container.querySelector('#editor-container');

  function switchTab(tabId) {
    // Update active nav state
    navItems.forEach(nav => {
      nav.classList.toggle('active', nav.dataset.tab === tabId);
    });

    // Render appropriate editor
    editorContainer.innerHTML = ''; // clear
    if (tabId === 'factions') {
      renderFactionEditor(editorContainer);
    } else if (tabId === 'cards') {
      renderCardEditor(editorContainer);
    } else if (tabId === 'consumables') {
      renderConsumableEditor(editorContainer);
    } else if (tabId === 'equipment') {
      renderEquipmentEditor(editorContainer);
    } else if (tabId === 'keyItems') {
      renderKeyItemEditor(editorContainer);
    } else if (tabId === 'enemies') {
      renderEnemyEditor(editorContainer);
    } else if (tabId === 'events') {
      renderEventEditor(editorContainer);
    } else if (tabId === 'decks') {
      renderDeckEditor(editorContainer);
    } else if (tabId === 'maps') {
      renderMapEditor(editorContainer);
    } else if (tabId === 'flags') {
      renderFlagEditor(editorContainer);
    } else {
      editorContainer.innerHTML = `
        <div class="editor-header">
          <h2>${tabId.charAt(0).toUpperCase() + tabId.slice(1)} Editor</h2>
        </div>
        <div class="editor-body">
          <div class="empty-state">Editor for ${tabId} is not implemented yet.</div>
        </div>
      `;
    }
  }

  // Setup nav click listeners
  navItems.forEach(nav => {
    nav.addEventListener('click', () => {
      switchTab(nav.dataset.tab);
    });
  });

  // Export / Import
  container.querySelector('#btn-export-data').addEventListener('click', async () => {
     // Force fresh read directly from localStorage
     const rawMaps = localStorage.getItem('gamebuilder_maps');
     console.log('[Export Debug] Raw maps from localStorage:', rawMaps);
     
     const jsonStr = store.exportAll();
     console.log('[Export Debug] Full export length:', jsonStr.length, 'chars');
     console.log('[Export Debug] Export preview:', jsonStr.substring(0, 500));
     
     const blob = new Blob([jsonStr], { type: 'application/json' });
     
     // Modern File System Access API
     if ('showSaveFilePicker' in window) {
       try {
         const handle = await window.showSaveFilePicker({
           suggestedName: 'game_data.json',
           types: [{
             description: 'JSON File',
             accept: { 'application/json': ['.json'] },
           }],
         });
         const writable = await handle.createWritable();
         await writable.write(blob);
         await writable.close();
         return; // Successfully saved
       } catch (err) {
         if (err.name === 'AbortError') return; // User cancelled prompt
         console.warn('File System Access API failed, falling back:', err);
       }
     }
     
     // Fallback classical anchor tag
     const url = URL.createObjectURL(blob);
     const a = document.createElement('a');
     a.style.display = 'none';
     a.href = url;
     a.download = 'game_data.json';
     
     document.body.appendChild(a);
     a.click();
     
     setTimeout(() => {
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
     }, 150);
  });

  container.querySelector('#btn-import-data').addEventListener('click', () => {
     const input = document.createElement('input');
     input.type = 'file';
     input.accept = 'application/json';
     input.onchange = e => {
        const file = e.target.files[0];
        if (!file) return;
        const reader = new FileReader();
        reader.onload = ev => {
           if(store.importAll(ev.target.result)) {
              alert('Data imported successfully!');
              switchTab('factions'); // redraw
           } else {
              alert('Failed to import data. Invalid JSON format.');
           }
        };
        reader.readAsText(file);
     };
     input.click();
  });

  // Load initial tab
  switchTab('factions');
}
