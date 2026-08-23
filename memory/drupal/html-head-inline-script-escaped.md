---
name: An inline head script is HTML-escaped, so >= and && break it
description: a pre-paint <head> script silently stops running the moment you add a comparison or a logical AND — html_tag autoescapes #value, and an entity inside <script> is never decoded back
type: reference
---

Anything attached as `html_head` with `'#tag' => 'script'` renders through the
`html_tag` template, whose `{{ value }}` is **autoescaped**. So a `#value` string
containing `>`, `<` or `&` ships as `&gt;`, `&lt;`, `&amp;` — and the HTML parser
does **not** decode entities inside `<script>`, which is raw-text content. The
browser sees literal `&gt;=` and throws `SyntaxError`. The whole script never
runs.

```php
// Ships as: if(N-last&gt;=600000){...}  → SyntaxError, gate dead.
$attachments['#attached']['html_head'][] = [
  ['#tag' => 'script', '#value' => $script],
  'my_gate',
];

// Correct.
use Drupal\Core\Render\Markup;
['#tag' => 'script', '#value' => Markup::create($script)],
```

**Why it hides.** These scripts are usually written first as pure equality and
membership checks — `indexOf(x)!==-1`, `getItem(k)`, `classList.add()` — none of
which contain an escaped character, so the original ships and works. The break
arrives later, in an edit that looks trivial: a `>=` for a time window, an `&&`
joining two conditions. The failure is total and instant, but it is in a
pre-paint gate whose whole job is to be invisible, so what you observe is the
FEATURE misbehaving — an overlay that shows every single view, a consent notice
that reappears after a choice — not a broken script. Nothing on the server side
changed, and the PHP is valid, so the hunt starts in the wrong place.

`Markup::create()` is safe here for exactly one reason: every byte of the string
is authored in the module. The moment any part comes from config, a field, or a
request, it must be JSON-encoded into the script (`Json::encode()`) rather than
concatenated — marking user input as safe markup inside a `<script>` is an XSS,
and the autoescape you just bypassed was the thing stopping it.

**Check the emitted bytes, not the PHP.** `curl -s <url> | grep -o "var show=[^<]*"`
— if you see `&gt;` or `&amp;&amp;` anywhere between `<script>` tags, that is the
bug, whatever else is going on.

Same trap, same fix, for any inline `<script>` or `<style>` built as a `#value`
string — `hook_page_attachments()`, `hook_preprocess_html()`, a render array in a
block. Related: [[private-file-gate]] is the other case where a gate looks
correct in code and fails only in what the browser actually receives.
