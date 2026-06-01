document.addEventListener('DOMContentLoaded', () => {
    registerModals();
});


function openModal(id) {
    const modal = document.getElementById(id);
    if (modal) {
        modal.classList.remove('hidden');
        modal.classList.remove('opacity-0');
        document.body.classList.add('overflow-hidden'); // Lock scroll
    }
}

function closeModal(modal) {
    modal.classList.add('hidden');
    document.body.classList.remove('overflow-hidden');
}

function registerModals() {
    document.querySelectorAll('[data-modal-target]').forEach(trigger => {
        trigger.addEventListener('click', () => {
            const targetId = trigger.getAttribute('data-modal-target');
            if (targetId) openModal(targetId);
        });
    });

    document.querySelectorAll('.modal-backdrop').forEach(backdrop => {
        document.body.appendChild(backdrop);
        
        backdrop.addEventListener('click', (e) => {
            const modalBox = backdrop.querySelector('.modal');
            if (!modalBox.contains(e.target) || e.target.classList.contains('modal-close')) {
                closeModal(backdrop);
            }
        });
    });
}