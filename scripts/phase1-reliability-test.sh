#!/usr/bin/env bash
# Reproducible CI regression check. The fixture exists only in the runner.
set -euo pipefail

SLUG="phase1-draft-leak-fixture"
MARKER="phase1draftleakuniqueprobe6287"
FIXTURE="src/content/towns/${SLUG}.md"
HTML_TEST="dist/phase1-search-check.html"
SERVER_PID=""

cleanup() {
  rm -f "$FIXTURE" "$HTML_TEST"
  if [[ -n "$SERVER_PID" ]]; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

if [[ -e "$FIXTURE" ]]; then
  echo "FAIL: regression fixture path already exists"
  exit 1
fi

cat > "$FIXTURE" <<'DRAFT'
---
title: "Phase 1 draft leak fixture"
town: "Phase One"
county: "Test County"
pubDatetime: 2026-10-23
description: "phase1draftleakuniqueprobe6287"
draft: true
---

phase1draftleakuniqueprobe6287
DRAFT

echo "Building site with temporary draft fixture..."
npm run build
rm -f "$FIXTURE"

if [[ -e "dist/towns/${SLUG}/index.html" ]]; then
  echo "FAIL: draft fixture generated an HTML page"
  exit 1
fi
echo "PASS: draft fixture did not generate dist/towns/${SLUG}/index.html"

shopt -s nullglob
sitemaps=(dist/sitemap*.xml)
if [[ ${#sitemaps[@]} -eq 0 ]]; then
  echo "FAIL: no generated sitemap was found"
  exit 1
fi
if grep -Fq "$SLUG" "${sitemaps[@]}"; then
  echo "FAIL: draft fixture appeared in the sitemap"
  exit 1
fi
echo "PASS: draft fixture absent from ${#sitemaps[@]} generated sitemap file(s)"

test -f dist/pagefind/pagefind.js || {
  echo "FAIL: Pagefind JavaScript missing from plain dist output"
  exit 1
}

# This HTML is written to dist only after indexing, so it cannot affect the index.
cat > "$HTML_TEST" <<'HTML'
<!doctype html>
<html lang="en">
  <head><meta charset="utf-8"><title>Phase 1 Pagefind check</title></head>
  <body>
    <pre id="result">Searches have not completed.</pre>
    <script type="module">
      const output = document.querySelector("#result");
      try {
        const pagefind = await import("/pagefind/pagefind.js");
        const checks = [
          ["Newton", "/towns/newton-jasper-county/"],
          ["Effigy Mounds", "/places/effigy-mounds-national-monument/"],
        ];
        const lines = [];

        for (const [query, expectedUrl] of checks) {
          const matches = await pagefind.search(query);
          const pages = await Promise.all(matches.results.map(match => match.data()));
          const urls = pages.map(page => page.url);
          if (!urls.some(url => url.includes(expectedUrl))) {
            throw new Error(query + " did not return " + expectedUrl + "; got " + urls.join(", "));
          }
          lines.push("PASS " + query + " -> " + expectedUrl);
        }

        const draftResults = await pagefind.search("phase1draftleakuniqueprobe6287");
        if (draftResults.results.length !== 0) {
          throw new Error("Draft fixture appeared in Pagefind results");
        }
        lines.push("PASS: draft marker absent from Pagefind search");
        document.body.dataset.phase1Status = "pass";
        output.textContent = lines.join("\n");
      } catch (error) {
        document.body.dataset.phase1Status = "fail";
        output.textContent = "FAIL: " + String(error);
      }
    </script>
  </body>
</html>
HTML

python3 -m http.server 4181 --bind 127.0.0.1 --directory dist > /tmp/beautiful-iowa-phase1-http.log 2>&1 &
SERVER_PID=$!

ready=false
for _ in {1..40}; do
  if curl -fsS http://127.0.0.1:4181/pagefind/pagefind.js -o /dev/null; then
    ready=true
    break
  fi
  sleep 0.25
done
if [[ "$ready" != true ]]; then
  echo "FAIL: local server did not serve Pagefind"
  exit 1
fi

CHROME=""
for browser in google-chrome google-chrome-stable chromium chromium-browser; do
  if command -v "$browser" >/dev/null 2>&1; then
    CHROME="$browser"
    break
  fi
done
if [[ -z "$CHROME" ]]; then
  echo "FAIL: no Chromium-based browser installed to verify real searches"
  exit 1
fi

"$CHROME" --headless --no-sandbox --disable-gpu --disable-dev-shm-usage \
  --disable-background-networking --virtual-time-budget=30000 --dump-dom \
  http://127.0.0.1:4181/phase1-search-check.html \
  > /tmp/beautiful-iowa-phase1-browser.html \
  2> /tmp/beautiful-iowa-phase1-chrome.log

if ! grep -Fq 'data-phase1-status="pass"' /tmp/beautiful-iowa-phase1-browser.html; then
  echo "FAIL: served-dist browser/Pagefind verification failed"
  grep -A 8 'id="result"' /tmp/beautiful-iowa-phase1-browser.html || true
  tail -n 30 /tmp/beautiful-iowa-phase1-chrome.log || true
  exit 1
fi

grep -Fq 'PASS Newton' /tmp/beautiful-iowa-phase1-browser.html
echo "PASS Newton -> /towns/newton-jasper-county/"
grep -Fq 'PASS Effigy Mounds' /tmp/beautiful-iowa-phase1-browser.html
echo "PASS Effigy Mounds -> /places/effigy-mounds-national-monument/"
grep -Fq 'PASS: draft marker absent from Pagefind search' /tmp/beautiful-iowa-phase1-browser.html
echo "PASS: draft marker absent from Pagefind search"
echo "PASS: live Pagefind queries worked on locally served plain dist"
