document.addEventListener('DOMContentLoaded', function() {
(function() {
  var tocFloat = document.getElementById('toc-float');
  if (!tocFloat) return;

  var tocWrapper = document.getElementById('toc-wrapper');
  var tocUl = null;

  if (tocWrapper) {
    tocUl = tocWrapper.querySelector(':scope > ul');
  } else {
    var markdownBody = document.querySelector('.markdown-body');
    if (markdownBody) {
      var allUls = markdownBody.querySelectorAll('ul');
      for (var i = 0; i < allUls.length; i++) {
        var ul = allUls[i];
        if (ul.closest('li')) continue;
        var topLi = ul.querySelectorAll(':scope > li');
        if (topLi.length === 0) continue;
        var tocCount = 0;
        for (var j = 0; j < topLi.length; j++) {
          if (topLi[j].querySelector('a[href^="#"]')) tocCount++;
        }
        if (tocCount === topLi.length) {
          var wrapper = document.createElement('div');
          wrapper.id = 'toc-wrapper';
          ul.parentNode.insertBefore(wrapper, ul);
          wrapper.appendChild(ul);
          tocWrapper = wrapper;
          tocUl = ul;
          break;
        }
      }
    }
  }

  if (!tocUl) return;

  var clone = tocUl.cloneNode(true);
  tocFloat.appendChild(clone);
  tocFloat.classList.add('toc-has-content');

  var headings = Array.from(
    document.querySelectorAll('.markdown-body h1[id], .markdown-body h2[id], .markdown-body h3[id], .markdown-body h4[id]')
  );
  var links = Array.from(tocFloat.querySelectorAll('a[href^="#"]'));

  function updateActive() {
    var active = null;
    var threshold = Math.round(window.innerHeight * 0.35);
    for (var i = headings.length - 1; i >= 0; i--) {
      if (headings[i].getBoundingClientRect().top <= threshold) {
        active = headings[i].id;
        break;
      }
    }
    links.forEach(function(link) {
      var id = decodeURIComponent(link.getAttribute('href').slice(1));
      if (id === active) {
        link.classList.add('toc-active');
      } else {
        link.classList.remove('toc-active');
      }
    });
  }

  window.addEventListener('scroll', updateActive, { passive: true });
  updateActive();

  var main = document.getElementById('_main');
  function adjustForToc() {
    if (!main) return;
    var tocStyle = window.getComputedStyle(tocFloat);
    if (tocStyle.display === 'none' || tocStyle.position !== 'fixed') {
      main.style.width = '';
      main.style.maxWidth = '';
      return;
    }
    var tocLeft = tocFloat.getBoundingClientRect().left;
    var contentLeft = main.getBoundingClientRect().left;
    var available = Math.floor(tocLeft - contentLeft - 16);
    if (available > 100) {
      main.style.width = available + 'px';
      main.style.maxWidth = 'none';
    }
  }
  adjustForToc();
  window.addEventListener('resize', adjustForToc, { passive: true });
})();
});
