<?php

/**
 * @file
 * The overlap check that runs on the NEW site — trap 4's companion.
 *
 * Template — copy into a Drupal project as `scripts/audit-migrated-overlap.php`
 * and fill in the CONFIG block below. Companion to the `content-audit` skill and
 * to `content-overlap-sweep.py`; that one sweeps the LEGACY CMS, this one sweeps
 * what has already landed.
 *
 * The sweep compares legacy nodes to legacy nodes, so a node duplicating content
 * that ALREADY migrated is invisible to it. On the reference project that is how
 * a product overview scored a clean 20% against its own cluster and still had to
 * be eliminated: two live commerce products already owned every fact in it.
 *
 * So point the same verbatim-sentence method the other way — a proposed
 * section's nodes against every product and node already on the site. Run it
 * alongside the sweep, before building the section.
 *
 *   ddev drush php:script scripts/audit-migrated-overlap.php -- 999150 999151
 *   ddev drush php:script scripts/audit-migrated-overlap.php -- --preset=learn
 *
 * Read the output the same way as the sweep's: a candidate detector, not a
 * verdict, and a small denominator inflates the score. Crucially, a LOW score
 * does not clear a node — this compares wording, and a section rebuilt as a
 * construction (re-typed rather than copied) scores near zero against the very
 * content it duplicates. Verbatim overlap is evidence of duplication; its
 * absence is not evidence of originality. Apply the group-vs-merge test by hand.
 */

use Drupal\Core\Entity\EntityInterface;
use Drupal\Core\Url;

// --- CONFIG — set these per project ---------------------------------------

// Named clusters of NEW-site nids, so a check is one flag. Mirror the presets in
// content-overlap-sweep.py, but in destination ids — these have migrated.
const AUDIT_PRESETS = [
  // 'learn' => [999150, 999151, 999152],
];

// Entity types already on the site that could own this content. Products are
// the classic case; add any type a section might restate.
const AUDIT_TARGET_TYPES = ['commerce_product', 'node'];

// Node bundles to compare against, or an empty array for all of them.
const AUDIT_TARGET_BUNDLES = [];

// Matches content-overlap-sweep.py's MIN_SENTENCE so the two runs are
// comparable. Short enough to be boilerplate rather than substance.
const AUDIT_MIN_SENTENCE = 45;

// --- end CONFIG ------------------------------------------------------------

/**
 * Tag-stripped, normalised sentences long enough to carry meaning.
 */
function audit_sentences(string $raw): array {
  // Tags become a SPACE, not nothing. `strip_tags()` would turn
  // `…distortion.</p><p>Some applications…` into `distortion.Some`, which the
  // sentence split below cannot break — fusing a whole article into a single
  // giant "sentence" that can never match anything, and reporting a confident
  // no-overlap. This is the one line in the file that will silently invalidate
  // the whole check, and it matches the substitution the Python sweep uses.
  //
  // The literal `\n` / `\t` / `\/` pass is for composed pages, whose prose
  // lives in JSON-encoded component props where a newline arrives as two
  // characters and every slash is escaped.
  $text = str_replace(['\\n', '\\t', '\\/'], [' ', ' ', '/'], $raw);
  $text = html_entity_decode(preg_replace('/<[^>]+>/', ' ', $text), ENT_QUOTES | ENT_HTML5);
  $text = preg_replace('/\s+/', ' ', (string) $text);
  $out = [];
  foreach (preg_split('/(?<=[.!?])\s+/', (string) $text) as $sentence) {
    $sentence = trim(mb_strtolower($sentence));
    if (mb_strlen($sentence) > AUDIT_MIN_SENTENCE) {
      $out[$sentence] = TRUE;
    }
  }
  return $out;
}

/**
 * Every string an entity carries, component tree included.
 *
 * Walks fields rather than rendering: a composed page's prose lives in a props
 * JSON blob that no view mode exposes as text, and rendering each candidate
 * would drag in menus, blocks and footers that then read as shared content on
 * every single pair.
 */
function audit_entity_text(EntityInterface $entity): string {
  $text = '';
  foreach ($entity->getFields(FALSE) as $field) {
    foreach ($field as $item) {
      foreach ($item->getValue() as $value) {
        if (is_string($value)) {
          $text .= ' ' . $value;
        }
      }
    }
  }
  return $text;
}

$nids = [];
foreach ($extra ?? [] as $arg) {
  if (preg_match('/^--preset=(.+)$/', $arg, $match)) {
    if (!isset(AUDIT_PRESETS[$match[1]])) {
      print "Unknown preset {$match[1]} — have: " . implode(', ', array_keys(AUDIT_PRESETS)) . "\n";
      return;
    }
    $nids = array_merge($nids, AUDIT_PRESETS[$match[1]]);
  }
  elseif (ctype_digit($arg)) {
    $nids[] = (int) $arg;
  }
}
if (!$nids) {
  print "Give some nids, or --preset=" . implode('/', array_keys(AUDIT_PRESETS)) . "\n";
  return;
}

$etm = \Drupal::entityTypeManager();
$nodeStorage = $etm->getStorage('node');

$subjects = [];
foreach ($nodeStorage->loadMultiple($nids) as $node) {
  $subjects[$node->id()] = [
    'title' => $node->label(),
    'sent' => audit_sentences(audit_entity_text($node)),
  ];
  print sprintf("%7d  %-52s %3d sentences\n", $node->id(),
    mb_substr($node->label(), 0, 52), count($subjects[$node->id()]['sent']));
}
if ($missing = array_diff($nids, array_keys($subjects))) {
  print '  ! not found: ' . implode(', ', $missing) . "\n";
}

$targets = [];
foreach (AUDIT_TARGET_TYPES as $type) {
  if (!$etm->hasDefinition($type)) {
    continue;
  }
  $storage = $etm->getStorage($type);
  $query = $storage->getQuery()->accessCheck(FALSE);
  if ($type === 'node') {
    $query->condition('nid', $nids, 'NOT IN');
    if (AUDIT_TARGET_BUNDLES) {
      $query->condition('type', AUDIT_TARGET_BUNDLES, 'IN');
    }
  }
  foreach ($storage->loadMultiple($query->execute()) as $entity) {
    $targets[$type . '/' . $entity->id()] = [
      'title' => (string) $entity->label(),
      'sent' => audit_sentences(audit_entity_text($entity)),
    ];
  }
}
print "\nchecked against " . count($targets) . " entities already on the site\n";

// Scored against the smaller side, as the sweep does: a short node wholly
// absorbed by a long one is the strongest signal available.
$pairs = [];
foreach ($subjects as $nid => $subject) {
  foreach ($targets as $key => $target) {
    $shared = array_intersect_key($subject['sent'], $target['sent']);
    if (!$shared) {
      continue;
    }
    $smaller = min(count($subject['sent']), count($target['sent']));
    $pairs[] = [
      'pct' => $smaller ? (int) round(100 * count($shared) / $smaller) : 0,
      'nid' => $nid,
      'subject' => $subject['title'],
      'key' => $key,
      'target' => $target['title'],
      'shared' => array_keys($shared),
    ];
  }
}
usort($pairs, fn (array $a, array $b) => $b['pct'] <=> $a['pct']);

print "\n--- content already owned elsewhere on the new site ---\n";
if (!$pairs) {
  print "  none verbatim — which does NOT clear the set. See the header: a\n"
    . "  re-typed section scores near zero against what it duplicates.\n";
  return;
}
foreach ($pairs as $pair) {
  print sprintf("\n %3d%%  %2d shared   %d %s\n              <-> %s %s\n",
    $pair['pct'], count($pair['shared']), $pair['nid'],
    mb_substr($pair['subject'], 0, 44), $pair['key'], mb_substr($pair['target'], 0, 44));
  foreach (array_slice($pair['shared'], 0, 3) as $sentence) {
    print '        · ' . mb_substr($sentence, 0, 104) . "\n";
  }
}
print "\nA candidate detector, not a verdict — read the node before acting.\n";
