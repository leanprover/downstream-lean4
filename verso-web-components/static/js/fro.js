window.addEventListener('DOMContentLoaded', () => {
    const heroSection = document.querySelector('.org-hero');

    if (!heroSection) return;

    const img = heroSection.querySelector('img.reveal');

    if (img.complete) {
      // image was cached and already loaded
      heroSection.classList.add('active');
    } else {
      img.onload = () => {
        heroSection.classList.add('active');
      };
      img.onerror = () => {
        console.error('couldn’t load image');
      };
    }
});