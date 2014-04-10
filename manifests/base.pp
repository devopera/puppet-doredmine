define doredmine::base (

  # class arguments
  # ---------------
  # setup defaults

  $appname = $title,
  $user = 'web',
  $group = 'www-data',

  # similar to installapp for easy cross-over
  $repo_path = '/var/www/svn/svn.redmine.org',
  $repo_provider = 'svn',
  $repo_source = 'http://svn.redmine.org/redmine/branches/2.4-stable',
  $app_subpath = '',

  # default is redmine svn, so no config
  $install_crontabs = false,
  $install_databases = false,
  $install_filesets = false,
  $byrepo_hosts = {},
  $byrepo_vhosts = {},
  $byrepo_crontabs = {},
  $byrepo_databases = {},
  # undef means use defaults
  $byrepo_filewriteable = undef,
  
  # create symlink and if so, where
  $symlinkdir = false,
  
  # redmine install details
  $site_name = 'Redmine',
  $admin_user = 'admin',
  $admin_email = 'root@localhost',
  # admin password not currently used (default 'admin')
  $admin_password = 'admLn**',

  # database connection values
  # set db_type to undef not to create db
  $db_type = 'mysql',
  $db_name = 'doredmine',
  $db_user = 'doredmine',
  $db_pass = 'admLn**',
  $db_host = 'localhost',
  $db_port = '3306',
  $db_grants = ['all'],
  # don't automatically fill database with default data
  $db_populate = false,
  
  # don't monitor by default
  $monitor = false,

  # end of class arguments
  # ----------------------
  # begin class

) {

  # monitor if turned on
  if ($monitor) {
    class { 'doredmine::monitor' : 
      site_name => $site_name, 
    }
  }

  # create path folder only if it doesn't exist
  if ! defined(File["${repo_path}"]) {
    docommon::stickydir { "doredmine-webroot-${title}" :
      filename => "${repo_path}",
      user => $user,
      group => $group,
      require => File['common-webroot'],
    }
  }

  # setup default files
  $default_filewriteable = {
    "doredmine-base-log-${title}" => {
      filename => "${repo_path}/${appname}${app_subpath}/log",
      user => $::apache::params::user,
      context => 'httpd_log_t',
    },
    "doredmine-base-systmp-${title}" => {
      filename => "/tmp/${appname}/",
      user => $::apache::params::user,
      context => 'httpd_tmpfs_t',
    },
    "doredmine-base-tmp-${title}" => {
      filename => "${repo_path}/${appname}${app_subpath}/tmp",
      user => $::apache::params::user,
      context => 'httpd_tmpfs_t',
    },
    "doredmine-base-files-${title}" => {
      filename => "${repo_path}/${appname}${app_subpath}/files",
      user => $::apache::params::user,
      context => 'httpd_sys_rw_content_t',
    },
    "doredmine-base-public-plugin_assets-${title}" => {
      filename => "${repo_path}/${appname}${app_subpath}/public/plugin_assets",
      user => $::apache::params::user,
      context => 'httpd_sys_rw_content_t',
    },
  }
  $real_byrepo_filewriteable = $byrepo_filewriteable ? {
    undef => $default_filewriteable,
    default => $byrepo_filewriteable,
  }

  # checkout redmine (from SVN repo by default)
  dorepos::installapp { "${appname}" :
    user => $user,
    group => $group,
    repo_provider => $repo_provider,
    repo_path => $repo_path,
    repo_source => $repo_source,
    symlinkdir => $symlinkdir,
    byrepo_hosts => $byrepo_hosts,
    byrepo_vhosts => $byrepo_vhosts,
    byrepo_crontabs => $byrepo_crontabs,
    byrepo_databases => $byrepo_databases,
    byrepo_filewriteable => $real_byrepo_filewriteable,
    # stickydir may not be in this manifest, so require the file (directory) it creates
    # require => Docommon::Stickydir["doredmine-webroot-${title}"],
    require => File["${repo_path}"],
  }

  if ($db_type == 'mysql') {
    # create a database and user
    mysql::db { "${db_name}":
      user     => $db_user,
      password => $db_pass,
      host     => $db_host,
      grant    => $db_grants,
    }
    # create a database.yml config file
    file { "doredmine-base-config--${title}" :
      ensure => 'present',
      path => "${repo_path}/${appname}${app_subpath}/config/database.yml",
      owner => $user,
      group => $group,
      content => template('doredmine/database.yml.erb'),
      mode => 0640,
      require => [Dorepos::Getrepo[$appname]],
    }
  }

  # fetch redmine gems
  exec { "doredmine-base-install-bundle-${title}" :
    path => '/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin',
    command => "bash -c \"export HOME='/home/${user}/'; bundle install --quiet --without development test\"",
    user => $user,
    group => $group,
    timeout => 1800,
    cwd => "${repo_path}/${appname}${app_subpath}",
    require => [Dorepos::Installapp["${appname}"]],
  }->

  # generates a random key used by Rails to encode cookies storing session
  exec { "doredmine-base-rake-secret-token-${title}" :
    path => '/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin',
    command => "bash -c \"export HOME='/home/${user}/'; bundle exec rake generate_secret_token\"",
    user => $user,
    group => $group,
    cwd => "${repo_path}/${appname}${app_subpath}",
  }
  
  if ($db_populate) {
    # create database objects
    exec { "doredmine-base-rake-create-objects-${title}" :
      path => '/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin',
      command => 'bash -c "RAILS_ENV=production bundle exec rake db:migrate"',
      user => $user,
      group => $group,
      cwd => "${repo_path}/${appname}${app_subpath}",
      require => [Exec["doredmine-base-install-bundle-${title}"]],
    }->
    # create example data
    exec { "doredmine-base-rake-create-data" :
      path => '/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin',
      command => 'bash -c "RAILS_ENV=production REDMINE_LANG=en bundle exec rake redmine:load_default_data"',
      user => $user,
      group => $group,
      cwd => "${repo_path}/${appname}${app_subpath}",
    }
  }

}
