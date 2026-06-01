document.addEventListener('DOMContentLoaded', () => {
    initCodeTabs();
    removeTabFocus();
});

function removeTabFocus() {
    const container = document.querySelector('.hero-right');

    if (container) {
        container.querySelectorAll('a, button, input, textarea, select, [tabindex]')
            .forEach(el => el.setAttribute('tabindex', '-1'));
    }
}

function initCodeTabs() {
    const tabs = Array.from(document.querySelectorAll('.code-gallery-tab')).filter(tab => !tab.classList.contains('filler'));
    const codeSnippets = document.querySelectorAll('.code-gallery-snippet');
    const codeTips = document.querySelectorAll('.code-gallery-tip');
    const border = document.querySelector('.code-gallery-tab-border');
    const nextButton = document.querySelector('.hero-footer-next');

    if (tabs.length === 0 || !border) return;

    let activeIndex = tabs.findIndex(tab => tab.classList.contains('active'));
    if (activeIndex === -1) activeIndex = 0;

    function updateBorder(tab) {
        const tabRect = tab.getBoundingClientRect();
        const parentRect = tab.parentElement.getBoundingClientRect();
        const parentScrollLeft = tab.parentElement.scrollLeft || 0;

        border.style.left = `${tabRect.left - parentRect.left + parentScrollLeft}px`;
        border.style.width = `${tabRect.width}px`;
    }

    function setActiveCodeTab(index) {
        tabs.forEach((tab, i) => {
            const isActive = i === index;
            tab.classList.toggle('active', isActive);
            tab.setAttribute('aria-selected', isActive ? 'true' : 'false');
        });

        codeSnippets.forEach((snippet, i) => {
            snippet.classList.toggle('visible-code', i === index);
            snippet.setAttribute('aria-hidden', i !== index);
        });

        codeTips.forEach((tip, i) => {
            tip.classList.toggle('active', i === index);
            tip.setAttribute('aria-hidden', i !== index);
        });

        updateBorder(tabs[index]);
        activeIndex = index;
    }

    tabs.forEach((tab, index) => {
        tab.setAttribute('role', 'tab');
        tab.setAttribute('aria-selected', index === activeIndex ? 'true' : 'false');

        tab.addEventListener('click', () => {
            setActiveCodeTab(index);
        });
    });

    // Listen for scroll events on the tab container to update border position
    const tabContainer = tabs[0]?.parentElement;
    if (tabContainer) {
        tabContainer.addEventListener('scroll', () => {
            updateBorder(tabs[activeIndex]);
        });
    }

    if (nextButton) {
        nextButton.addEventListener('click', () => {
            setActiveCodeTab((activeIndex + 1) % tabs.length);
        });
    }

    setActiveCodeTab(activeIndex);
}

function initCodeAnimations() {
    const codeSnippets = document.querySelectorAll('.code-gallery-snippet');

    codeSnippets.forEach(snippet => {
        const tokens = snippet.querySelectorAll('.token, .inter-text');

        tokens.forEach((token, i) => {
            token.style.animationDelay = `${i * 3 + 30}ms`;
        });
    });
}