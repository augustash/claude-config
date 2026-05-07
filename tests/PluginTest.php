<?php

declare(strict_types=1);

namespace Augustash\ClaudeConfig\Tests;

use Augustash\ClaudeConfig\Plugin;
use PHPUnit\Framework\TestCase;

class PluginTest extends TestCase
{
    private string $tmp;

    protected function setUp(): void
    {
        $this->tmp = sys_get_temp_dir() . '/claude-config-' . bin2hex(random_bytes(6));
        mkdir($this->tmp, 0777, true);
    }

    protected function tearDown(): void
    {
        $this->rrmdir($this->tmp);
    }

    private function rrmdir(string $dir): void
    {
        if (!is_dir($dir)) return;
        foreach (scandir($dir) as $entry) {
            if ($entry === '.' || $entry === '..') continue;
            $path = $dir . '/' . $entry;
            is_dir($path) ? $this->rrmdir($path) : unlink($path);
        }
        rmdir($dir);
    }

    public function testAddImportCreatesFileWhenMissing(): void
    {
        $file = $this->tmp . '/nested/CLAUDE.md';
        $line = '@vendor/foo/bar.md';

        $this->assertTrue(Plugin::addImport($file, $line));
        $this->assertSame($line . "\n", file_get_contents($file));
    }

    public function testAddImportAppendsWithBlankSeparatorWhenFileHasContent(): void
    {
        $file = $this->tmp . '/AGENTS.md';
        file_put_contents($file, "# Existing\n\nSome content.\n");
        $line = 'See `vendor/foo/bar.md` for stuff.';

        $this->assertTrue(Plugin::addImport($file, $line));
        $this->assertSame("# Existing\n\nSome content.\n\n" . $line . "\n", file_get_contents($file));
    }

    public function testAddImportNoOpWhenLineAlreadyPresent(): void
    {
        $file = $this->tmp . '/AGENTS.md';
        $line = 'See `vendor/foo/bar.md` for stuff.';
        file_put_contents($file, "preamble\n\n" . $line . "\n");

        $this->assertFalse(Plugin::addImport($file, $line));
        $this->assertSame("preamble\n\n" . $line . "\n", file_get_contents($file));
    }

    public function testPruneImportDeletesFileWhenLineWasOnlyContent(): void
    {
        $file = $this->tmp . '/CLAUDE.md';
        $line = '@vendor/foo/bar.md';
        file_put_contents($file, $line . "\n");

        $this->assertTrue(Plugin::pruneImport($file, $line));
        $this->assertFileDoesNotExist($file);
    }

    public function testPruneImportPreservesOtherContentAndDropsTrailingBlanks(): void
    {
        $file = $this->tmp . '/CLAUDE.md';
        $line = '@vendor/foo/bar.md';
        file_put_contents($file, "# Heading\n\n" . $line . "\n");

        $this->assertTrue(Plugin::pruneImport($file, $line));
        $this->assertSame("# Heading\n", file_get_contents($file));
    }

    public function testPruneImportPreservesInterContentBlanks(): void
    {
        $file = $this->tmp . '/CLAUDE.md';
        $line = '@vendor/foo/bar.md';
        // Blanks bracketing the import are preserved literally (matches the
        // shell predecessor's behavior). Only trailing blanks get dropped.
        file_put_contents($file, "before\n\n" . $line . "\n\nafter\n");

        $this->assertTrue(Plugin::pruneImport($file, $line));
        $this->assertSame("before\n\n\nafter\n", file_get_contents($file));
    }

    public function testPruneImportRoundTripsAddImportOnFileWithContent(): void
    {
        // The round-trip we actually care about: addImport appends with a
        // single blank separator; pruneImport must restore the original.
        $file = $this->tmp . '/CLAUDE.md';
        $line = '@vendor/foo/bar.md';
        $original = "# Heading\n\nbody\n";
        file_put_contents($file, $original);

        $this->assertTrue(Plugin::addImport($file, $line));
        $this->assertTrue(Plugin::pruneImport($file, $line));
        $this->assertSame($original, file_get_contents($file));
    }

    public function testPruneImportNoOpWhenLineAbsent(): void
    {
        $file = $this->tmp . '/CLAUDE.md';
        $original = "# Heading\n\nbody\n";
        file_put_contents($file, $original);

        $this->assertFalse(Plugin::pruneImport($file, '@vendor/foo/bar.md'));
        $this->assertSame($original, file_get_contents($file));
    }

    public function testPruneImportNoOpWhenFileMissing(): void
    {
        $this->assertFalse(Plugin::pruneImport($this->tmp . '/nope.md', '@vendor/foo/bar.md'));
    }

    public function testWireAddsBothImportsAndPrunesLegacy(): void
    {
        // Pre-seed legacy references like a project wired by the old installer.
        file_put_contents(
            $this->tmp . '/AGENTS.md',
            "# AGENTS\n\n" . Plugin::LEGACY_AGENTS_IMPORT_LINE . "\n"
        );
        mkdir($this->tmp . '/.claude');
        file_put_contents(
            $this->tmp . '/.claude/CLAUDE.md',
            Plugin::LEGACY_CLAUDE_IMPORT_LINE . "\n"
        );

        (new Plugin())->wire($this->tmp);

        $claude = file_get_contents($this->tmp . '/.claude/CLAUDE.md');
        $agents = file_get_contents($this->tmp . '/AGENTS.md');

        $this->assertStringContainsString(Plugin::CLAUDE_IMPORT_LINE, $claude);
        $this->assertStringNotContainsString(Plugin::LEGACY_CLAUDE_IMPORT_LINE, $claude);

        $this->assertStringContainsString(Plugin::AGENTS_IMPORT_LINE, $agents);
        $this->assertStringNotContainsString(Plugin::LEGACY_AGENTS_IMPORT_LINE, $agents);
    }

    public function testWireOnEmptyProjectCreatesBothFiles(): void
    {
        (new Plugin())->wire($this->tmp);

        $this->assertFileExists($this->tmp . '/.claude/CLAUDE.md');
        $this->assertFileExists($this->tmp . '/AGENTS.md');
        $this->assertSame(
            Plugin::CLAUDE_IMPORT_LINE . "\n",
            file_get_contents($this->tmp . '/.claude/CLAUDE.md')
        );
        $this->assertSame(
            Plugin::AGENTS_IMPORT_LINE . "\n",
            file_get_contents($this->tmp . '/AGENTS.md')
        );
    }

    public function testWireIsIdempotent(): void
    {
        $plugin = new Plugin();
        $plugin->wire($this->tmp);
        $first = [
            file_get_contents($this->tmp . '/.claude/CLAUDE.md'),
            file_get_contents($this->tmp . '/AGENTS.md'),
        ];
        $plugin->wire($this->tmp);
        $second = [
            file_get_contents($this->tmp . '/.claude/CLAUDE.md'),
            file_get_contents($this->tmp . '/AGENTS.md'),
        ];

        $this->assertSame($first, $second);
    }

    public function testPruneRemovesOwnImportsLeavingOtherContentIntact(): void
    {
        mkdir($this->tmp . '/.claude');
        file_put_contents(
            $this->tmp . '/.claude/CLAUDE.md',
            "# Project notes\n\n" . Plugin::CLAUDE_IMPORT_LINE . "\n"
        );
        file_put_contents(
            $this->tmp . '/AGENTS.md',
            "# AGENTS\n\nProject specifics.\n\n" . Plugin::AGENTS_IMPORT_LINE . "\n"
        );

        (new Plugin())->prune($this->tmp);

        $this->assertSame("# Project notes\n", file_get_contents($this->tmp . '/.claude/CLAUDE.md'));
        $this->assertSame("# AGENTS\n\nProject specifics.\n", file_get_contents($this->tmp . '/AGENTS.md'));
    }

    public function testPruneDeletesFilesIfImportWasOnlyContent(): void
    {
        mkdir($this->tmp . '/.claude');
        file_put_contents(
            $this->tmp . '/.claude/CLAUDE.md',
            Plugin::CLAUDE_IMPORT_LINE . "\n"
        );
        file_put_contents(
            $this->tmp . '/AGENTS.md',
            Plugin::AGENTS_IMPORT_LINE . "\n"
        );

        (new Plugin())->prune($this->tmp);

        $this->assertFileDoesNotExist($this->tmp . '/.claude/CLAUDE.md');
        $this->assertFileDoesNotExist($this->tmp . '/AGENTS.md');
    }
}
