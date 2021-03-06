# == Class: bhv_cms::sftp
#
# === Authors
#
# Author Name <foppe.pieters@naturalis.nl>
#
# === Copyright
#
# Apache2 license 2017.
#
class bhv_cms::sftp(
){

# setup sftp user
  user { $bhv_cms::sftp_user:
    ensure              => present,
    comment             => 'sftp user',
    home                => "/home/${bhv_cms::sftp_user}",
    managehome          => true,
    password            => sha1('${bhv_cms::sftp_user}'),
    uid                 => $bhv_cms::sftp_uid
  }

  $image_name           = 'atmoz/sftp:latest'
  $container_name       = 'sftp'
  $diffcmd              = "/usr/bin/diff <(docker image inspect --format='{{.Id}}' ${image_name}) <(docker inspect --format='{{.Image}}' ${container_name})"
  $service_cmd          = "/usr/sbin/service docker-${container_name} restart"

  include 'docker'

  file { $bhv_cms::sftp_dir :
    ensure             => directory,
    owner              => $bhv_cms::sftp_user,
    group              => $bhv_cms::sftp_user,
    require            => User[$bhv_cms::sftp_user]
  }

  docker::run { $container_name :
    image               => $image_name,
    ports               => ["${bhv_cms::sftp_port}:22"],
    volumes             => ["${bhv_cms::sftp_dir}:/home/${bhv_cms::sftp_user}/content-clients",'/data/sftp-config/users.conf:/etc/sftp/users.conf:ro'],
    pull_on_start       => false,
    require             => [User[$bhv_cms::sftp_user],File[$bhv_cms::sftp_dir]]
  }

  docker::exec { 'usermod':
    detach                => true,
    container             => $container_name,
    command               => 'sleep 5 && /usr/sbin/usermod -g www-data boerhaave',
    tty                   => true,
    unless                => 'id boerhaave | grep www-data',
    require               => Docker::Run[$container_name],
  }

  exec { $service_cmd :
    onlyif              => $diffcmd,
    require             => [Exec["/usr/bin/docker pull ${image_name}"],Docker::Run[$container_name]]
  }

  exec {"/usr/bin/docker pull ${image_name}" :
    schedule            => 'everyday-sftp',
  }

  schedule { 'everyday-sftp':
    period              => daily,
    repeat              => 1,
    range               => '7-9',
  }

}
