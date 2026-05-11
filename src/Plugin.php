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
 * migrates legacy ~/claude-config/ references from the previous global-clone
 * layout the first time the package is installed.
 */
class Plugin implements PluginInterface, EventSubscriberInterface
{
    public const PACKAGE_NAME = 'augustash/claude-config';

    public const CLAUDE_IMPORT_LINE = '@vendor/augustash/claude-config/CLAUDE.md';
    public const AGENTS_IMPORT_LINE = 'See `vendor/augustash/claude-config/AGENTS.md` for shared augustash team conventions.';

    public const LEGACY_CLAUDE_IMPORT_LINE = '@~/claude-config/CLAUDE.md';
    public const LEGACY_AGENTS_IMPORT_LINE = 'See `~/claude-config/AGENTS.md` for shared augustash team conventions.';

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
        $this->wire($this->projectRoot());
        $this->checkInstallSource($this->packageInstallPath($package));
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
        $this->wire($this->projectRoot());
        $this->checkInstallSource($this->packageInstallPath($package));
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
        $this->prune($this->projectRoot());
    }

    /**
     * Add the package's import lines to a project root and clear any legacy
     * references left behind by the old global-clone installer.
     */
    public function wire(string $root): void
    {
        if (self::addImport($root . '/.claude/CLAUDE.md', self::CLAUDE_IMPORT_LINE)) {
            $this->info('added CLAUDE.md import');
        }
        if (self::addImport($root . '/AGENTS.md', self::AGENTS_IMPORT_LINE)) {
            $this->info('added AGENTS.md pointer');
        }
        if (self::ensureGitignore($root, ['/.claude/CLAUDE.md', '/AGENTS.md'])) {
            $this->info('added .gitignore entries for managed files');
        }

        // One-time migration: prune legacy ~/claude-config/ references.
        foreach ([$root . '/.claude/CLAUDE.md', $root . '/CLAUDE.md'] as $candidate) {
            if (self::pruneImport($candidate, self::LEGACY_CLAUDE_IMPORT_LINE)) {
                $this->info('pruned legacy CLAUDE.md import (' . $candidate . ')');
            }
        }
        if (self::pruneImport($root . '/AGENTS.md', self::LEGACY_AGENTS_IMPORT_LINE)) {
            $this->info('pruned legacy AGENTS.md pointer');
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
     * Remove an import line from a file. Inter-content blank runs are kept;
     * trailing blanks left behind by the removal are dropped. Deletes the
     * file if nothing remains.
     *
     * @return bool True if the file was changed; false otherwise.
     */
    public static function pruneImport(string $file, string $line): bool
    {
        if (!is_file($file)) {
            return false;
        }
        $contents = file_get_contents($file);
        if ($contents === false || !self::containsLine($contents, $line)) {
            return false;
        }

        $normalized = preg_replace("/\r\n|\r/", "\n", $contents);
        if (substr($normalized, -1) === "\n") {
            $normalized = substr($normalized, 0, -1);
        }
        $lines = $normalized === '' ? [] : explode("\n", $normalized);

        // Mirror utils.sh: buffer blank runs so blanks stranded after the
        // removed line don't end up trailing the file. Blanks between content
        // are flushed when the next non-blank line appears.
        $out = '';
        $buf = '';
        foreach ($lines as $current) {
            if ($current === $line) {
                continue;
            }
            if ($current === '') {
                $buf .= "\n";
            } else {
                $out .= $buf . $current . "\n";
                $buf = '';
            }
        }

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
     * @return bool True if the file was changed; false if all lines were already present.
     */
    public static function ensureGitignore(string $root, array $lines): bool
    {
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
            . "# Managed by augustash/claude-config; safe to remove if you want to commit\n"
            . "# project-specific content in these files instead of .claude/memory/.\n"
            . implode("\n", $missing) . "\n";
        file_put_contents($file, $existing . $block);
        return true;
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
