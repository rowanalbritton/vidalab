// Hairline under the sticky header once the page has scrolled.
const header = document.querySelector('.site-header');
addEventListener('scroll', () => header?.classList.toggle('scrolled', scrollY > 8), { passive: true });

// Mobile navigation.
const menu = document.querySelector('.menu-button'), links = document.querySelector('.nav-links');
menu?.addEventListener('click', () => {
  const open = links.classList.toggle('open');
  menu.setAttribute('aria-expanded', open);
});

// Research Explorer filters.
const filters = document.querySelectorAll('.filter');
filters.forEach(button => button.addEventListener('click', () => {
  filters.forEach(x => {
    x.classList.toggle('active', x === button);
    x.setAttribute('aria-pressed', x === button);
  });
  const value = button.dataset.filter;
  document.querySelectorAll('.explorer-item').forEach(item => {
    item.hidden = value !== 'all' && !item.dataset.tags.includes(value);
  });
}));
filters.forEach(x => x.setAttribute('aria-pressed', x.classList.contains('active')));

// Site search.
const panel = document.querySelector('.search-panel'),
      input = document.querySelector('#site-search'),
      results = document.querySelector('.search-results'),
      trigger = document.querySelector('.search-button');

const pages = [
  ['CGRP and migraine prevention', '/conditions/migraine/', 'migraine neurology headache treatment cgrp'],
  ['Is POTS partly autoimmune?', '/conditions/pots/', 'pots autonomic dysautonomia autoimmune'],
  ['Long COVID’s biological clues', '/conditions/long-covid/', 'long covid immunology post viral'],
  ['Fibromyalgia research', '/conditions/fibromyalgia/', 'fibromyalgia pain science chronic pain'],
  ['Research Explorer', '/research/', 'research explorer conditions treatments technology diagnostics'],
  ['The VIDA LAB App', '/app/', 'app ios iphone patterns doctor prep library'],
  ['About VIDA LAB', '/about/', 'about editorial standards mission'],
  ['Support and FAQ', '/support', 'support help faq contact bug'],
  ['Privacy Policy', '/privacy', 'privacy data encryption apple health'],
  ['Terms of Use', '/terms', 'terms legal subscription vida plus'],
];

const closeSearch = () => {
  if (!panel?.classList.contains('open')) return;
  panel.classList.remove('open');
  trigger?.focus();
};

trigger?.addEventListener('click', () => {
  panel.classList.add('open');
  input.focus();
  input.select();
});
panel?.addEventListener('click', e => { if (e.target === panel) closeSearch(); });
addEventListener('keydown', e => {
  if (e.key !== 'Escape') return;
  closeSearch();
  if (links?.classList.contains('open')) {
    links.classList.remove('open');
    menu.setAttribute('aria-expanded', 'false');
  }
});

input?.addEventListener('input', () => {
  const q = input.value.trim().toLowerCase();
  if (!q) { results.innerHTML = ''; return; }
  const hits = pages.filter(([name, , keywords]) =>
    name.toLowerCase().includes(q) || keywords.includes(q));
  results.innerHTML = hits.length
    ? hits.map(([name, url]) => `<a href="${url}">${name} →</a>`).join('')
    : '<span>No matching VIDA LAB pages yet.</span>';
});

// Newsletter sign-up, handled by Netlify Forms without leaving the page.
document.querySelectorAll('.newsletter-form').forEach(form => form.addEventListener('submit', async e => {
  e.preventDefault();
  const status = form.parentElement.querySelector('.form-status');
  const button = form.querySelector('button');
  status.textContent = 'Joining…';
  button.disabled = true;
  try {
    const response = await fetch('/', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams(new FormData(form)).toString(),
    });
    if (!response.ok) throw new Error(response.status);
    form.reset();
    status.textContent = 'You’re in. Stay curious.';
  } catch {
    status.textContent = 'That didn’t go through. Please try again, or email hello@vidalab.co.';
  } finally {
    button.disabled = false;
  }
}));
