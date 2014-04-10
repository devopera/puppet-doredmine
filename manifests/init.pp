class doredmine (

  # class arguments
  # ---------------
  # setup defaults

  $user = 'web',
  $group = 'www-data',

  # end of class arguments
  # ----------------------
  # begin class

) {

  # install redmine deps
  if ! defined(Package['bundler']) {
    package { 'bundler' :
      ensure => 'installed',
      provider => 'gem',
    }
  }
  if ! defined(Package['rake']) {
    package { 'rake' :
      ensure => 'installed',
      provider => 'gem',
    }
  }

  # install Ruby ImageMagick deps
  case $operatingsystem {
    centos, redhat: {
      if ! defined(Package['ImageMagick-devel']) {
        package { 'ImageMagick-devel' :
          ensure => 'installed',
          before => [Package['rmagick']],
        }
      }
      if ! defined(Package['ImageMagick-c++-devel']) {
        package { 'ImageMagick-c++-devel' :
          ensure => 'installed',
          before => [Package['rmagick']],
        }
      }
    }
    ubuntu, debian: {
      if ! defined(Package['imagemagick']) {
        package { 'imagemagick' :
          ensure => 'installed',
          before => [Package['rmagick']],
        }
      }
      if ! defined(Package['librmagick-ruby']) {
        package { 'librmagick-ruby' :
          ensure => 'installed',
          before => [Package['rmagick']],
        }
      }
      if ! defined(Package['libmagickwand-dev']) {
        package { 'libmagickwand-dev' :
          ensure => 'installed',
          before => [Package['rmagick']],
        }
      }
    }
  }
  if ! defined(Package['rmagick']) {
    package { 'rmagick' :
      ensure => 'installed',
      provider => 'gem',
    }
  }

}
