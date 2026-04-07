/**
 * Custom Confirmation Modal to replace window.confirm
 */

export function showConfirmModal(message, onConfirm) {
  // Check if modal container exists, if not create it
  let modalOverlay = document.getElementById('custom-confirm-modal');
  
  if (!modalOverlay) {
    modalOverlay = document.createElement('div');
    modalOverlay.id = 'custom-confirm-modal';
    modalOverlay.className = 'modal-overlay';
    modalOverlay.innerHTML = `
      <div class="modal-content">
        <h3 style="margin-top:0;">Confirm Action</h3>
        <p id="custom-modal-message"></p>
        <div class="modal-actions">
          <button id="btn-modal-cancel">Cancel</button>
          <button id="btn-modal-confirm" class="danger">Confirm Delete</button>
        </div>
      </div>
    `;
    document.body.appendChild(modalOverlay);
  }

  // Set message
  document.getElementById('custom-modal-message').innerText = message;
  
  // Show modal
  modalOverlay.classList.add('visible');

  // Handle button clicks
  const btnCancel = document.getElementById('btn-modal-cancel');
  const btnConfirm = document.getElementById('btn-modal-confirm');

  // Remove old listeners to prevent multiple callbacks
  const newCancel = btnCancel.cloneNode(true);
  const newConfirm = btnConfirm.cloneNode(true);
  btnCancel.parentNode.replaceChild(newCancel, btnCancel);
  btnConfirm.parentNode.replaceChild(newConfirm, btnConfirm);

  newCancel.addEventListener('click', () => {
    modalOverlay.classList.remove('visible');
  });

  newConfirm.addEventListener('click', () => {
    modalOverlay.classList.remove('visible');
    if (typeof onConfirm === 'function') {
      onConfirm();
    }
  });
}
