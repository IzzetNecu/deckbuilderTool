const RESTORE_FRAMES = 2;

export function captureEditorScroll(container) {
  const positions = [];
  capture(container, null, positions);

  container.querySelectorAll('*').forEach(element => {
    if (!isScrollable(element)) return;
    capture(element, buildElementPath(container, element), positions);
  });

  return () => {
    let frames = RESTORE_FRAMES;
    const restore = () => {
      positions.forEach(position => {
        const element = position.path ? container.querySelector(`:scope > ${position.path}`) : container;
        if (!element) return;
        element.scrollTop = position.top;
        element.scrollLeft = position.left;
      });
      frames -= 1;
      if (frames > 0) requestAnimationFrame(restore);
    };
    requestAnimationFrame(restore);
  };
}

function capture(element, path, positions) {
  positions.push({
    path,
    top: element.scrollTop,
    left: element.scrollLeft
  });
}

function isScrollable(element) {
  return element.scrollTop > 0
    || element.scrollLeft > 0
    || element.scrollHeight > element.clientHeight
    || element.scrollWidth > element.clientWidth;
}

function buildElementPath(root, element) {
  const segments = [];
  let current = element;

  while (current && current !== root) {
    const tagName = current.tagName.toLowerCase();
    let index = 1;
    let sibling = current.previousElementSibling;
    while (sibling) {
      if (sibling.tagName.toLowerCase() === tagName) index += 1;
      sibling = sibling.previousElementSibling;
    }
    segments.unshift(`${tagName}:nth-of-type(${index})`);
    current = current.parentElement;
  }

  return segments.join(' > ');
}
