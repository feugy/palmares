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

var paths = {
  dest: 'lib',
  vendors: 'vendor/**/*',
  scripts: 'src/**/*.coffee',
  tests: 'test/**/*.coffee',
  styles: 'style/**/*.styl',
  stylesBuilt: ['style/**/*.styl', '!style/constants.styl']
};

gulp.task('clean', function(done) { 
  fs.remove(paths.dest, done);
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