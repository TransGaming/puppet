# Copyright (c) 2010 TransGaming Inc. All rights reserved. Use of this source
# code is governed by a BSD-style license that can be found in the LICENSE file.

include 'tg_yumrepo'

class splunk {
  
  # Ensure Splunk is installed!
  class base {
    package { splunk:
      ensure => installed,
    }
    service { splunk:
      ensure     => running,
      enable     => true,
      hasrestart => true,
      hasstatus  => false,
      pattern    => "splunkd",
      require    => [ File[ 
                            "/etc/init.d/splunk",
                            "/opt/splunk/etc/system/local/inputs.conf", 
                            "/opt/splunk/etc/splunk.license", 
                            "/opt/splunk/etc/certs/cacert.pem"
                          ],
                      Package["splunk"],
                    ],
      subscribe  => [ File[ 
                            "/opt/splunk/etc/splunk.license",
                            "/opt/splunk/etc/system/local/inputs.conf",
                            "/opt/splunk/etc/certs/cacert.pem"
                          ],
                      Package["splunk"],
                    ],
    }
    
    file { "/opt/splunk/etc/splunk.license":
      owner => splunk, group => splunk, mode => 600,
      source => [
        "puppet:///modules/splunk/etc/splunk.license.$fqdn",
        "puppet:///modules/splunk/etc/splunk.license",
      ],
      require => Package['splunk'],
    }
    
    
    # Init script (Based on `/opt/splunk/bin/splunk enable boot-start`)
    file { "/etc/init.d/splunk":
      owner => root, group => root, mode => 755,
      source => [
        "puppet:///modules/splunk/etc/init-script.$fqdn",
        "puppet:///modules/splunk/etc/init-script",
      ],
    }
    # Users local to the Splunk install (e.g., admin)
    file { "/opt/splunk/etc/passwd":
      owner => splunk, group => splunk, mode => 600,
      source => [
        "puppet:///modules/splunk/etc/passwd.$fqdn",
        "puppet:///modules/splunk/etc/passwd",
      ],
      require => Package['splunk'],
    }
    file { "/opt/splunk/etc/certs":
      ensure => directory,
      owner => splunk, group => splunk, mode => 700,
      require => Package['splunk'],
    }
    
    file { "/opt/splunk/etc/certs/cacert.pem":
      owner => splunk, group => splunk, mode => 600,
      source => [
        "puppet:///modules/splunk/etc/certs/cacert.pem",
      ],
      require => Package['splunk'],
    }
  } # end splunk::base
  
  
  # LightWeight Forwarder
  class lwf inherits splunk::base {
    # As much as the parent service definition rocks, we don't want it to start
    # before the SplunkLightForwarder stuff is in place, and even then it has
    # to be in place before the service is started, so let's alter the 
    # definition. While we're at it let's tell the service about the pem file:
    
    Service['splunk'] {
      require    => [ File[ 
                            "/etc/init.d/splunk",
                            "/opt/splunk/etc/system/local/inputs.conf", 
                            "/opt/splunk/etc/splunk.license", 
                            "/opt/splunk/etc/certs/cacert.pem", 
                            "/opt/splunk/etc/certs/forwarder.pem",
                            "/opt/splunk/etc/apps/SplunkLightForwarder"
                          ], 
                      Package["splunk"],
                    ],
      subscribe  => [ File[ 
                            "/opt/splunk/etc/splunk.license", 
                            "/opt/splunk/etc/certs/cacert.pem",
                            "/opt/splunk/etc/certs/forwarder.pem",
                            "/opt/splunk/etc/system/local/inputs.conf", 
                            "/opt/splunk/etc/apps/SplunkLightForwarder"
                          ],
                      Package["splunk"],
                    ],
      
    }
    
    file { "/opt/splunk/etc/system/local/inputs.conf":
      owner => splunk, group => splunk, mode => 600,
      content => template("splunk/local/inputs.conf.erb"),
      require => Package['splunk'],
    }
    
    ## Begin outputs.conf hack; summary:
    
    # If we manage outputs.conf with plaintext Splunk and Puppet will fight 
    # over the file with Splunk crypting the plaintext and Puppet replacing it
    # If we manage a proxy file and then trigger a command to copy the file to
    # the file Splunk is expecting it will work fine. In the exec we notify
    # the Splunk service so that it restarts when it picks up the new
    # outputs.conf file.
    file { "/opt/splunk/etc/system/local/outputs.conf-PUPPET":
      owner => splunk, group => splunk, mode => 400,
      source => [
        "puppet:///modules/splunk/etc/system/local/lwf-output.conf.$fqdn",
        "puppet:///modules/splunk/etc/system/local/lwf-output.conf",
      ],
      require => Package['splunk'],
      notify => Exec['move-outputs.conf'],
    }
    exec { "move-outputs.conf":
      command => "/bin/cp -f /opt/splunk/etc/system/local/outputs.conf-PUPPET /opt/splunk/etc/system/local/outputs.conf ; /bin/chown splunk:splunk /opt/splunk/etc/system/local/outputs.conf ; /bin/chmod 600 /opt/splunk/etc/system/local/outputs.conf",
      refreshonly => true,
      notify => Service['splunk'],
    }
    
    ## End outputs.conf hack
    
    file { "/opt/splunk/etc/apps/SplunkLightForwarder": 
      owner => splunk, group => splunk, mode => 600,
      recurse => true,
      purge => false,
      source => [
        "puppet:///modules/splunk/etc/apps/SplunkLightForwarder.$fqdn",
        "puppet:///modules/splunk/etc/apps/SplunkLightForwarder",
      ],
      require => Package['splunk'],
    }
    file { "/opt/splunk/etc/certs/forwarder.pem":
      owner => splunk, group => splunk, mode => 600,
      source => [
        "puppet:///modules/splunk/etc/certs/$fqdn.pem",
        "puppet:///modules/splunk/etc/certs/forwarder.pem",
      ],
      require => Package['splunk'],
    }
    
  } # end splunk::lwf
  
  
  # Let's just manage the Splunk cert for the Splunk indexer
  class server inherits splunk::base {
    # Just like the lwf above we need to tweak the Service definition to 
    # include the splunk.pem dependency.
    Service['splunk'] {
      require    => [ File[ 
                            "/etc/init.d/splunk",
                            "/opt/splunk/etc/system/local/inputs.conf", 
                            "/opt/splunk/etc/splunk.license", 
                            "/opt/splunk/etc/certs/cacert.pem", 
                            "/opt/splunk/etc/certs/splunk.pem"
                          ], 
                      Package["splunk"], 
                    ],
      subscribe  => [ File[ 
                            "/opt/splunk/etc/splunk.license", 
                            "/opt/splunk/etc/certs/cacert.pem",
                            "/opt/splunk/etc/certs/splunk.pem",
                            "/opt/splunk/etc/system/local/inputs.conf"
                          ],
                      Package["splunk"],
                    ],
      
    }
    
    file { "/opt/splunk/etc/system/local/inputs.conf":
      owner => splunk, group => splunk, mode => 600,
      content => template("splunk/local/inputs.conf-server.erb"),
      require => Package['splunk'],
    }
    file { "/opt/splunk/etc/certs/splunk.pem":
      owner => splunk, group => splunk, mode => 600,
      source => [
        "puppet:///modules/splunk/etc/certs/$fqdn.pem",
        "puppet:///modules/splunk/etc/certs/splunk.pem",
      ],
      require => Package['splunk'],
    }
  } # end splunk::server
}
