import { store } from './data/store.js?v=1778165481';
import { initBuilder } from './builder/builder.js?v=1778165481';

// Entry point
document.addEventListener('DOMContentLoaded', () => {
  const appContainer = document.getElementById('app');
  
  // Ensure store has initial empty collections
  store.init();
  
  // Mount the builder UI
  initBuilder(appContainer);
});
