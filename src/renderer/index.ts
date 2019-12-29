function init() {
  console.log('initialized');
  console.log('called3');
}

if (document.readyState !== 'loading') {
  init();
} else {
  document.addEventListener('DOMContentLoaded', init);
}
