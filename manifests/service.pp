# Puppet class that controls the Kubelet service

class kubernetes::service (

  Boolean $controller                = $kubernetes::controller,
  Boolean $bootstrap_controller      = $kubernetes::bootstrap_controller,
  String $container_runtime          = $kubernetes::container_runtime,
  Optional[String] $etcd_ip          = $kubernetes::etcd_ip,
){

  $peeruls = inline_template("'{\"peerURLs\":[\"http://${etcd_ip}:2380\"]}'")

  file {'/etc/systemd/system/kubelet.service.d':
    ensure => 'directory',
  }

  file {'/etc/systemd/system/kubelet.service.d/kubernetes.conf':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('kubernetes/kubernetes.conf.erb'),
    require => File['/etc/systemd/system/kubelet.service.d'],
    notify  => Exec['Reload systemd'],
  }

  exec { 'Reload systemd':
    path        => '/bin',
    command     => 'systemctl daemon-reload',
    refreshonly => true,
    #unless      => 'uname -a | grep coreos',
  }

  case $container_runtime {
    'docker': {
      if $facts['os']['name'] == 'CoreOS' {
        service { 'docker':
          ensure => stopped,
        }
        file { '/etc/systemd/system/kubelet.service':
          content => '[Service]',
        }
        service { 'etcd-member':
          ensure => running,
        }
        service { 'kubelet':
          ensure => running,
          require => File['/etc/systemd/system/kubelet.service']
        }
      }
      else {
        service { 'docker':
          ensure => running,
          enable => true,
        }
        service {'kubelet':
          ensure    => running,
          enable    => true,
          subscribe => File['/etc/systemd/system/kubelet.service.d/kubernetes.conf'],
          require   => Service['docker'],
        }
      }
    }

    'cri_containerd': {
      service {'containerd':
        ensure  => running,
        enable  => true,
        require => Exec['Reload systemd'],
        before  => Service['kubelet'],
      }

      service {'cri-containerd':
        ensure  => running,
        enable  => true,
        require => Exec['Reload systemd'],
        before  => Service['kubelet'],
      }

      service {'kubelet':
        ensure    => running,
        enable    => true,
        subscribe => File['/etc/systemd/system/kubelet.service.d/kubernetes.conf'],
        require   => [Service['containerd'], Service['cri-containerd']],
      }
    }

    default: {
      fail(translate('Please specify a valid container runtime'))
    }
  }

  if $bootstrap_controller {
    exec {'Checking for the Kubernetes cluster to be ready':
      path        => ['/usr/bin', '/bin', '/opt/bin'],
      command     => 'kubectl get nodes | grep -w NotReady',
      tries       => 10,
      try_sleep   => 3,
      logoutput   => true,
      unless      => 'kubectl get nodes',
      environment => [ 'HOME=/root', 'KUBECONFIG=/root/admin.conf'],
      require     => [ Service['kubelet'], File['/root/admin.conf']],
    }
  }
}
