---
name: A subscriber naming a contrib class in getSubscribedEvents deadlocks deploy
description: Referencing a contrib class in a custom module's getSubscribedEvents() makes the container unbuildable wherever that module isn't installed yet — which is every deploy that lands code ahead of its config import.
metadata:
  type: reference
---

# A subscriber naming a contrib class in getSubscribedEvents deadlocks deploy

Symptom: right after a deploy, **every** drush command on the environment dies with

```
Error: Class "Drupal\some_contrib\Event\SomeEvents" not found in
Drupal\our_module\EventSubscriber\OurSubscriber::getSubscribedEvents()
```

including the `config:import` you were about to run. The class file is plainly
on disk — the code deployed fine.

## Why

`getSubscribedEvents()` is static and runs while the **container compiles**
(`RegisterEventSubscribersPass`). Drupal registers a module's PSR-4 namespace
with the autoloader only for modules that are **installed**. So on any
environment holding the code without the module installed, that class cannot
resolve, the container cannot build, and nothing boots.

On Pantheon (and any deploy that separates code from config) that state is not
an edge case — it is *every* deploy of a new module: code lands first, `cim`
installs it afterward. Which is what makes this a **deadlock** rather than an
error you fix by running the next command: the only thing that would install
the module is the import, and the import can't boot either.

Recovering means deploying different code. There is no drush route out.

## The fix — the event name is a string

Only the array `getSubscribedEvents()` returns is evaluated at compile time.
Spell the event out and nothing needs autoloading:

```php
public static function getSubscribedEvents(): array {
  // Not SomeEvents::THING — this runs at container compile, before the module
  // providing that class is necessarily installed.
  return ['some_contrib.the_thing' => 'onThing'];
}
```

Everything below that line is safe to type normally. PHP resolves parameter
types and method bodies **on call**, and the only caller is the event itself —
which can only fire if the module dispatching it is installed. So
`onThing(SomeContribEvent $event)` and any `instanceof` inside it are fine.

Also declare the dependency in `.info.yml`. That is the honest statement and it
stops the module being uninstalled out from under you, but it does **not** fix
this: dependencies are enforced at install time, so adding one to an
already-installed module changes nothing about the current deploy.

## Where it does not apply

Plugin classes extending a contrib base are fine. Annotation/attribute
discovery uses static parsing and never autoloads the class, so the parent only
resolves when the plugin is actually instantiated — which requires config that
names it, i.e. after the import. Confirmed on sisal 2026-09-09: a payment
gateway plugin subclassing `commerce_stripe` deployed cleanly in the same
commit whose subscriber took the site down.

Related: [[pantheon-build-lag]] for the other way a deploy reports success
against code that isn't live yet.
