---
name: Search API / Solr server + index naming convention (and DDEV-injected local Solr)
description: Standard across Augustash sites — index id `global`, servers `pantheon_search` (prod) + `local` (DDEV), with the local server connection injected at runtime by settings.local.php against the standardized DDEV Solr Docker build. Don't hand-roll off-convention server names.
type: feedback
---

Augustash sites wire Search API + Solr the same way everywhere. Follow it so local dev is identical across the team and config deploys cleanly to Pantheon.

## Names (use these exactly)

- **Index id: `global`** — the standard content/product index. The `search_api.index.primary` that ships as boilerplate from `search_api_pantheon` is a placeholder to **replace**, not the convention.
- **Server ids:** `pantheon_search` (production cloud Solr, auto-configured by `search_api_pantheon`) and `local` (DDEV).

Never invent names like `local_solr` / `my_index`. Committed config uses `global` + `local` + `pantheon_search` so every site matches.

## How the local server is wired (settings.local.php, not active config)

The `local` server's **connection is injected at runtime** in `web/sites/default/settings.local.php` — never committed into active config (consistent with [local-config-in-settings-local.md](../preferences/local-config-in-settings-local.md)). The committed `search_api.server.local.yml` is just a base (status off / placeholder connection); settings.local.php turns it on and fills the host per-environment:

```php
$config['search_api.index.global']['server'] = 'local';
$config['search_api.server.local']['status'] = TRUE;
$config['search_api.server.local']['backend_config']['connector'] = 'solr_cloud_basic_auth';
$config['search_api.server.local']['backend_config']['connector_config']['scheme'] = 'http';
$config['search_api.server.local']['backend_config']['connector_config']['host'] = $_ENV['DDEV_SITENAME'] . '.' . $_ENV['DDEV_TLD'];
$config['search_api.server.local']['backend_config']['connector_config']['core'] = 'search';
$config['search_api.server.local']['backend_config']['connector_config']['username'] = 'solr';
$config['search_api.server.local']['backend_config']['connector_config']['password'] = 'SolrRocks';
$config['search_api.server.local']['backend_config']['connector_config']['port'] = 8983;
```

So: prod ignores settings.local.php → index `global` stays on `pantheon_search`. Locally → `global` is repointed to `local` and activated. The connector is **`solr_cloud_basic_auth`** (SolrCloud, not standalone), Basic Auth `solr` / `SolrRocks`.

## DDEV Solr build (standardized Docker)

DDEV provides Solr via a standardized add-on: `.ddev/docker-compose.solr.yaml` — **Solr 8.11 Cloud**, 3 nodes (solr1/2/3, ports 8983–8985) + a ZooKeeper node, Basic Auth `solr`/`SolrRocks`, security.json at `.ddev/solr/security.json`. The web container links `solr1` as host `solr`.

Upload the configset with **`ddev solrcollection`** (`.ddev/commands/host/solrcollection`): it enables `search_api_solr_admin`, finds the non-`pantheon` server from `drush sapi-sl`, and runs `drush solr-upload-conf <server> --alias=search`. Run it after creating the `local` server or after `ddev restart`.

## Pantheon deploy

When Pantheon Solr is freshly enabled on a site, push the configset to the cloud server too (the `search_api_pantheon` postUpdate / `drush search-api-pantheon:*` deploy step) before the `global` index will work on Pantheon. Treat as a go-live/deploy action.
