<?php

declare(strict_types=1);

namespace Augustash\ClaudeConfig\Tests;

use Augustash\ClaudeConfig\Plugin;
use Composer\DependencyResolver\Operation\UninstallOperation;
use Composer\Installer\PackageEvent;
use Composer\Package\PackageInterface;
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
        unset($_SERVER['COMPOSER']);
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

    public function testWireMigratesSupersededRelativeImport(): void
    {
        // Regression guard for the bug that motivated the ../vendor form:
        // a project wired by an older plugin carries the root-relative
        // @vendor/... line, which Claude Code resolves against .claude/
        // (=> .claude/vendor/..., a silent no-op). wire() must REPLACE it with
        // the ../vendor form — not append a second line beside the dead one.
        // assertSame on the full file content catches both a missed migration
        // and accidental duplication.
        mkdir($this->tmp . '/.claude');
        file_put_contents(
            $this->tmp . '/.claude/CLAUDE.md',
            '@vendor/augustash/claude-config/CLAUDE.md' . "\n"
        );

        (new Plugin())->wire($this->tmp);

        $this->assertSame(
            Plugin::CLAUDE_IMPORT_LINE . "\n",
            file_get_contents($this->tmp . '/.claude/CLAUDE.md')
        );
    }

    public function testWireMigratesSupersededImportPreservingProjectContent(): void
    {
        // The migration must not eat project-specific instructions sharing the
        // file. Prune-then-add should leave the heading + a single blank
        // separator before the corrected import.
        mkdir($this->tmp . '/.claude');
        file_put_contents(
            $this->tmp . '/.claude/CLAUDE.md',
            "# Project notes\n\n" . '@vendor/augustash/claude-config/CLAUDE.md' . "\n"
        );

        (new Plugin())->wire($this->tmp);

        $this->assertSame(
            "# Project notes\n\n" . Plugin::CLAUDE_IMPORT_LINE . "\n",
            file_get_contents($this->tmp . '/.claude/CLAUDE.md')
        );
    }

    public function testWireLeavesRootLevelVendorImportUntouched(): void
    {
        // A root-level CLAUDE.md with @vendor/... is CORRECT (resolved from the
        // project root), so the superseded-form migration must not touch it.
        // wire() still adds its managed .claude/CLAUDE.md alongside.
        file_put_contents(
            $this->tmp . '/CLAUDE.md',
            '@vendor/augustash/claude-config/CLAUDE.md' . "\n"
        );

        (new Plugin())->wire($this->tmp);

        $this->assertSame(
            '@vendor/augustash/claude-config/CLAUDE.md' . "\n",
            file_get_contents($this->tmp . '/CLAUDE.md')
        );
        $this->assertSame(
            Plugin::CLAUDE_IMPORT_LINE . "\n",
            file_get_contents($this->tmp . '/.claude/CLAUDE.md')
        );
    }

    public function testWireNormalizesGarbledImportMissingVendorSegment(): void
    {
        // The case that motivated the pattern prune: a hand-mangled import that
        // matched none of the old hardcoded variants (here, the vendor path
        // segment dropped) used to slip past migration, so wire() appended the
        // correct line beside the dead one. The pattern catches any
        // @…claude-config/CLAUDE.md form, so this collapses to the canonical.
        mkdir($this->tmp . '/.claude');
        file_put_contents(
            $this->tmp . '/.claude/CLAUDE.md',
            "@augustash/claude-config/CLAUDE.md\n"
        );

        (new Plugin())->wire($this->tmp);

        $this->assertSame(
            Plugin::CLAUDE_IMPORT_LINE . "\n",
            file_get_contents($this->tmp . '/.claude/CLAUDE.md')
        );
    }

    public function testWireCollapsesStackedDuplicateImports(): void
    {
        // The exact state a buggy earlier run left behind: the mangled line and
        // the appended-correct line stacked with a blank between. wire() must
        // reduce this to a single clean canonical line — no surviving variant,
        // no stranded leading blank from pruning the first line.
        mkdir($this->tmp . '/.claude');
        file_put_contents(
            $this->tmp . '/.claude/CLAUDE.md',
            "@augustash/claude-config/CLAUDE.md\n\n" . Plugin::CLAUDE_IMPORT_LINE . "\n"
        );

        (new Plugin())->wire($this->tmp);

        $this->assertSame(
            Plugin::CLAUDE_IMPORT_LINE . "\n",
            file_get_contents($this->tmp . '/.claude/CLAUDE.md')
        );
    }

    public function testPruneStaleClaudeImportsKeepsCanonicalAndPreservesContent(): void
    {
        // Unit-level: a non-canonical variant is removed, project content and
        // the already-correct line are both preserved untouched. The canonical
        // line leads here so the dropped trailing variant can't strand a blank
        // and muddy the assertion — the point is which lines survive, not blank
        // bookkeeping (covered by the pruneImport blank tests).
        $file = $this->tmp . '/CLAUDE.md';
        file_put_contents(
            $file,
            Plugin::CLAUDE_IMPORT_LINE . "\n\n# Notes\n\n@vendor/augustash/claude-config/CLAUDE.md\n"
        );

        $this->assertTrue(Plugin::pruneStaleClaudeImports($file, Plugin::CLAUDE_IMPORT_LINE));
        $this->assertSame(
            Plugin::CLAUDE_IMPORT_LINE . "\n\n# Notes\n",
            file_get_contents($file)
        );
    }

    public function testPruneStaleClaudeImportsNoOpWhenOnlyCanonicalPresent(): void
    {
        // No non-canonical variant to prune => no change, file left byte-for-byte
        // (this is what keeps wire() idempotent on an already-correct file).
        $file = $this->tmp . '/CLAUDE.md';
        $original = Plugin::CLAUDE_IMPORT_LINE . "\n";
        file_put_contents($file, $original);

        $this->assertFalse(Plugin::pruneStaleClaudeImports($file, Plugin::CLAUDE_IMPORT_LINE));
        $this->assertSame($original, file_get_contents($file));
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

    public function testIsGitWorkingCopyDetectsGitDir(): void
    {
        $this->assertFalse(Plugin::isGitWorkingCopy($this->tmp));
        mkdir($this->tmp . '/.git');
        $this->assertTrue(Plugin::isGitWorkingCopy($this->tmp));
    }

    public function testIsGitWorkingCopyHandlesEmptyPath(): void
    {
        $this->assertFalse(Plugin::isGitWorkingCopy(''));
    }

    public function testIsGitWorkingCopyFalseWhenGitIsAFile(): void
    {
        // A .git file (not a directory) means a worktree or submodule pointer.
        // For our purposes — authoring memory in place — we want a real
        // working copy with its own .git dir, so a file should be false.
        file_put_contents($this->tmp . '/.git', "gitdir: /elsewhere\n");
        $this->assertFalse(Plugin::isGitWorkingCopy($this->tmp));
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

    public function testAddAuditHookCreatesSettingsWhenMissing(): void
    {
        $file = $this->tmp . '/.claude/settings.json';

        $this->assertTrue(Plugin::addAuditHook($file));

        $settings = json_decode((string) file_get_contents($file), true);
        $command = $settings['hooks']['SessionStart'][0]['hooks'][0]['command'];
        $this->assertSame(Plugin::AUDIT_HOOK_COMMAND, $command);
        $this->assertSame('command', $settings['hooks']['SessionStart'][0]['hooks'][0]['type']);
    }

    public function testAddAuditHookIsIdempotent(): void
    {
        $file = $this->tmp . '/.claude/settings.json';

        $this->assertTrue(Plugin::addAuditHook($file));
        $this->assertFalse(Plugin::addAuditHook($file));

        // Exactly one registration, not stacked duplicates.
        $settings = json_decode((string) file_get_contents($file), true);
        $this->assertCount(1, $settings['hooks']['SessionStart']);
    }

    public function testAddAuditHookPreservesExistingSettingsAndHooks(): void
    {
        $file = $this->tmp . '/.claude/settings.json';
        mkdir($this->tmp . '/.claude');
        file_put_contents($file, json_encode([
            'permissions' => ['allow' => ['Bash(ls:*)']],
            'hooks' => [
                'PreToolUse' => [['matcher' => 'Bash', 'hooks' => [['type' => 'command', 'command' => 'echo hi']]]],
                'SessionStart' => [['hooks' => [['type' => 'command', 'command' => 'other-thing']]]],
            ],
        ]));

        $this->assertTrue(Plugin::addAuditHook($file));

        $settings = json_decode((string) file_get_contents($file), true);
        // Unrelated settings untouched.
        $this->assertSame(['Bash(ls:*)'], $settings['permissions']['allow']);
        $this->assertSame('echo hi', $settings['hooks']['PreToolUse'][0]['hooks'][0]['command']);
        // Existing SessionStart group kept; ours appended.
        $this->assertCount(2, $settings['hooks']['SessionStart']);
        $this->assertSame('other-thing', $settings['hooks']['SessionStart'][0]['hooks'][0]['command']);
        $this->assertSame(Plugin::AUDIT_HOOK_COMMAND, $settings['hooks']['SessionStart'][1]['hooks'][0]['command']);
    }

    public function testAddAuditHookLeavesMalformedJsonUntouched(): void
    {
        $file = $this->tmp . '/.claude/settings.json';
        mkdir($this->tmp . '/.claude');
        file_put_contents($file, "{ not valid json ]");

        $this->assertFalse(Plugin::addAuditHook($file));
        $this->assertSame("{ not valid json ]", file_get_contents($file));
    }

    public function testRemoveAuditHookRoundTripsAddAndDropsEmptyKeys(): void
    {
        $file = $this->tmp . '/.claude/settings.json';

        Plugin::addAuditHook($file);
        $this->assertTrue(Plugin::removeAuditHook($file));

        $settings = json_decode((string) file_get_contents($file), true);
        // Our hook was the only content → hooks key removed entirely, not left empty.
        $this->assertArrayNotHasKey('hooks', $settings);
    }

    public function testRemoveAuditHookPreservesSiblingSessionStartHooks(): void
    {
        $file = $this->tmp . '/.claude/settings.json';
        mkdir($this->tmp . '/.claude');
        file_put_contents($file, json_encode([
            'hooks' => [
                'SessionStart' => [['hooks' => [['type' => 'command', 'command' => 'keep-me']]]],
            ],
        ]));
        Plugin::addAuditHook($file);

        $this->assertTrue(Plugin::removeAuditHook($file));

        $settings = json_decode((string) file_get_contents($file), true);
        $this->assertCount(1, $settings['hooks']['SessionStart']);
        $this->assertSame('keep-me', $settings['hooks']['SessionStart'][0]['hooks'][0]['command']);
    }

    public function testRemoveAuditHookNoOpWhenAbsent(): void
    {
        $file = $this->tmp . '/.claude/settings.json';
        mkdir($this->tmp . '/.claude');
        file_put_contents($file, json_encode(['permissions' => ['allow' => []]]));

        $this->assertFalse(Plugin::removeAuditHook($file));
    }

    public function testEnsureGitignoreCreatesManagedBlock(): void
    {
        $this->assertTrue(Plugin::ensureGitignore($this->tmp, ['/.claude/CLAUDE.md', '/AGENTS.md']));
        $this->assertSame(
            "# Managed by augustash/claude-config; safe to remove if you want to commit\n"
            . "# project-specific content in these files instead of .claude/memory/.\n"
            . "/.claude/CLAUDE.md\n/AGENTS.md\n",
            file_get_contents($this->tmp . '/.gitignore')
        );
    }

    public function testEnsureGitignoreAppendsBlockWithBlankSeparator(): void
    {
        // An existing .gitignore keeps its content; our block is appended after
        // a single blank-line separator. This is the second-call path (e.g. the
        // WordPress self-ignore following the managed-files block).
        file_put_contents($this->tmp . '/.gitignore', "/node_modules\n");

        $this->assertTrue(Plugin::ensureGitignore($this->tmp, ['/vendor/foo/'], ['# custom']));
        $this->assertSame(
            "/node_modules\n\n# custom\n/vendor/foo/\n",
            file_get_contents($this->tmp . '/.gitignore')
        );
    }

    public function testEnsureGitignoreNoOpWhenAllLinesPresent(): void
    {
        Plugin::ensureGitignore($this->tmp, ['/AGENTS.md']);
        $before = file_get_contents($this->tmp . '/.gitignore');

        $this->assertFalse(Plugin::ensureGitignore($this->tmp, ['/AGENTS.md']));
        $this->assertSame($before, file_get_contents($this->tmp . '/.gitignore'));
    }

    public function testIsWordPressDetectsCorePackageInRequire(): void
    {
        file_put_contents(
            $this->tmp . '/composer.json',
            json_encode(['require' => ['php' => '>=8.1', 'johnpbloch/wordpress' => '^6.4']])
        );
        $this->assertTrue(Plugin::isWordPress($this->tmp));
    }

    public function testIsWordPressDetectsWpackagistDependency(): void
    {
        file_put_contents(
            $this->tmp . '/composer.json',
            json_encode(['require' => ['wpackagist-plugin/woocommerce' => '*']])
        );
        $this->assertTrue(Plugin::isWordPress($this->tmp));
    }

    public function testIsWordPressDetectsWpLoadInWebRoot(): void
    {
        // Core managed outside composer (no signal in composer.json), but the
        // WordPress bootstrap sits in a conventional web subdir.
        mkdir($this->tmp . '/web');
        file_put_contents($this->tmp . '/web/wp-load.php', "<?php\n");
        $this->assertTrue(Plugin::isWordPress($this->tmp));
    }

    public function testIsWordPressFalseForDrupalProject(): void
    {
        file_put_contents(
            $this->tmp . '/composer.json',
            json_encode(['require' => ['drupal/core-recommended' => '^10', 'drush/drush' => '^12']])
        );
        $this->assertFalse(Plugin::isWordPress($this->tmp));
    }

    public function testIsWordPressFalseForEmptyProject(): void
    {
        $this->assertFalse(Plugin::isWordPress($this->tmp));
    }

    public function testSelfIgnoreLineIsRootRelativeDirectory(): void
    {
        $this->assertSame(
            '/vendor/augustash/claude-config/',
            Plugin::selfIgnoreLine('/srv/site', '/srv/site/vendor/augustash/claude-config')
        );
    }

    public function testSelfIgnoreLineHonorsCustomVendorLayout(): void
    {
        // Bedrock-style: the package lives under a non-default install path. The
        // ignore entry must track the real location, not a hardcoded vendor/.
        $this->assertSame(
            '/web/app/mu-plugins/claude-config/',
            Plugin::selfIgnoreLine('/srv/site', '/srv/site/web/app/mu-plugins/claude-config')
        );
    }

    public function testSelfIgnoreLineFallsBackWhenInstallPathOutsideRoot(): void
    {
        // Never emit an absolute path into .gitignore; fall back to convention.
        $this->assertSame(
            '/vendor/augustash/claude-config/',
            Plugin::selfIgnoreLine('/srv/site', '/opt/elsewhere/claude-config')
        );
    }

    public function testWireIgnoresVendorCopyOnWordPressProject(): void
    {
        file_put_contents(
            $this->tmp . '/composer.json',
            json_encode(['require' => ['johnpbloch/wordpress' => '^6.4']])
        );
        $installPath = $this->tmp . '/vendor/augustash/claude-config';

        (new Plugin())->wire($this->tmp, $installPath);

        $gitignore = file_get_contents($this->tmp . '/.gitignore');
        $this->assertStringContainsString('/vendor/augustash/claude-config/', $gitignore);
        // The managed-files block is still written alongside the self-ignore.
        $this->assertStringContainsString('/.claude/CLAUDE.md', $gitignore);
    }

    public function testWireDoesNotIgnoreVendorCopyOnNonWordPressProject(): void
    {
        file_put_contents(
            $this->tmp . '/composer.json',
            json_encode(['require' => ['drupal/core-recommended' => '^10']])
        );
        $installPath = $this->tmp . '/vendor/augustash/claude-config';

        (new Plugin())->wire($this->tmp, $installPath);

        $gitignore = file_get_contents($this->tmp . '/.gitignore');
        $this->assertStringNotContainsString('/vendor/augustash/claude-config/', $gitignore);
    }

    public function testWireVendorSelfIgnoreIsIdempotent(): void
    {
        file_put_contents(
            $this->tmp . '/composer.json',
            json_encode(['require' => ['johnpbloch/wordpress' => '^6.4']])
        );
        $installPath = $this->tmp . '/vendor/augustash/claude-config';
        $plugin = new Plugin();

        $plugin->wire($this->tmp, $installPath);
        $first = file_get_contents($this->tmp . '/.gitignore');
        $plugin->wire($this->tmp, $installPath);
        $second = file_get_contents($this->tmp . '/.gitignore');

        $this->assertSame($first, $second);
    }

    public function testWireWithoutInstallPathSkipsVendorSelfIgnore(): void
    {
        // The no-arg wire() path (tests, or any caller lacking the install path)
        // must not attempt a self-ignore even on a WordPress project.
        file_put_contents(
            $this->tmp . '/composer.json',
            json_encode(['require' => ['johnpbloch/wordpress' => '^6.4']])
        );

        (new Plugin())->wire($this->tmp);

        $gitignore = file_get_contents($this->tmp . '/.gitignore');
        $this->assertStringNotContainsString('claude-config/', $gitignore);
    }

    /**
     * Regression: a production build (Pantheon's `composer install --no-dev`)
     * uninstalls this require-dev package. The uninstall handler must NOT prune
     * — pruning rewrites the committed .claude/settings.json (stripping the
     * audit hook), and Pantheon aborts on the tracked-file change.
     */
    public function testPrePackageUninstallSkipsPruneOnNoDevBuild(): void
    {
        $file = $this->wireFakeProject();
        $before = file_get_contents($file);

        (new Plugin())->onPrePackageUninstall($this->uninstallEvent(Plugin::PACKAGE_NAME, false));

        $this->assertSame($before, file_get_contents($file), 'no-dev uninstall must leave settings.json byte-for-byte');
    }

    /**
     * A genuine dev-mode removal (`composer remove augustash/claude-config`)
     * still cleans up the wired hook.
     */
    public function testPrePackageUninstallPrunesOnDevRemoval(): void
    {
        $file = $this->wireFakeProject();

        (new Plugin())->onPrePackageUninstall($this->uninstallEvent(Plugin::PACKAGE_NAME, true));

        $this->assertStringNotContainsString(Plugin::AUDIT_HOOK_COMMAND, (string) file_get_contents($file));
    }

    /**
     * Build a fake project root under tmp with a composer.json and a wired
     * settings.json, and point the plugin's projectRoot() resolution at it via
     * the COMPOSER env override Composer's Factory honors.
     *
     * @return string Path to the wired .claude/settings.json.
     */
    private function wireFakeProject(): string
    {
        file_put_contents($this->tmp . '/composer.json', '{}');
        $_SERVER['COMPOSER'] = $this->tmp . '/composer.json';
        $file = $this->tmp . '/.claude/settings.json';
        Plugin::addAuditHook($file);
        return $file;
    }

    private function uninstallEvent(string $packageName, bool $devMode): PackageEvent
    {
        $package = $this->createMock(PackageInterface::class);
        $package->method('getName')->willReturn($packageName);

        $event = $this->createMock(PackageEvent::class);
        $event->method('getOperation')->willReturn(new UninstallOperation($package));
        $event->method('isDevMode')->willReturn($devMode);
        return $event;
    }
}
