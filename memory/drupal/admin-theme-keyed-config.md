---
name: Changing the admin theme orphans config keyed to the old theme by name
description: after a Seven→Claro switch the admin UI looks wrong — forms sprawl over two rows, sidebar panels render unstyled — because exo_form.settings and real_favicon.settings key their settings by theme name and the new theme simply isn't listed
metadata:
  type: reference
---

# Changing the admin theme orphans config keyed to the old theme by name

Presents as **"the new admin theme looks wrong"** — exposed filters that used to sit
on one row wrap onto two, labels move from inside the field to above it, sidebar
panels lose their headers, favicons disappear. The natural read is "Claro is just
roomier than Seven, we need to restyle it," and that sends you writing CSS for a
problem that is one config key.

Several modules store per-theme settings in a map keyed by **theme machine name**.
Switch the admin theme and those entries don't follow — the old key sits there
inert and the new theme gets nothing. Nothing warns you; `config:status` is clean,
because the config is exactly as exported.

Confirmed cases:

```yaml
# exo_form.settings.yml — the big one; carries admin form layout wholesale
themes:
  ash: {  }
  seven: { exo_default: 0, style: intersect, wrap: 1 }

# real_favicon.settings.yml — admin favicons
themes: { aeon: sisal, ash: sisal, bartik: sisal, seven: sisal }
```

**Find them all in one grep** before touching any CSS:

```
grep -rn '\bseven\b' config/ | grep -viE 'seven_|\.seven|dependencies'
```

Copy the old theme's entry to the new key. On sisal, adding `claro` to
`exo_form.settings.themes` alone restored the single-row filter layout, floating
labels, table metrics, spacing and colours — table `th`/`td` then matched Seven on
every measured property. Set the values with the right **types**: `drush cset`
writes `'0'`/`'1'` as strings where the existing entries are ints, so use
`drush ev` with a real array if the module compares strictly.

## What config can't recover

eXo deliberately withholds some treatments from Claro, because Claro styles those
elements itself:

```css
.exo-body:not(.theme-claro) … .entity-meta > details { … }
```

Commerce renders order-sidebar panels as bare `<details>`/`<summary>` with no Claro
classes, so under Claro *nothing* styles them and they read as unstyled beside
everything else. That part needs site CSS re-asserting the values — measure them
off the old theme rather than eyeballing, and scope to `.theme-claro` (the class
sits on `div#exo-body`).

Note this is Drupal-wide, not eXo-specific: any module with a `themes:` map has the
same failure mode. Worth checking on every D10→D11 upgrade, since [Seven is removed
from core in 11.0](d11-symfony-runtime.md) and every eXo site must move off it.
