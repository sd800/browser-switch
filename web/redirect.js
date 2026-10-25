"use strict";

(() => {
  const { protocol, pathname, search, hash } = window.location;
  if ((protocol === "https:" || protocol === "http:") &&
      ["/index", "/index/", "/index.html", "/index/index.html"].includes(pathname)) {
    window.location.replace(`/${search}${hash}`);
  }
})();
