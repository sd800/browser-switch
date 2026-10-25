# Browser Switch website

The product website for Browser Switch, published at **browser-switch.songming.org**.

## Open locally

Double-click `index.html` to open the complete site in a browser. No installation, build step, local server, or internet connection is required for the page and interactive preview. Downloads and GitHub links require an internet connection.

All styles, scripts, and images are local, with relative paths. The site follows the system appearance and offers a temporary appearance toggle. The demo never opens links or saves selections. There are no analytics, cookies, third-party scripts, or browser storage.

## Deploy

The **Deploy website** GitHub Actions workflow uploads this directory directly to GitHub Pages when changes to `web/` or the workflow reach `main`. It can also be started manually from Actions.

In the repository’s **Settings → Pages**, select **GitHub Actions** as the source and set **browser-switch.songming.org** as the custom domain. Configure a DNS CNAME record for `browser-switch` pointing to `sd800.github.io`, then enable **Enforce HTTPS** when GitHub makes it available.

`CNAME`, canonical metadata, `robots.txt`, and `sitemap.xml` use the production domain. Download links point to the published GitHub Release. No GitHub API requests run in visitors’ browsers.

## Assets

The Browser Switch icon is the app’s own icon. Browser icons identify the applications shown in the illustrative picker; the names and icons belong to their respective owners. Their inclusion does not imply endorsement.
