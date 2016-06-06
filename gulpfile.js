/*
Equivalent to makefile, with gulp.
The only requirement is to have gulp globally installed `npm install -g gulp`,
and to have retrieved the npm dependencies with `npm install`

Available tasks:
  clean - removed compiled folders
  build - compiles coffee-script, stylus, copy assets
  start - launch application
  test  - launch unit tests
  watch (default) - clean, build, and use watcher to recompile on the fly when sources or scripts file changes
*/
var fs = require('fs-extra');
var gulp = require('gulp');
var gutil = require('gulp-util');
var mocha = require('gulp-spawn-mocha');
var coffee = require('gulp-coffee');
var stylus = require('gulp-stylus');
var NwBuilder = require('nw-builder');
var manifest = require('./package.json');
var async = require('async');

var paths = {
  dest: 'lib',
  vendors: 'vendor/**/*',
  scripts: 'src/**/*.coffee',
  tests: 'test/**/*.coffee',
  styles: 'style/**/*.styl',
  stylesBuilt: ['style/**/*.styl', '!style/constants.styl']
};

var platforms = ['osx64'];

gulp.task('clean', function(done) {
  async.each([paths.dest, 'build', 'cache'], fs.remove, done);
});

// cleans destination folder and copy vendor libs into it
gulp.task('vendor', ['clean'], function() {
  return gulp.src(paths.vendors).pipe(gulp.dest(paths.dest));
});

// compiles coffee scripts
gulp.task('build-scripts', buildScripts);

function buildScripts() {
  return gulp.src(paths.scripts)
    .pipe(coffee({bare: true}))
    .on('end', function() {
      console.log('scripts rebuilt');
    }).on('error', function(err) {
      gutil.beep();
      gutil.log(err.filename + ' : ' + err.message + '\n' + err.location);
    }).pipe(gulp.dest(paths.dest));
};

// compiles stylus scripts
gulp.task('build-styles', buildStyles);

function buildStyles() {
  return gulp.src(paths.stylesBuilt)
    .pipe(stylus())
    .on('end', function() {
      console.log('styles rebuilt');
    }).on('error', function(err) {
      gutil.beep();
      gutil.log(err.filename + ' : ' + err.message + '\n' + err.location);
    }).pipe(gulp.dest(paths.dest));
};

// build everything
gulp.task('build', ['vendor'], function() {
  return buildStyles().on('finish', buildScripts);
});

// watch and rebuild
gulp.task('watch', ['build'], function() {
  gulp.watch(paths.scripts, buildScripts);
  return gulp.watch(paths.styles, buildStyles);
});
gulp.task('default', ['watch']);

// run mocha's test
gulp.task('test', function() {
  return gulp.src(paths.tests, {read: false}).pipe(mocha({
    env: {
      NODE_ENV: 'test'
    },
    reporter: 'spec',
    compilers: 'coffee:coffee-script/register'
  }));
});

// Make distribution packages
gulp.task('dist', ['build'], function(done) {
  var options = {
    files: ['./package.json',
      './index.html',
      './README.md',
      './nls/**',
      './template/**',
      './style/**',
      './' + paths.dest + '/**',
      './node_modules/async',
      './node_modules/cheerio',
      './node_modules/csv',
      './node_modules/fs-extra',
      './node_modules/hogan.js',
      './node_modules/async',
      './node_modules/js-yaml',
      './node_modules/md5',
      './node_modules/moment',
      './node_modules/request',
      './node_modules/underscore',
      './node_modules/underscore.string',
      './node_modules/xlsx.js'],
    version: '0.10.5',
    platforms: platforms,
    macIcns: 'style/ribas-icon.icns',
    winIco: 'style/ribas-icon.ico',
    platformOverrides: {
      osx: {
        toolbar: true
      }
    }
  };
  for (var package in manifest.devDependencies) {
    options.files.push('!./node_modules/' + package + '/**');
  }

  var nw = new NwBuilder(options);
  nw.on('log', gutil.log.bind(gutil)).build(done);
});