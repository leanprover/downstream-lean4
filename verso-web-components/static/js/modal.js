let _animate = null;

async function getAnimate() {
    if (_animate) return _animate;
    const { animate } = await import('https://cdn.jsdelivr.net/npm/motion@latest/+esm');
    _animate = animate;
    return animate;
}

async function openModal(id) {
    const backdrop = document.getElementById(id);
    if (!backdrop) return;

    const modal = backdrop.querySelector('.modal');
    backdrop.classList.remove('hidden');
    document.body.classList.add('modal-open');

    const animate = await getAnimate();
    animate(backdrop, { opacity: [0, 1] }, { duration: 0.2, easing: 'ease-out' });
    animate(modal, { opacity: [0, 1], scale: [0.95, 1] }, { duration: 0.25, easing: [0.34, 1.56, 0.64, 1] });
}

async function closeModal(backdrop) {
    const modal = backdrop.querySelector('.modal');
    const animate = await getAnimate();

    animate(modal, { opacity: 0, scale: 0.95 }, { duration: 0.15, easing: 'ease-in' });
    await animate(backdrop, { opacity: 0 }, { duration: 0.2, easing: 'ease-in' });

    backdrop.classList.add('hidden');
    document.body.classList.remove('modal-open');
}

document.addEventListener('DOMContentLoaded', () => {
    getAnimate();
    registerModals();
});

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
