"use strict";

(() => {
  const demo = document.getElementById("demo");
  const tabs = [...document.querySelectorAll("[data-route]")];
  const rows = [...document.querySelectorAll("[data-browser]")];
  const status = document.getElementById("demo-status");
  const panel = document.getElementById("preview-panel");
  let route = "ask";

  function setRoute(next) {
    route = next;
    const asks = route === "ask";
    tabs.forEach(tab => {
      const selected = tab.dataset.route === route;
      tab.setAttribute("aria-selected", String(selected));
      tab.tabIndex = selected ? 0 : -1;
    });
    panel.setAttribute("aria-labelledby", asks ? "ask-tab" : "default-tab");
    document.getElementById("browser-choices").hidden = !asks;
    document.getElementById("automatic-route").hidden = asks;
    document.getElementById("picker-title").textContent = asks ? "Open link with…" : "On its way.";
    document.getElementById("picker-domain").textContent = asks ? "github.com" : "wikipedia.org";
    document.getElementById("preview-url").textContent = asks ? "https://github.com/sd800/browser-switch" : "https://wikipedia.org/";
    document.getElementById("picker-hint").textContent = asks ? "Click a browser, or try keys 1–4." : "Your everyday browser takes it from here.";
    rows.forEach(row => row.classList.remove("is-selected"));
    status.textContent = asks ? "Try the preview. No actual links are opened." : "Demo: this link would open in Google Chrome automatically.";
  }

  function choose(row) {
    rows.forEach(other => other.classList.toggle("is-selected", other === row));
    status.textContent = `Demo: github.com would open in ${row.dataset.browser}.`;
  }

  tabs.forEach((tab, index) => {
    tab.addEventListener("click", () => setRoute(tab.dataset.route));
    tab.addEventListener("keydown", event => {
      let next;
      if (event.key === "ArrowLeft" || event.key === "ArrowRight") next = tabs[1 - index];
      if (event.key === "Home") next = tabs[0];
      if (event.key === "End") next = tabs[tabs.length - 1];
      if (!next) return;
      event.preventDefault();
      setRoute(next.dataset.route);
      next.focus();
    });
  });
  rows.forEach(row => row.addEventListener("click", () => choose(row)));
  demo.addEventListener("keydown", event => {
    if (route !== "ask" || event.metaKey || event.ctrlKey || event.altKey || event.shiftKey || event.repeat) return;
    const index = ["1", "2", "3", "4"].indexOf(event.key);
    if (index === -1) return;
    event.preventDefault();
    choose(rows[index]);
  });

  const themeToggle = document.getElementById("theme-toggle");
  const systemTheme = window.matchMedia("(prefers-color-scheme: dark)");
  let themeWasChosen = false;
  function updateTheme(dark) {
    document.documentElement.dataset.theme = dark ? "dark" : "light";
    themeToggle.setAttribute("aria-label", `Switch to ${dark ? "light" : "dark"} appearance`);
  }
  updateTheme(systemTheme.matches);
  themeToggle.hidden = false;
  themeToggle.addEventListener("click", () => {
    themeWasChosen = true;
    updateTheme(document.documentElement.dataset.theme !== "dark");
  });
  systemTheme.addEventListener("change", event => {
    if (!themeWasChosen) updateTheme(event.matches);
  });
})();
