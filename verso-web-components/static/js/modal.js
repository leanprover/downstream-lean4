/** @type {typeof import("motion").animate | null} */
let _animate = null;

async function getAnimate() {
    if (_animate) return _animate;
    const { animate } = await import("https://cdn.jsdelivr.net/npm/motion@latest/+esm");
    _animate = animate;
    return animate;
}

/** @param {string} id */
async function openModal(id) {
    const backdrop = document.getElementById(id);
    if (!backdrop) return;

    const modal = backdrop.querySelector(".modal");
    backdrop.classList.remove("hidden");
    document.body.classList.add("modal-open");

    const animate = await getAnimate();
    animate(backdrop, { opacity: [0, 1] }, { duration: 0.2, ease: "easeOut" });
    if (modal) {
        animate(
            modal,
            { opacity: [0, 1], scale: [0.95, 1] },
            { duration: 0.25, ease: [0.34, 1.56, 0.64, 1] },
        );
    }
}

/** @param {Element} backdrop */
async function closeModal(backdrop) {
    const modal = backdrop.querySelector(".modal");
    const animate = await getAnimate();

    if (modal) {
        animate(modal, { opacity: 0, scale: 0.95 }, { duration: 0.15, ease: "easeIn" });
    }
    await animate(backdrop, { opacity: 0 }, { duration: 0.2, ease: "easeIn" });

    backdrop.classList.add("hidden");
    document.body.classList.remove("modal-open");
}

document.addEventListener("DOMContentLoaded", () => {
    getAnimate();
    registerModals();
});

function registerModals() {
    document.querySelectorAll("[data-modal-target]").forEach((trigger) => {
        trigger.addEventListener("click", () => {
            const targetId = trigger.getAttribute("data-modal-target");
            if (targetId) openModal(targetId);
        });
    });

    document.querySelectorAll(".modal-backdrop").forEach((backdrop) => {
        document.body.appendChild(backdrop);

        backdrop.addEventListener("click", (e) => {
            const modalBox = backdrop.querySelector(".modal");
            const target = /** @type {Element} */ (e.target);
            if (!modalBox) return;
            if (!modalBox.contains(target) || target.classList.contains("modal-close")) {
                closeModal(backdrop);
            }
        });
    });
}
