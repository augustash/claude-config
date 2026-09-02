<?php

/**
 * @file
 * Finds component props that render fine but block the Alchemist editor.
 *
 * THE TRAP. A `type: string` prop is backed by a Drupal `string` field, capped
 * at 255 characters. A builder writing straight to storage never validates, so
 * an over-long value renders perfectly on the page — but the moment anyone opens
 * that component in the editor, form validation fails on every offending item
 * and the component save can never complete. It does not report the field: the
 * component modal simply refuses to return to layout level, so the entity save
 * is never reachable. It reads as "saving is broken".
 *
 * First found 2026-08-12 (DMX): sections_s1's `super_copy` carried 279–1022
 * characters on 28 items, and pillars_s1's `text` one at 387. Fix per prop is
 * `format: textarea`, which swaps the backing field to `string_long` (see
 * StringShape's `formats`) — same string value, no cap, and the right control
 * for a paragraph. See [[neo-alchemist-builder-value-blocks-editor]].
 *
 * This audits ACTUAL STORED VALUES rather than guessing from schemas, because
 * only a real over-long value is a real blocker.
 *
 * Copy into the project's scripts/ and run:
 *   ddev drush scr scripts/audit-string-prop-overflow.php
 */

declare(strict_types=1);

const LIMIT = 255;

// Set to TRUE to include props already fixed with `format: textarea` — used to
// self-test the detector against a known case.
const IGNORE_EXEMPTIONS = FALSE;

$out = fn (string $s = '') => print($s . PHP_EOL);

// --- Which prop names are `string`-typed, per component ---------------------
// ⚠ Read from the LIVE SDC definition, never the neo_component entity's stored
// `schema`/`expression`. That snapshot only re-syncs on certain triggers (not on
// `drush cr`), so a prop just fixed in the yml still looks unfixed there — the
// audit would keep reporting a resolved problem, or miss a new prop entirely.
$stringProps = [];
$textareaProps = [];

/**
 * Collects string-typed prop names, and which of them are textarea-backed.
 */
function md_audit_collect(array $schema, string $id, array &$stringProps, array &$textareaProps): void {
  foreach ($schema['properties'] ?? [] as $name => $prop) {
    if (!is_array($prop)) {
      continue;
    }
    if (($prop['type'] ?? '') === 'string') {
      $stringProps[$id][$name] = TRUE;
      if (($prop['format'] ?? '') === 'textarea') {
        $textareaProps[$id][$name] = TRUE;
      }
    }
    // Recurse into object properties and array item schemas.
    md_audit_collect($prop, $id, $stringProps, $textareaProps);
    if (isset($prop['items']) && is_array($prop['items'])) {
      md_audit_collect($prop['items'], $id, $stringProps, $textareaProps);
    }
  }
}

foreach (\Drupal::service('plugin.manager.sdc')->getDefinitions() as $definition) {
  if (empty($definition['neo']) || empty($definition['props'])) {
    continue;
  }
  md_audit_collect($definition['props'], $definition['machineName'], $stringProps, $textareaProps);
}
$out('components with string props: ' . count($stringProps));

/**
 * Walks a stored prop tree, reporting long values whose key is a string prop.
 */
function md_audit_walk(mixed $data, array $names, array $exempt, array $path, array &$hits): void {
  if (!is_array($data)) {
    return;
  }
  foreach ($data as $key => $value) {
    $here = array_merge($path, [$key]);
    if (is_string($value)) {
      // The value sits under `value` in canonical storage, so the meaningful
      // key is the nearest non-`value` ancestor.
      $owner = NULL;
      foreach (array_reverse($here) as $segment) {
        if (!is_int($segment) && $segment !== 'value') {
          $owner = $segment;
          break;
        }
      }
      if ($owner !== NULL && isset($names[$owner]) && !isset($exempt[$owner]) && mb_strlen($value) > LIMIT) {
        $hits[$owner][] = mb_strlen($value);
      }
      continue;
    }
    md_audit_walk($value, $names, $exempt, $here, $hits);
  }
}

// --- Walk every stored component tree --------------------------------------
$found = [];
$fieldMap = \Drupal::service('entity_field.manager')->getFieldMapByFieldType('neo_component_tree');
foreach ($fieldMap as $entityTypeId => $fields) {
  $storage = \Drupal::entityTypeManager()->getStorage($entityTypeId);
  foreach (array_keys($fields) as $fieldName) {
    $ids = $storage->getQuery()->accessCheck(FALSE)->exists($fieldName)->execute();
    foreach ($storage->loadMultiple($ids) as $entity) {
      foreach ($entity->get($fieldName) as $item) {
        $value = $item->getValue();
        $props = is_string($value['props'] ?? '') ? json_decode($value['props'], TRUE) : ($value['props'] ?? []);
        $tree = is_string($value['tree'] ?? '') ? json_decode($value['tree'], TRUE) : ($value['tree'] ?? []);
        // Map of uuid => component id. ⚠ Walked recursively: the tree is keyed by
        // region uuid, and a component dropped into a `region` prop nests
        // another level down. A flat two-deep loop silently skips every nested
        // component — and warns about the missing keys while doing it.
        $components = [];
        $collect = static function (mixed $branch) use (&$collect, &$components): void {
          if (!is_array($branch)) {
            return;
          }
          if (isset($branch['uuid'], $branch['component'])) {
            $components[$branch['uuid']] = $branch['component'];
          }
          foreach ($branch as $child) {
            $collect($child);
          }
        };
        $collect($tree ?: []);
        foreach (($props ?: []) as $uuid => $stored) {
          $componentId = $components[$uuid] ?? NULL;
          if ($componentId === NULL || empty($stringProps[$componentId])) {
            continue;
          }
          $hits = [];
          md_audit_walk(
            $stored['props'] ?? [],
            $stringProps[$componentId],
            IGNORE_EXEMPTIONS ? [] : ($textareaProps[$componentId] ?? []),
            [],
            $hits
          );
          foreach ($hits as $prop => $lengths) {
            $key = "$componentId :: $prop";
            $found[$key]['count'] = ($found[$key]['count'] ?? 0) + count($lengths);
            $found[$key]['max'] = max($lengths + [$found[$key]['max'] ?? 0]);
            $found[$key]['where']["$entityTypeId {$entity->id()} “{$entity->label()}”"] = TRUE;
          }
        }
      }
    }
  }
}

$out('');
if (!$found) {
  $out('✓ No stored string prop exceeds ' . LIMIT . ' characters. Nothing blocks the editor.');
  return;
}

$out('⚠ ' . count($found) . ' prop(s) hold values over ' . LIMIT . ' chars — each blocks its');
$out('  component from being saved in the editor. Fix: add `format: textarea`.');
$out('');
ksort($found);
foreach ($found as $key => $info) {
  $out(sprintf('  %-42s %3d value(s), longest %d', $key, $info['count'], $info['max']));
  foreach (array_keys($info['where']) as $where) {
    $out("      · $where");
  }
}
