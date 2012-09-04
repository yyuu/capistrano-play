# capistrano-play

a capistrano recipe to deploy [Play!](http://www.playframework.org/) apps.

this project was forked from [play-capistrano](https://github.com/mandubian/play-capistrano) and modified to create gem.

## Installation

Add this line to your application's Gemfile:

    gem 'capistrano-play'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install capistrano-play

## Usage

This recipes will try to do following things during Capistrano `deploy:setup` and `deploy` tasks.

1. Download and install Play! runtime for current project
2. Prepare `~/.ivy2/ivysettings.xml` (optional)
3. Build Play! project remotely (default) or locally

To build you Play! projects during Capistrano `deploy` tasks, add following in you `config/deploy.rb`. By default, Play! precompile will run after the Capistrano's `deploy:finalize_update`.

    # in "config/deploy.rb"
    require 'capistrano-play'
    set(:play_version, '1.2.4') # Play! version for your app

Following options are available to manage your Play! build.

 * `:play_version` - Play! version for your app. `1.2.5` by default.
 * `:play_zip_url` - download URL of Play! runtime.
 * `:play_preserve_zip` - controls whether preserving downloaded archive or not. `true` by default.
 * `:play_daemonize_method` - `:play` or `:upstart` are sensible.
 * `:play_use_precompile` - performe precompilation before restarting service. `true` by default.
 * `:play_precompile_locally` - perform precompilation on localhost. `false` by default.
 * `:play_java_home` - `JAVA_HOME` for Play! runtime.
 * `:play_java_home_local` - `JAVA_HOME` for Play! runtime on localhost.
 * `:play_setup_ivy` - controls whether managing `~/.ivy2/ivysettings.xml` or not. `false` by default.
 * `:play_setup_ivy_locally` - controls whether managing `~/.ivy2/ivysettings.xml` or not. `false` by default.
 
## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Author

- YAMASHITA Yuu (https://github.com/yyuu)
- Geisha Tokyo Entertainment Inc. (http://www.geishatokyo.com/)

## License

Apache License 2.0
