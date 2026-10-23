#!/usr/bin/env bash
# Reproducible CI regression check. The fixture exists only in the runner.
set -euo pipefail

SLUG="phase1-draft-leak-fixture"
MARKER="phase1draftleakuniqueprobe6287"
FIXTURE="src/content/towns/${SLUG}.md"
HTML_TEST="dist/phase1-search-check.html"
SERVER_PID=""
BROWSER_PID=""
PROFILE_DIR=""

cleanup() {
  rm -f "$FIXTURE" "$HTML_TEST"
  if [[ -n "$BROWSER_PID" ]]; then
    kill "$BROWSER_PID" 2>/dev/null || true
    wait "$BROWSER_PID" 2>/dev/null || true
  fi
  if [[ -n "$PROFILE_DIR" ]]; then
    rm -rf "$PROFILE_DIR"
  fi
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
    <script>
      (async () => {
      const output = document.querySelector("#result");
      try {
        const pagefind = await import("/pagefind/pagefind.js");
        await pagefind.options({ noWorker: true });
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
      })();
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

# Keep a real headless browser session alive while Pagefind fetches its index.
# --dump-dom can snapshot the page before asynchronous search work finishes.
PROFILE_DIR=$(mktemp -d)
"$CHROME" --headless --no-sandbox --disable-gpu --disable-dev-shm-usage \
  --disable-background-networking --remote-debugging-port=9225 \
  --remote-allow-origins='*' --user-data-dir="$PROFILE_DIR" \
  http://127.0.0.1:4181/phase1-search-check.html \
  > /tmp/beautiful-iowa-phase1-chrome.log 2>&1 &
BROWSER_PID=$!

node --input-type=module <<'NODE'
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
let page;

for (let attempt = 0; attempt < 120; attempt++) {
  try {
    const response = await fetch("http://127.0.0.1:9225/json/list");
    if (response.ok) {
      const targets = await response.json();
      page = targets.find(
        target =>
          target.type === "page" &&
          target.url.includes("phase1-search-check.html")
      );
      if (page) break;
    }
  } catch {
    // Chrome hasn't opened its remote-debugging interface yet.
  }
  await pause(250);
}
if (!page) throw new Error("Chrome did not open the Pagefind test page");

const socket = new WebSocket(page.webSocketDebuggerUrl);
await new Promise((resolve, reject) => {
  socket.addEventListener("open", resolve, { once: true });
  socket.addEventListener("error", reject, { once: true });
});

let id = 0;
const pending = new Map();
socket.addEventListener("message", event => {
  const message = JSON.parse(event.data);
  if (!pending.has(message.id)) return;
  pending.get(message.id)(message);
  pending.delete(message.id);
});

async function readBrowserResult() {
  const requestId = ++id;
  const reply = new Promise(resolve => pending.set(requestId, resolve));
  socket.send(
    JSON.stringify({
      id: requestId,
      method: "Runtime.evaluate",
      params: {
        expression:
          "({ status: document.body?.dataset.phase1Status ?? '', " +
          "output: document.getElementById('result')?.textContent ?? '' })",
        returnByValue: true,
      },
    })
  );
  const result = await reply;
  if (result.error || result.result?.exceptionDetails) {
    throw new Error("Chrome evaluation failed: " + JSON.stringify(result));
  }
  return result.result.result.value;
}

try {
  let state;
  for (let attempt = 0; attempt < 180; attempt++) {
    state = await readBrowserResult();
    if (state?.status === "pass" || state?.status === "fail") break;
    await pause(250);
  }

  if (state?.status !== "pass") {
    throw new Error("Pagefind browser check failed or timed out: " + JSON.stringify(state));
  }

  const expected = [
    "PASS Newton -> /towns/newton-jasper-county/",
    "PASS Effigy Mounds -> /places/effigy-mounds-national-monument/",
    "PASS: draft marker absent from Pagefind search",
  ];
  for (const line of expected) {
    if (!state.output.includes(line)) {
      throw new Error("Missing Pagefind check: " + line + "; got " + state.output);
    }
  }
  console.log(state.output);
  console.log("PASS: live Pagefind queries worked on locally served plain dist");
} finally {
  socket.close();
}
NODE
