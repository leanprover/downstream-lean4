document.addEventListener('DOMContentLoaded', () => {
    initTestimonials();
});

function initTestimonials() {
    const testimonials = document.querySelectorAll('.testimonial-card');
    const circles = document.querySelectorAll('.select-circles .circle');

    let activeIndex = Array.from(testimonials).findIndex(card => card.classList.contains('active'));
    if (activeIndex === -1) activeIndex = 0;

    circles.forEach((circle, index) => {
        circle.setAttribute('role', 'tab');
        circle.setAttribute('aria-selected', index === activeIndex ? 'true' : 'false');

        circle.addEventListener('click', () => {
            setActiveTestimonial(index, testimonials, circles);
        });
    });

    setActiveTestimonial(activeIndex, testimonials, circles);
}

function setActiveTestimonial(index, testimonials, circles) {
    testimonials.forEach((card, i) => {
        card.classList.toggle('active', i === index);
        card.setAttribute('aria-hidden', i !== index);
    });

    circles.forEach((circle, i) => {
        const isActive = i === index;
        circle.classList.toggle('filled', isActive);
        circle.classList.toggle('outlined', !isActive);
        circle.setAttribute('aria-selected', isActive ? 'true' : 'false');
    });
}