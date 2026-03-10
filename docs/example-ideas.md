# Example Ideas

Examples that showcase QuickBEAM's unique strengths: JS + BEAM + DOM working
together in ways no other JS runtime can.

## Web Scraper

Fetch pages, parse with `document`, extract data with `querySelector`, store
via `beam.callSync` to Ecto. Multiple supervised runtimes scraping in parallel
with rate limiting from the Elixir side.

**Features:** fetch + DOM + BEAM integration + supervision + concurrent runtimes

## Server-Side Rendering

Load a JS template engine (Mustache/Handlebars or raw template literals),
render HTML, then Elixir reads the DOM back with `dom_find` for SEO metadata
extraction. Plug/Bandit serves the result.

**Features:** DOM + Elixir DOM API + `:script` + web server integration

## Link Checker

Supervised runtimes crawl a site: fetch page → parse DOM → extract all
`<a href>` → report broken links. BFS with Elixir managing the queue, JS
doing the parsing.

**Features:** fetch + DOM + supervision + message passing

## Markdown-to-HTML Pipeline

JS runtime converts markdown (via a small lib like marked), then Elixir
inspects the DOM to build a table of contents, validate heading hierarchy,
extract code blocks.

**Features:** Elixir DOM API as the differentiator — read JS-produced DOM
from Elixir without re-parsing

## RSS/Atom Feed Aggregator

Fetch multiple feeds, parse XML/HTML, normalize entries, deduplicate via
BEAM ETS.

**Features:** fetch + DOM + beam.callSync + concurrent runtimes
