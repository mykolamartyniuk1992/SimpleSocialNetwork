const gulp = require('gulp');
const inject = require('gulp-inject');
const path = require('path');
const config = require('./vendor.config.json');

// Copy npm packages
gulp.task('copy-npm', function () {
    return gulp.src([
        'node_modules/@microsoft/signalr/**/*.js',
        'node_modules/bootstrap/dist/**/*',
        'node_modules/jquery/dist/**/*',
        'node_modules/jquery-ui/**/*',
        'node_modules/moment/**/*'
    ], { base: 'node_modules' })
        .pipe(gulp.dest('wwwroot/lib'));
});

// Copy js folder
gulp.task('copy-js', function () {
    return gulp.src('js/**/*')
        .pipe(gulp.dest('wwwroot/js'));
});

// Copy css folder
gulp.task('copy-css', function () {
    return gulp.src('css/**/*')
        .pipe(gulp.dest('wwwroot/css'));
});

// Copy html files to wwwroot root
gulp.task('copy-html', function () {
    return gulp.src('html/**/*.html')
        .pipe(gulp.dest('wwwroot'));
});

gulp.task('inject-vendor', function () {
    const vendorScripts = gulp.src(config.common.scripts.map(f => `node_modules/${f}`), { read: false });
    const vendorStyles = gulp.src(config.common.styles.map(f => `node_modules/${f}`), { read: false });

    return gulp.src('html/**/*.html')
        .pipe(inject(vendorScripts, {
            starttag: '<!-- inject:vendor:js -->',
            endtag: '<!-- endinject -->',
            transform: function (filepath, file, i, length, targetFile) {
                const htmlName = path.basename(targetFile.path).toLowerCase();
                const pageCfg = config.pages[htmlName] || {};
                const pageScripts = Array.isArray(pageCfg.scripts) ? pageCfg.scripts : [];

                if (i === 0) {
                    console.log('\x1b[36m%s\x1b[0m', `Inject JS -> ${htmlName}`);
                    return [...config.common.scripts, ...pageScripts]
                        .map(f => `<script src="lib/${f}"></script>`)
                        .join('\n    ');
                }
                return ''; // остальные вызовы игнорируем, чтобы не плодить дубли
            }
        }))
        .pipe(inject(vendorStyles, {
            starttag: '<!-- inject:vendor:css -->',
            endtag: '<!-- endinject -->',
            transform: function (filepath, file, i, length, targetFile) {
                const htmlName = path.basename(targetFile.path).toLowerCase();
                const pageCfg = config.pages[htmlName] || {};
                const pageStyles = Array.isArray(pageCfg.styles) ? pageCfg.styles : [];

                if (i === 0) {
                    console.log('\x1b[36m%s\x1b[0m', `Inject CSS -> ${htmlName}`);
                    return [...config.common.styles, ...pageStyles]
                        .map(f => `<link href="lib/${f}" rel="stylesheet">`)
                        .join('\n    ');
                }
                return '';
            }
        }))
        .pipe(gulp.dest('wwwroot'));
});

// Default task
gulp.task('default', gulp.series(
    gulp.parallel('copy-npm', 'copy-js', 'copy-css', 'copy-html'),
    'inject-vendor'
));