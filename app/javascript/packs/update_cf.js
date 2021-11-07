import clipboard from 'clipboard';

new clipboard('.copy-btn', {
  text: function (trigger) {
    const ele = document.getElementById(trigger.dataset.clipboardTarget.replace("#", ""))
    return ele.getAttribute('href');
  }
})