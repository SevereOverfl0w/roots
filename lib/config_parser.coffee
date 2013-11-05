require('colors')
fs = require 'fs'
path = require 'path'
shell = require 'shelljs'
coffee = require 'coffee-script'
roots = require './index'
_ = require 'underscore'

# config parser
# -----------------
# Parses the app.coffee file in a roots project,
# adds and configures any additional options, and puts all
# config options inside `roots.project`

class ConfigLoader

  constructor: (@args, @done) ->
    @proj = roots.project
    @path = path.join(@proj.rootDir + '/app.coffee')

  init: ->
    @load_file()
    @configure_compilers()
    @configure_directories()
    @configure_locals()
    @configure_extensions()
    @configure_ignores()
    @configure_templates()

    @proj.debug = @config.debug || @args.debug
    roots.print.debug 'config options set!'

    @done()

  load_file: ->
    contents = if fs.existsSync(@path) then fs.readFileSync(@path, 'utf8') else '{}'

    if contents.match /exports\./
      console.warn """
      You are using a depracated format for your app.coffee file.
      Please see the documentation for app.coffee formatting at
      http://roots.cx/docs/xxx
      """.yellow
      @config = require(@path);
    else
      @config = eval(coffee.compile(contents, { bare: true }))  

  configure_compilers: ->
    configurable_compilers = ['stylus', 'coffeescript']

    for cmp in configurable_compilers
      @proj.compiler_options[cmp] = @config[cmp] if @config[cmp]

    # (deprecated) coffeescript bare option
    if @config.coffeescript_bare
      @proj.compiler_options.coffeescript.bare = @config.coffeescript_bare

  configure_directories: ->
    @proj.dirs['views'] = @config.views_folder || 'views'
    @proj.dirs['assets'] = @config.assets_folder || 'assets'
    @proj.dirs['public'] = @config.output_folder || 'public'

  configure_locals: ->
    @config.locals ||= {}

    # view helper bundles
    view_helpers = @config.view_helpers || ['collection', 'str', 'date', '_']
    for helper in view_helpers
      hpath = path.join(__dirname, 'view_helpers', helper)
      @proj.locals[helper] = require(hpath)

    # (deprecated) direct-attached sort helper
    @proj.locals.sort = @proj.locals.collection.sort

    # load custom locals & layouts
    _.extend(@proj.locals, @config.locals)
    _.extend(@proj.layouts, @config.layouts)

  configure_extensions: ->
    @proj.extensions ||= []

    for name, adapter of require('./adapters')
      @proj.extensions.push(adapter.settings.file_type)

  configure_ignores: ->
    # cover the bases
    @config.ignore_files ||= []
    @config.ignore_folders ||= []
    @config.watcher_ignore_folders ||= []
    @config.watcher_ignore_files ||= []
    @config.layouts ||= {}

    # ignore all layout files
    @config.ignore_files.push(v) for k,v of @config.layouts

    # always ignore app.coffee
    @config.ignore_files.push('app.coffee')

    # add plugins, and public folders to the folder ignores
    @config.ignore_folders = _.union(
      @config.ignore_folders,
      @proj.dirs.public,
      ['plugins']
    )

    # ignore js templates folder
    # TODO: this is currently not working because of an issue with
    # readdirp: https://github.com/thlorenz/readdirp/issues/4
    if @config.templates then @config.ignore_folders.concat([@config.templates])

    # set up default watcher ignores
    @config.watcher_ignore_folders = _.union(
      @config.watcher_ignore_folders,
      ['components', 'plugins', '.git', @proj.dirs['public']]
    )

    @config.watcher_ignore_files = _.union(
      @config.watcher_ignore_folders,
      ['.DS_Store', 'app.coffee']
    )

    # format the file/folder ignore patterns
    format_ignores = (ary) -> ary.map (pat) -> "!" + pat.toString()
    @proj.ignore_files = format_ignores(@config.ignore_files);
    @proj.ignore_folders = format_ignores(@config.ignore_folders);
    @proj.watcher_ignore_folders = format_ignores(@config.watcher_ignore_folders);
    @proj.watcher_ignore_files = format_ignores(@config.watcher_ignore_files);

  configure_templates: ->
    @proj.templates = @config.templates

module.exports = (args, cb) ->
  conf = new ConfigLoader(args, cb)
  conf.init()
