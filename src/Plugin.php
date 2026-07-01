<?php

declare(strict_types=1);

namespace Augustash\ClaudeConfig;

use Composer\Composer;
use Composer\DependencyResolver\Operation\InstallOperation;
use Composer\DependencyResolver\Operation\UninstallOperation;
use Composer\DependencyResolver\Operation\UpdateOperation;
use Composer\EventDispatcher\EventSubscriberInterface;
use Composer\Factory;
use Composer\Installer\PackageEvent;
use Composer\Installer\PackageEvents;
use Composer\IO\IOInterface;
use Composer\Package\PackageInterface;
use Composer\Plugin\PluginInterface;

/**
 * Wires the project's CLAUDE.md / AGENTS.md to the installed package on
 * composer require, and prunes those references on composer remove. Also
 * normalizes the .claude/CLAUDE.md import on each install/update: any
 * @…claude-config/CLAUDE.md line that isn't the canonical ../vendor form is
 * pruned and replaced, so a stale or hand-mangled import (the old
 * ~/claude-config/ clone path, the superseded @vendor/... form, a typo) can't
 * linger stacked beside the correct line. See pruneStaleClaudeImports().
 */
class Plugin implements PluginInterface, EventSubscriberInterface
{
    public const PACKAGE_NAME = 'augustash/claude-config';

    public const CLAUDE_IMPORT_LINE = '@../vendor/augustash/claude-config/CLAUDE.md';
    public const AGENTS_IMPORT_LINE = 'See `vendor/augustash/claude-config/AGENTS.md` for shared augustash team conventions.';

    public const LEGACY_CLAUDE_IMPORT_LINE = '@~/claude-config/CLAUDE.md';
    public const LEGACY_AGENTS_IMPORT_LINE = 'See `~/claude-config/AGENTS.md` for shared augustash team conventions.';

    /**
     * SessionStart hook command: reminds to run the shared-memory audit when
     * memory-audit.md's last_audit date is past its daily floor. The script
     * ships in this package; the command is project-relative via the
     * Claude-Code-provided $CLAUDE_PROJECT_DIR so it resolves from any clone.
     */
    public const AUDIT_HOOK_COMMAND =
        'python3 "$CLAUDE_PROJECT_DIR/vendor/augustash/claude-config/templates/memory-audit-check.py"';

    /**
     * composer.json require names that mark a project as WordPress. Any
     * wpackagist-* dependency counts too (see isWordPress()).
     */
    public const WORDPRESS_CORE_PACKAGES = [
        'johnpbloch/wordpress',
        'johnpbloch/wordpress-core',
        'roots/wordpress',
        'roots/wordpress-no-content',
        'roots/bedrock',
    ];

    /**
     * Comment block preceding the plugin-managed .gitignore entries for the
     * files it writes (CLAUDE.md / AGENTS.md).
     */
    private const MANAGED_FILES_GITIGNORE_COMMENT = [
        '# Managed by augustash/claude-config; safe to remove if you want to commit',
        '# project-specific content in these files instead of .claude/memory/.',
    ];

    /**
     * Comment block preceding the WordPress-only .gitignore entry that keeps
     * this package's own vendor copy out of a committed vendor/ tree.
     */
    private const SELF_GITIGNORE_COMMENT = [
        '# Managed by augustash/claude-config: dev-only tooling installed via',
        '# prefer-source, so its vendor copy carries a nested .git. On WordPress',
        '# projects that commit vendor/, that embedded repo becomes a broken',
        '# gitlink and fails Pantheon builds — ignore it and let composer install',
        '# it locally instead.',
    ];

    private ?IOInterface $io = null;
    private ?Composer $composer = null;

    public function activate(Composer $composer, IOInterface $io): void
    {
        $this->io = $io;
        $this->composer = $composer;
    }

    public function deactivate(Composer $composer, IOInterface $io): void
    {
    }

    public function uninstall(Composer $composer, IOInterface $io): void
    {
    }

    public static function getSubscribedEvents(): array
    {
        return [
            PackageEvents::POST_PACKAGE_INSTALL => 'onPostPackageInstall',
            PackageEvents::POST_PACKAGE_UPDATE => 'onPostPackageUpdate',
            PackageEvents::PRE_PACKAGE_UNINSTALL => 'onPrePackageUninstall',
        ];
    }

    public function onPostPackageInstall(PackageEvent $event): void
    {
        $op = $event->getOperation();
        if (!$op instanceof InstallOperation) {
            return;
        }
        $package = $op->getPackage();
        if ($package->getName() !== self::PACKAGE_NAME) {
            return;
        }
        $installPath = $this->packageInstallPath($package);
        $this->wire($this->projectRoot(), $installPath);
        $this->checkInstallSource($installPath);
    }

    public function onPostPackageUpdate(PackageEvent $event): void
    {
        $op = $event->getOperation();
        if (!$op instanceof UpdateOperation) {
            return;
        }
        $package = $op->getTargetPackage();
        if ($package->getName() !== self::PACKAGE_NAME) {
            return;
        }
        $installPath = $this->packageInstallPath($package);
        $this->wire($this->projectRoot(), $installPath);
        $this->checkInstallSource($installPath);
    }

    public function onPrePackageUninstall(PackageEvent $event): void
    {
        $op = $event->getOperation();
        if (!$op instanceof UninstallOperation) {
            return;
        }
        if ($op->getPackage()->getName() !== self::PACKAGE_NAME) {
            return;
        }
        // A production build (Pantheon's `composer install --no-dev`) uninstalls
        // this require-dev package, which would fire prune() and rewrite the
        // committed .claude/settings.json (stripping the audit hook) — Pantheon
        // then aborts on the unexpected tracked-file change. Unlike the
        // gitignored CLAUDE.md/AGENTS.md outputs, settings.json can hold the
        // project's own hooks/permissions, so it isn't gitignored and must not
        // be touched by a deploy. Only clean up on a genuine dev-mode removal
        // (`composer remove`), never on a no-dev build.
        if (!$event->isDevMode()) {
            return;
        }
        $this->prune($this->projectRoot());
    }

    /**
     * Add the package's import lines to a project root and clear any legacy
     * references left behind by the old global-clone installer.
     */
    public function wire(string $root, string $installPath = ''): void
    {
        $claude = $root . '/.claude/CLAUDE.md';

        // Normalize the .claude/CLAUDE.md import *before* adding the current
        // one, so a file carrying a stale or garbled line is rewritten cleanly
        // rather than left with the old and new lines stacked together. This
        // prunes every @…claude-config/CLAUDE.md variant except the canonical
        // line — the legacy ~/claude-config/ clone path, the superseded
        // @vendor/... form, and any hand-mangled path all collapse to one.
        // Other content in the file is preserved (see pruneStaleClaudeImports).
        if (self::pruneStaleClaudeImports($claude, self::CLAUDE_IMPORT_LINE)) {
            $this->info('normalized stale CLAUDE.md import to ../vendor form');
        }
        // The legacy ~/claude-config/ form is wrong everywhere, so also prune it
        // from a root-level CLAUDE.md. A root-level @vendor/... form, by
        // contrast, is correct (resolved from the project root) and must stay,
        // which is why the pattern prune above is scoped to .claude/ only.
        if (self::pruneImport($root . '/CLAUDE.md', self::LEGACY_CLAUDE_IMPORT_LINE)) {
            $this->info('pruned legacy CLAUDE.md import (' . $root . '/CLAUDE.md)');
        }
        if (self::pruneImport($root . '/AGENTS.md', self::LEGACY_AGENTS_IMPORT_LINE)) {
            $this->info('pruned legacy AGENTS.md pointer');
        }

        if (self::addImport($claude, self::CLAUDE_IMPORT_LINE)) {
            $this->info('added CLAUDE.md import');
        }
        if (self::addImport($root . '/AGENTS.md', self::AGENTS_IMPORT_LINE)) {
            $this->info('added AGENTS.md pointer');
        }
        if (self::ensureGitignore($root, ['/.claude/CLAUDE.md', '/AGENTS.md'])) {
            $this->info('added .gitignore entries for managed files');
        }
        // WordPress projects commit vendor/, so the prefer-source nested .git in
        // this package's own vendor copy would become a broken gitlink and break
        // Pantheon builds. Ignore the whole dir there; composer rebuilds it
        // locally (dev tooling, not needed in the production artifact).
        if ($installPath !== '' && self::isWordPress($root)) {
            $line = self::selfIgnoreLine($root, $installPath);
            if (self::ensureGitignore($root, [$line], self::SELF_GITIGNORE_COMMENT)) {
                $this->info(
                    'added .gitignore entry for the vendor copy (' . $line . ') — '
                    . 'WordPress project keeps the nested repo out of committed vendor/'
                );
            }
        }
        if (self::addAuditHook($root . '/.claude/settings.json')) {
            $this->info('wired memory-audit SessionStart hook into .claude/settings.json');
        }
    }

    /**
     * Print guidance when the package was installed via dist (zip extract)
     * instead of source (git clone). Without prefer-source the vendor copy
     * isn't a git working copy, so in-place memory authoring isn't possible
     * — devs would have to keep a separate clone to commit/push changes.
     */
    public function checkInstallSource(string $installPath): void
    {
        if ($installPath === '' || self::isGitWorkingCopy($installPath)) {
            return;
        }
        if ($this->io === null) {
            return;
        }
        $this->io->write('');
        $this->io->write('  <comment>claude-config:</comment> installed via dist — vendor copy is not a git working copy.');
        $this->io->write('  To author shared memory in place from any project, run:');
        $this->io->write('    <info>composer reinstall augustash/claude-config --prefer-source</info>');
        $this->io->write('  Or set it once globally:');
        $this->io->write('    <info>composer global config preferred-install.augustash/claude-config source</info>');
        $this->io->write('');
    }

    public static function isGitWorkingCopy(string $path): bool
    {
        return $path !== '' && is_dir($path . '/.git');
    }

    /**
     * Remove the package's import lines from a project root.
     */
    public function prune(string $root): void
    {
        if (self::pruneImport($root . '/.claude/CLAUDE.md', self::CLAUDE_IMPORT_LINE)) {
            $this->info('pruned CLAUDE.md import');
        }
        if (self::pruneImport($root . '/AGENTS.md', self::AGENTS_IMPORT_LINE)) {
            $this->info('pruned AGENTS.md pointer');
        }
        if (self::removeAuditHook($root . '/.claude/settings.json')) {
            $this->info('removed memory-audit SessionStart hook from .claude/settings.json');
        }
    }

    /**
     * Add an import line to a file if not already present. Creates the file
     * (and parent directory) when missing; appends with a blank-line separator
     * when the file already has content.
     *
     * @return bool True if the line was added; false if already present.
     */
    public static function addImport(string $file, string $line): bool
    {
        if (is_file($file)) {
            $contents = file_get_contents($file);
            if ($contents !== false && self::containsLine($contents, $line)) {
                return false;
            }
        }
        $dir = dirname($file);
        if (!is_dir($dir)) {
            mkdir($dir, 0777, true);
        }
        if (is_file($file) && filesize($file) > 0) {
            file_put_contents($file, "\n" . $line . "\n", FILE_APPEND);
        } else {
            file_put_contents($file, $line . "\n");
        }
        return true;
    }

    /**
     * Remove an exact import line from a file. Inter-content blank runs are
     * kept; trailing blanks left behind by the removal are dropped. Deletes the
     * file if nothing remains.
     *
     * @return bool True if the file was changed; false otherwise.
     */
    public static function pruneImport(string $file, string $line): bool
    {
        return self::removeLines($file, static fn (string $current): bool => $current === $line);
    }

    /**
     * Normalize the claude-config import in a managed .claude/CLAUDE.md: prune
     * every @…claude-config/CLAUDE.md line except the canonical one, so any
     * stale or hand-mangled variant collapses to a single correct import once
     * wire() re-adds it. Unrelated content (project-specific instructions) is
     * preserved. Scope this to .claude/CLAUDE.md only — a root-level CLAUDE.md
     * legitimately uses the @vendor/... form, which would match the pattern.
     *
     * @param string $canonical The import line to keep untouched.
     * @return bool True if the file was changed; false otherwise.
     */
    public static function pruneStaleClaudeImports(string $file, string $canonical): bool
    {
        return self::removeLines($file, static function (string $current) use ($canonical): bool {
            return $current !== $canonical
                && preg_match('#^@(?:\S*/)?claude-config/CLAUDE\.md$#', $current) === 1;
        });
    }

    /**
     * Remove every line a predicate matches from a file, preserving the rest.
     * Inter-content blank runs are kept; leading and trailing blanks left
     * behind by a removal are dropped (so pruning the first or last line can't
     * strand a blank at the edge of the file). Deletes the file if nothing
     * remains. The file is only rewritten when at least one line is removed, so
     * a no-op call never reformats untouched content.
     *
     * @param callable(string): bool $matches Returns true for lines to drop.
     * @return bool True if the file was changed; false otherwise.
     */
    private static function removeLines(string $file, callable $matches): bool
    {
        if (!is_file($file)) {
            return false;
        }
        $contents = file_get_contents($file);
        if ($contents === false) {
            return false;
        }

        $normalized = preg_replace("/\r\n|\r/", "\n", $contents);
        if (substr($normalized, -1) === "\n") {
            $normalized = substr($normalized, 0, -1);
        }
        $lines = $normalized === '' ? [] : explode("\n", $normalized);

        // Mirror utils.sh: buffer blank runs so blanks stranded after a removed
        // line don't end up trailing the file. Blanks between content are
        // flushed when the next non-blank line appears.
        $out = '';
        $buf = '';
        $removed = false;
        foreach ($lines as $current) {
            if ($matches($current)) {
                $removed = true;
                continue;
            }
            if ($current === '') {
                $buf .= "\n";
            } else {
                $out .= $buf . $current . "\n";
                $buf = '';
            }
        }

        if (!$removed) {
            return false;
        }
        // Drop blanks stranded at the top by removing a leading line; the buffer
        // above already prevents stranded trailing blanks.
        $out = ltrim($out, "\n");
        if ($out === '') {
            unlink($file);
            return true;
        }
        file_put_contents($file, $out);
        return true;
    }

    /**
     * Ensure the project root's .gitignore lists the plugin-managed files.
     *
     * Without this, projects that committed .claude/CLAUDE.md or AGENTS.md
     * before the plugin was added will fail Pantheon-style production builds:
     * `composer install --no-dev` removes this package, the uninstall hook
     * empties or deletes those files, and Pantheon aborts on the unexpected
     * tracked-file modification. Gitignoring them sidesteps the whole class
     * of failure since they are entirely plugin output.
     *
     * @param string[] $lines
     * @param string[]|null $comment Comment lines to head the managed block; defaults
     *   to the managed-files explanation.
     * @return bool True if the file was changed; false if all lines were already present.
     */
    public static function ensureGitignore(string $root, array $lines, ?array $comment = null): bool
    {
        $comment = $comment ?? self::MANAGED_FILES_GITIGNORE_COMMENT;
        $file = $root . '/.gitignore';
        $existing = is_file($file) ? (string) file_get_contents($file) : '';
        $missing = [];
        foreach ($lines as $line) {
            if (!self::containsLine($existing, $line)) {
                $missing[] = $line;
            }
        }
        if ($missing === []) {
            return false;
        }
        $prefix = '';
        if ($existing !== '' && substr($existing, -1) !== "\n") {
            $prefix .= "\n";
        }
        if ($existing !== '') {
            $prefix .= "\n";
        }
        $block = $prefix
            . implode("\n", $comment) . "\n"
            . implode("\n", $missing) . "\n";
        file_put_contents($file, $existing . $block);
        return true;
    }

    /**
     * True when the project root looks like a WordPress install: it requires a
     * known WordPress core package (or any wpackagist-* dependency), or a
     * wp-load.php / wp-settings.php sits at the root or a common web subdir.
     */
    public static function isWordPress(string $root): bool
    {
        $composer = self::readJsonObject($root . '/composer.json');
        if ($composer !== null) {
            $requires = array_merge(
                array_keys((array) ($composer['require'] ?? [])),
                array_keys((array) ($composer['require-dev'] ?? []))
            );
            foreach ($requires as $name) {
                $name = strtolower((string) $name);
                if (in_array($name, self::WORDPRESS_CORE_PACKAGES, true)) {
                    return true;
                }
                if (strncmp($name, 'wpackagist-', 11) === 0) {
                    return true;
                }
            }
        }
        foreach (['', 'web/', 'public/', 'wp/', 'public_html/'] as $sub) {
            if (is_file($root . '/' . $sub . 'wp-load.php')
                || is_file($root . '/' . $sub . 'wp-settings.php')) {
                return true;
            }
        }
        return false;
    }

    /**
     * The .gitignore entry for this package's own vendor copy: the install path
     * made relative to the project root, anchored (leading slash) and marked as
     * a directory (trailing slash). Falls back to the conventional
     * vendor/augustash/claude-config when the install path isn't under the root,
     * so an absolute path is never written into .gitignore.
     */
    public static function selfIgnoreLine(string $root, string $installPath): string
    {
        $prefix = rtrim($root, '/') . '/';
        $installPath = rtrim($installPath, '/');
        if ($installPath !== '' && strncmp($installPath, $prefix, strlen($prefix)) === 0) {
            $rel = substr($installPath, strlen($prefix));
        } else {
            $rel = 'vendor/' . self::PACKAGE_NAME;
        }
        return '/' . trim($rel, '/') . '/';
    }

    /**
     * Idempotently merge the memory-audit SessionStart hook into a project's
     * .claude/settings.json. Preserves all existing hooks and settings; adds
     * the hook only if our exact command isn't already registered. Creates the
     * file (and .claude/) when missing. Leaves malformed JSON untouched rather
     * than risk clobbering hand-edited settings.
     *
     * @return bool True if the file was changed; false if already present or unwritable.
     */
    public static function addAuditHook(string $file): bool
    {
        $settings = self::readJsonObject($file);
        if ($settings === null) {
            // Missing file → start fresh; malformed → bail (don't clobber).
            if (is_file($file)) {
                return false;
            }
            $settings = [];
        }

        $hooks = $settings['hooks'] ?? [];
        $sessionStart = $hooks['SessionStart'] ?? [];

        // Already wired? Scan every matcher group's hook commands for ours.
        foreach ($sessionStart as $group) {
            foreach ($group['hooks'] ?? [] as $hook) {
                if (($hook['command'] ?? null) === self::AUDIT_HOOK_COMMAND) {
                    return false;
                }
            }
        }

        $sessionStart[] = [
            'hooks' => [
                ['type' => 'command', 'command' => self::AUDIT_HOOK_COMMAND],
            ],
        ];
        $hooks['SessionStart'] = $sessionStart;
        $settings['hooks'] = $hooks;

        return self::writeJsonObject($file, $settings);
    }

    /**
     * Remove the memory-audit SessionStart hook from .claude/settings.json,
     * dropping any matcher group left empty by the removal and the SessionStart
     * (or hooks) key if it ends up empty. No-op on missing/malformed files.
     *
     * @return bool True if the file was changed; false otherwise.
     */
    public static function removeAuditHook(string $file): bool
    {
        $settings = self::readJsonObject($file);
        if ($settings === null || !isset($settings['hooks']['SessionStart'])) {
            return false;
        }

        $changed = false;
        $groups = [];
        foreach ($settings['hooks']['SessionStart'] as $group) {
            $kept = [];
            foreach ($group['hooks'] ?? [] as $hook) {
                if (($hook['command'] ?? null) === self::AUDIT_HOOK_COMMAND) {
                    $changed = true;
                    continue;
                }
                $kept[] = $hook;
            }
            if ($kept !== []) {
                $group['hooks'] = $kept;
                $groups[] = $group;
            } elseif (($group['hooks'] ?? []) === []) {
                // Group had no hooks to begin with — leave it as-is.
                $groups[] = $group;
            }
        }

        if (!$changed) {
            return false;
        }

        if ($groups === []) {
            unset($settings['hooks']['SessionStart']);
            if ($settings['hooks'] === []) {
                unset($settings['hooks']);
            }
        } else {
            $settings['hooks']['SessionStart'] = $groups;
        }

        return self::writeJsonObject($file, $settings);
    }

    /**
     * Read a JSON object file into an associative array. Returns null if the
     * file is missing, unreadable, or not a valid JSON object.
     *
     * @return array<string, mixed>|null
     */
    private static function readJsonObject(string $file): ?array
    {
        if (!is_file($file)) {
            return null;
        }
        $contents = file_get_contents($file);
        if ($contents === false || trim($contents) === '') {
            return null;
        }
        $data = json_decode($contents, true);
        return is_array($data) ? $data : null;
    }

    /**
     * Write an associative array as pretty JSON, creating the parent dir when
     * needed. Matches Claude Code's 2-space settings.json style.
     *
     * @param array<string, mixed> $data
     */
    private static function writeJsonObject(string $file, array $data): bool
    {
        $dir = dirname($file);
        if (!is_dir($dir)) {
            mkdir($dir, 0777, true);
        }
        $json = json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
        if ($json === false) {
            return false;
        }
        return file_put_contents($file, $json . "\n") !== false;
    }

    private static function containsLine(string $contents, string $line): bool
    {
        foreach (preg_split("/\r\n|\n|\r/", $contents) as $current) {
            if ($current === $line) {
                return true;
            }
        }
        return false;
    }

    private function projectRoot(): string
    {
        return dirname(Factory::getComposerFile());
    }

    private function packageInstallPath(PackageInterface $package): string
    {
        if ($this->composer === null) {
            return '';
        }
        $path = $this->composer->getInstallationManager()->getInstallPath($package);
        return $path !== null ? (string) $path : '';
    }

    private function info(string $message): void
    {
        if ($this->io !== null) {
            $this->io->write('  <info>claude-config:</info> ' . $message);
        }
    }
}
