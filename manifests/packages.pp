# Class kubernetes packages

class kubernetes::packages (

  Optional[String] $kubernetes_package_version = $kubernetes::kubernetes_package_version,
  String $container_runtime                    = $kubernetes::container_runtime,
  String $cni_version                          = $kubernetes::cni_version,

) {

  $kube_packages = ['kubelet', 'kubectl']

  case $kubernetes_package_version {
    /1[.]9[.]\d/: {
      $cri_source = 'https://github.com/containerd/cri-containerd/releases/download/v1.0.0-beta.1/cri-containerd-1.0.0-beta.1.linux-amd64.tar.gz'
      $cri_archive = 'cri-containerd-1.0.0-beta.1.linux-amd64.tar.gz'
    }
    default: {
      $cri_source = 'https://github.com/containerd/cri-containerd/releases/download/v1.0.0-alpha.1/cri-containerd-1.0.0-alpha.1.tar.gz'
      $cri_archive = 'cri-containerd-1.0.0-alpha.1.tar.gz'
    }
  }

  if $container_runtime == 'docker' {
    case $::osfamily {
      'Debian' : {
        package { 'docker-engine':
          ensure => '1.12.0-0~xenial',
        }
        package { 'kubernetes-cni':
          ensure => $cni_version,
        }
      }

      'RedHat' : {
        package { 'docker-engine':
          ensure => '1.12.6',
        }
        package { 'kubernetes-cni':
          ensure => $cni_version,
        }
      }

      'CoreOS' : { 
        notify {"Docker is already installed on CoreOS":}
      }

      default: { notify {"The OS family ${::os_family} is not supported by this module":} }
    }

  }

  elsif $container_runtime == 'cri_containerd' {
    wget::fetch { 'wget cri-containerd':
      source      => $cri_source,
      destination => '/',
      timeout     => 0,
      verbose     => false,
    }

  -> archive { $cri_archive:
      ensure          => present,
      path            => "/${cri_archive}",
      extract         => true,
      extract_command => 'tar xfz %s --strip-components=1',
      extract_path    => '/',
      cleanup         => true,
      creates         => '/usr/local/bin/cri-containerd'
      }
  }


  case $::osfamily {
    'CoreOS' : {
      file { '/opt/bin/kubectl':
        ensure  => file,
        mode    => '0755',
        source  => "https://storage.googleapis.com/kubernetes-release/release/v${kubernetes_package_version}/bin/linux/amd64/kubectl"
      }
    }
    default: {
      package { $kube_packages:
        ensure => $kubernetes_package_version,
      }
    }
  }
}
