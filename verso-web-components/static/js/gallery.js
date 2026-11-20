document.addEventListener("DOMContentLoaded", () => {
    initTabSelectors();
    initAccessibilityTab();

    const shouldChangeDefault = detectOS() && document.querySelector(".device-tabs");
    if (shouldChangeDefault) {
        changeTabDefault();
    }

    tippy(".code-gallery-run", {
        content: "Opens the current code in the playground!",
    });

    tippy(".social-icon", {
        placement: "top",
    });
});

/** @typedef {{ activeButton: Element | null, activePanel: Element | null }} ActiveState */

/**
 * @param {HTMLElement} element
 * @param {() => void} callback
 */
function observeUntilVisible(element, callback) {
    if (!element) return;

    /** @type {MutationObserver[]} */
    const observers = [];

    /** @param {Element | null} el */
    function isElementVisible(el) {
        while (el) {
            const style = getComputedStyle(el);
            if (
                style.display === "none" ||
                style.visibility === "hidden" ||
                style.opacity === "0"
            ) {
                return false;
            }
            el = el.parentElement;
        }
        return true;
    }

    /** @param {MutationObserver[]} observerList */
    function disconnectAllObservers(observerList) {
        observerList.forEach((observer) => observer.disconnect());
    }

    const targetObserver = new MutationObserver(() => {
        if (isElementVisible(element)) {
            callback();
            disconnectAllObservers(observers);
        }
    });

    targetObserver.observe(element, {
        attributes: true,
        attributeFilter: ["style", "class"],
    });
    observers.push(targetObserver);

    let parent = element.parentElement;
    while (parent && parent !== document.body) {
        const parentObserver = new MutationObserver(() => {
            if (isElementVisible(element)) {
                callback();
                disconnectAllObservers(observers);
            }
        });

        parentObserver.observe(parent, {
            attributes: true,
            attributeFilter: ["style", "class"],
        });
        observers.push(parentObserver);

        parent = parent.parentElement;
    }

    if (isElementVisible(element)) {
        callback();
        disconnectAllObservers(observers);
    }
}

function initAccessibilityTab() {
    /** @type {NodeListOf<HTMLElement>} */ (document.querySelectorAll(".selector-button")).forEach(
        (button) => {
            button.addEventListener("keydown", (e) => {
                if (e.key === "Enter") {
                    e.preventDefault();
                    button.click();
                }
            });
        },
    );
}

/**
 * @param {HTMLElement} button
 * @param {Element} contentContainer
 * @param {ActiveState} activeState
 */
function activateTab(button, contentContainer, activeState) {
    const { activeButton, activePanel } = activeState;

    if (button === activeButton) return;

    if (activeButton) {
        activeButton.classList.remove("active");
        activeButton.setAttribute("aria-selected", "false");
    }

    button.classList.add("active");
    button.setAttribute("aria-selected", "true");
    activeState.activeButton = button;

    const targetPanel = contentContainer.querySelector(
        `:scope > .selector-panel[data-id="${button.dataset["id"]}"]`,
    );

    if (activePanel && activePanel !== targetPanel) {
        activePanel.classList.remove("active");
        activePanel.setAttribute("aria-hidden", "true");
    }

    if (targetPanel) {
        targetPanel.classList.add("active");
        targetPanel.setAttribute("aria-hidden", "false");
        activeState.activePanel = targetPanel;
    }
}

/**
 * @param {HTMLElement} tabsContainer
 * @param {number} index
 */
function setActiveTabByIndex(tabsContainer, index) {
    const tabButtons = /** @type {NodeListOf<HTMLElement>} */ (
        tabsContainer.querySelectorAll(":scope > .selector-list > .selector-button")
    );
    const button = tabButtons[index];
    if (!button) return;

    const dataId = tabsContainer.dataset["id"];
    const contentContainer = document.querySelector(`.selector-panels[data-id="${dataId}"]`);
    if (!contentContainer) return;

    const activeButton = tabsContainer.querySelector(
        ":scope > .selector-list > .selector-button.active",
    );
    const activePanel = contentContainer.querySelector(":scope > .selector-panel.active");
    const activeState = {
        activeButton,
        activePanel,
    };

    activateTab(button, contentContainer, activeState);

    const tabList = tabsContainer.querySelector(".selector-list");
    if (tabList) {
        requestAnimationFrame(() => {
            requestAnimationFrame(() => {
                updateTabBackgroundIndicator(tabList, button);
            });
        });
    }
}

/**
 * @param {Element} tabsContainer
 * @param {Element} contentContainer
 */
function initTabContentPanels(tabsContainer, contentContainer) {
    const tabButtons = /** @type {NodeListOf<HTMLElement>} */ (
        tabsContainer.querySelectorAll(":scope > .selector-list > .selector-button")
    );

    if (tabButtons.length === 0) return;

    const initialButton = tabsContainer.querySelector(
        ':scope > .selector-list > .selector-button[data-initial="true"]',
    );
    if (initialButton) {
        initialButton.classList.add("active");
    }

    const activeButton = tabsContainer.querySelector(
        ":scope > .selector-list > .selector-button.active",
    );
    const activePanel = contentContainer.querySelector(":scope > .selector-panel.active");

    const activeState = {
        activeButton,
        activePanel,
    };

    tabButtons.forEach((button) => {
        button.setAttribute("role", "tab");
        button.setAttribute("aria-selected", button === activeButton ? "true" : "false");

        button.addEventListener("click", () => {
            activateTab(button, contentContainer, activeState);
        });
    });
}

/**
 * @param {HTMLElement} activeBackground
 * @param {HTMLElement} tab
 */
function setBackgroundPosition(activeBackground, tab) {
    tab.offsetHeight; // force reflow
    activeBackground.style.left = `${tab.offsetLeft}px`;
    activeBackground.style.top = `${tab.offsetTop}px`;
    activeBackground.style.width = `${tab.offsetWidth}px`;
    activeBackground.style.height = `${tab.offsetHeight}px`;
}

/**
 * @param {HTMLElement} activeBackground
 * @param {HTMLElement} tab
 */
function springBackgroundPosition(activeBackground, tab) {
    const animate = window.Motion?.animate;
    if (!animate) {
        setBackgroundPosition(activeBackground, tab);
        return;
    }
    animate(
        activeBackground,
        {
            left: tab.offsetLeft,
            top: tab.offsetTop,
            width: tab.offsetWidth,
            height: tab.offsetHeight,
        },
        { type: "spring", stiffness: 400, damping: 28 },
    );
}

/**
 * @param {Element} tabGroup
 * @param {HTMLElement} activeTab
 */
function updateTabBackgroundIndicator(tabGroup, activeTab) {
    const activeBackground = tabGroup.querySelector(".active-background");
    if (!(activeBackground instanceof HTMLElement) || !activeTab) return;

    activeBackground.style.opacity = "1";

    if (activeTab.offsetLeft === 0 || activeTab.offsetWidth === 0) {
        observeUntilVisible(activeTab, () => setBackgroundPosition(activeBackground, activeTab));
        return;
    }

    setBackgroundPosition(activeBackground, activeTab);
}

/** @param {Element} tabGroup */
function initTabBackgroundIndicator(tabGroup) {
    const tabButtons = /** @type {NodeListOf<HTMLElement>} */ (
        tabGroup.querySelectorAll(":scope > .selector-button")
    );
    if (tabButtons.length === 0) return;

    const activeBackground = document.createElement("div");
    activeBackground.classList.add("active-background");
    tabGroup.appendChild(activeBackground);

    let initialized = false;

    /**
     * @param {HTMLElement} tab
     * @param {boolean} [instant]
     */
    function positionBackground(tab, instant = false) {
        if (tab.offsetLeft === 0 && !instant) {
            observeUntilVisible(tab, () => positionBackground(tab, true));
            return;
        }
        if (!initialized || instant) {
            setBackgroundPosition(activeBackground, tab);
            initialized = true;
        } else {
            springBackgroundPosition(activeBackground, tab);
        }
    }

    let activeTab = /** @type {HTMLElement | null} */ (
        tabGroup.querySelector(":scope > .selector-button.active")
    );

    window.addEventListener("resize", () => {
        if (activeTab) positionBackground(activeTab, true);
    });

    tabButtons.forEach((tab) => {
        tab.addEventListener("click", () => {
            tabButtons.forEach((button) => {
                button.classList.remove("active");
                button.setAttribute("aria-selected", "false");
            });

            activeTab = tab;
            tab.classList.add("active");
            tab.setAttribute("aria-selected", "true");

            requestAnimationFrame(() => positionBackground(tab));
        });
    });

    const isDeviceTabs = tabGroup.closest(".device-tabs");
    const shouldChangeDefault = isDeviceTabs && detectOS();

    if (shouldChangeDefault) {
        activeBackground.style.opacity = "0";
    } else if (activeTab) {
        positionBackground(activeTab);
    }
}

function initTabSelectors() {
    const tabContainers = /** @type {NodeListOf<HTMLElement>} */ (
        document.querySelectorAll(".selectors-container")
    );
    if (tabContainers.length === 0) return;

    tabContainers.forEach((container) => {
        const tabList = container.querySelector(".selector-list");
        if (!tabList) return;

        const dataId = container.dataset["id"];
        const panelsContainer = document.querySelector(`.selector-panels[data-id="${dataId}"]`);

        if (panelsContainer) {
            initTabContentPanels(container, panelsContainer);
        }

        initTabBackgroundIndicator(tabList);
    });
}

function detectOS() {
    const platform = navigator.platform.toLowerCase();

    if (platform.includes("win")) {
        return 3;
    }
    if (platform.includes("mac")) {
        return 2;
    }
    if (platform.includes("linux")) {
        return 1;
    }
    return 0;
}

function changeTabDefault() {
    const os = detectOS();

    if (os) {
        const osTabButton = /** @type {HTMLElement | null} */ (
            document.querySelector(`.device-tabs`)
        );

        if (osTabButton) {
            setActiveTabByIndex(osTabButton, os - 1);
        }
    }
}
