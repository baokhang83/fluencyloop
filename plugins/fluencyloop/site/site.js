'use strict';

// Keep personal presentation preferences in the browser, never in the project store.
(() => {
  const root = document.documentElement;
  const button = document.querySelector('[data-theme-toggle]');
  const storageKey = 'fluencyloop.site.theme';

  const updateButton = (theme) => {
    if (!button) return;
    const isDark = theme === 'dark';
    button.textContent = isDark ? 'Light' : 'Dark';
    button.setAttribute('aria-label', 'Switch to ' + (isDark ? 'light' : 'dark') + ' theme');
    button.setAttribute('aria-pressed', String(isDark));
  };

  try {
    const saved = localStorage.getItem(storageKey);
    if (saved === 'light' || saved === 'dark') {
      root.dataset.theme = saved;
      updateButton(saved);
    } else {
      updateButton(window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
    }
  } catch (_) {
    updateButton(window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
  }

  button?.addEventListener('click', () => {
    const current = root.dataset.theme || (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
    const next = current === 'dark' ? 'light' : 'dark';
    root.dataset.theme = next;
    updateButton(next);
    try { localStorage.setItem(storageKey, next); } catch (_) { /* presentation still changes */ }
  });

  requestAnimationFrame(() => { document.body.dataset.motion = 'ready'; });
})();
