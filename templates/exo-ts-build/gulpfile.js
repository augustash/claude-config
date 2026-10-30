// Mirrors exo's gulpfile ts task (tsPackage + tsCompile) for one module,
// without the drupal/exo bootstrap steps. Run from the exo clone root;
// EXO_MODULE picks the module (default exo_modal).
const cwd = process.cwd();
const r = m => require(require.resolve(m, { paths: [cwd] }));
const gulp = r('gulp');
const { series } = gulp;
const plumber = r('gulp-plumber');
const rename = r('gulp-rename');
const uglify = r('gulp-uglify');
const typescript = r('gulp-typescript');
const fileinclude = r('gulp-file-include');
const babel = r('gulp-babel');
const clean = r('gulp-clean');
const tsProject = typescript.createProject(cwd + '/tsconfig.json');

const mod = process.env.EXO_MODULE || 'exo_modal';

function tsPackage() {
  return gulp.src([mod + '/src/ts/*.ts'], { base: '.' })
    .pipe(plumber())
    .pipe(fileinclude({ prefix: 'TS', basepath: '@file' }))
    .pipe(rename(p => { p.dirname = p.dirname.replace('/src/ts', '/tmp'); }))
    .pipe(plumber.stop())
    .pipe(gulp.dest('.'));
}

function tsCompile() {
  return gulp.src([mod + '/tmp/*.ts'], { base: '.' })
    .pipe(plumber(() => {}))
    .pipe(tsProject(typescript.reporter.nullReporter()))
    .pipe(babel({ presets: [require.resolve('@babel/preset-env', { paths: [cwd] })] }))
    .pipe(uglify())
    .pipe(rename(p => { p.dirname = p.dirname.replace('/tmp', '/js'); }))
    .pipe(plumber.stop())
    .pipe(gulp.dest('.'));
}

function tsClean() {
  return gulp.src(mod + '/tmp', { read: false, allowEmpty: true }).pipe(clean());
}

exports.default = series(tsPackage, tsCompile, tsClean);
