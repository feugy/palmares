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
const fs = require('fs-extra')
const gulp = require('gulp')
const gutil = require('gulp-util')
const mocha = require('gulp-spawn-mocha')
const coffee = require('gulp-coffee')
const stylus = require('gulp-stylus')
const manifest = require('./package.json')
const async = require('async')

const paths = {
  dest: 'lib',
  vendors: 'vendor/**/*',
  scripts: 'src/**/*.coffee',
  tests: 'test/**/*.coffee',
  styles: 'style/**/*.styl',
  stylesBuilt: ['style/**/*.styl', '!style/constants.styl'],
  buildFile: 'build.asar'
}

const platforms = ['osx64']

const buildScripts = () =>
  gulp.src(paths.scripts)
    .pipe(coffee({bare: true}))
    .on('end', () =>
      console.log('scripts rebuilt')
    ).on('error', err => {
      gutil.beep()
      gutil.log(`${err.filename}: ${err.message}\n${err.location}`)
    }).pipe(gulp.dest(paths.dest))

const buildStyles = () =>
  gulp.src(paths.stylesBuilt)
    .pipe(stylus())
    .on('end', () =>
      console.log('styles rebuilt')
    ).on('error', err => {
      gutil.beep()
      gutil.log(`${err.filename}: ${err.message}\n${err.location}`)
    }).pipe(gulp.dest(paths.dest))

gulp.task('clean', done =>
  async.each([paths.dest, 'build', 'cache'], fs.remove, done)
)

// cleans destination folder and copy vendor libs into it
gulp.task('vendor', ['clean'], () =>
  gulp.src(paths.vendors).pipe(gulp.dest(paths.dest))
)

// compiles coffee scripts
gulp.task('build-scripts', buildScripts)

// compiles stylus scripts
gulp.task('build-styles', buildStyles)

// build everything
gulp.task('build', ['vendor'], done => {
  buildStyles().on('finish', () =>
    buildScripts().on('finish', done)
  )
})

// watch and rebuild
gulp.task('watch', ['build'], () => {
  gulp.watch(paths.scripts, buildScripts)
  return gulp.watch(paths.styles, buildStyles)
})
gulp.task('default', ['watch'])

// run mocha's test
gulp.task('test', () =>
  gulp.src(paths.tests, {read: false}).pipe(mocha({
    env: {
      NODE_ENV: 'test'
    },
    reporter: 'spec',
    compilers: 'coffee:coffee-script/register'
  }))
)
