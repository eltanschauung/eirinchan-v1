(function () {
  function identity(value) {
    return value;
  }

  function onReady(callback) {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', callback, { once: true });
    } else {
      callback();
    }
  }

  function appendStyleChooser() {
    if (document.querySelector('div.styles')) return;

    var styles = window.styles || {
      Yotsuba: '/stylesheets/yotsuba.css',
      Contrast: '/stylesheets/contrast.css'
    };
    var selected = window.selectedstyle || localStorage.getItem('stylesheet') || 'Yotsuba';
    var container = document.createElement('div');
    container.className = 'styles';

    Object.keys(styles).forEach(function (styleName) {
      var link = document.createElement('a');
      link.href = 'javascript:void(0);';
      link.textContent = '[' + styleName + ']';
      if (styleName === selected) link.className = 'selected';
      link.addEventListener('click', function () {
        if (typeof window.changeStyle === 'function') {
          window.changeStyle(styleName, link);
        }
      });
      container.appendChild(link);
    });

    document.body.appendChild(container);
  }

  window._ = window._ || identity;
  window.fmt = window.fmt || function (string, args) {
    return string.replace(/\{([0-9]+)\}/g, function (_, index) {
      return args[index];
    });
  };
  window.onReady = window.onReady || onReady;
  window.resourceVersion = window.resourceVersion || '';
  window.selectedstyle = window.selectedstyle || 'Yotsuba';
  window.styles = window.styles || {
    Yotsuba: '/stylesheets/yotsuba.css',
    Contrast: '/stylesheets/contrast.css'
  };

  window.changeStyle =
    window.changeStyle ||
    function (styleName, link) {
      var stylePath = window.styles[styleName];
      if (!stylePath) return;

      var node = document.getElementById('stylesheet');
      if (!node) {
        node = document.createElement('link');
        node.rel = 'stylesheet';
        node.type = 'text/css';
        node.id = 'stylesheet';
        document.head.appendChild(node);
      }

      node.href = stylePath + (window.resourceVersion ? '?v=' + window.resourceVersion : '');
      window.selectedstyle = styleName;
      try {
        localStorage.setItem('stylesheet', styleName);
      } catch (_error) {
      }

      document.querySelectorAll('div.styles a').forEach(function (styleLink) {
        styleLink.className = styleLink === link ? 'selected' : '';
      });
    };

  window.initStyleChooser = window.initStyleChooser || appendStyleChooser;
  window.getCookie =
    window.getCookie ||
    function (cookieName) {
      var match = document.cookie.match('(?:^|; )' + cookieName + '=([^;]*)');
      return match ? decodeURIComponent(match[1]) : null;
    };
  window.get_cookie = window.get_cookie || window.getCookie;
  window.do_boardlist = window.do_boardlist || function () {};
  window.ready =
    window.ready ||
    function () {
      document.body.classList.add('desktop-style');
      window.initStyleChooser();
    };
})();
