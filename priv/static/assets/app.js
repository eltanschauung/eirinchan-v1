(function () {
  function appendQuote(textarea, quote) {
    if (!textarea || !quote) return;

    const prefix = textarea.value && !textarea.value.endsWith("\n") ? "\n" : "";
    const insertion = prefix + ">>" + quote + "\n";

    const start = textarea.selectionStart || textarea.value.length;
    const end = textarea.selectionEnd || textarea.value.length;
    const before = textarea.value.slice(0, start);
    const after = textarea.value.slice(end);

    textarea.value = before + insertion + after;
    const cursor = before.length + insertion.length;
    textarea.selectionStart = cursor;
    textarea.selectionEnd = cursor;
    textarea.focus();
  }

  function targetTextarea(link) {
    const quickReplyThread = link.dataset.quickReplyThread;

    if (quickReplyThread) {
      const form = document.querySelector(
        '[data-quick-reply-form="' + quickReplyThread + '"]'
      );

      if (form) {
        const panel = form.closest("[data-quick-reply-panel]");
        if (panel) panel.hidden = false;
        return form.querySelector("[data-post-body]");
      }
    }

    const threadForm = document.querySelector("[data-thread-reply-form]");
    if (threadForm) {
      return threadForm.querySelector("[data-post-body]");
    }

    const newThreadForm = document.querySelector("#new-thread-form");
    if (newThreadForm) {
      return newThreadForm.querySelector("[data-post-body]");
    }

    return null;
  }

  document.addEventListener("click", function (event) {
    const link = event.target.closest("[data-quote-to]");
    if (!link) return;

    const textarea = targetTextarea(link);
    if (!textarea) return;

    event.preventDefault();
    appendQuote(textarea, link.dataset.quoteTo);
  });
})();
