import { store } from './data/store.js?v=1778133956';
import { initBuilder } from './builder/builder.js?v=1778133956';

// Entry point
document.addEventListener('DOMContentLoaded', () => {
  const appContainer = document.getElementById('app');
  
  // Ensure store has initial empty collections
  store.init();
  
  // Mount the builder UI
  initBuilder(appContainer);
});
