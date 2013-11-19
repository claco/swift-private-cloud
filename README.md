Support
=======

Issues have been disabled for this repository.
Any issues with this cookbook should be raised here:

[https://github.com/rcbops/chef-cookbooks/issues](https://github.com/rcbops/chef-cookbooks/issues)

Please title the issue as follows:

[swift-private-cloud]: \<short description of problem\>

In the issue description, please include a longer description of the
issue, along with any relevant log/command/error output.  If logfiles
are extremely long, please place the relevant portion into the issue
description, and link to a gist containing the entire logfile

Please see the [contribution guidelines](CONTRIBUTING.md) for more
information about contributing to this cookbook.

Description
===========

Installs packages and configuration for OpenStack Swift in the Private
Cloud.  This is a highly opinionated configuration of swift.  It
likely is not suitable for you.

A better choice might be wrapping or builing around
https://github.com/rcbops-cookbooks/swift-lite, a non-opinionated bare
bones swift install.

That's what this cookbook is, essentially, a opinionation wrapper
around swift-lite.

Requirements
============

Client:
 * CentOS >= 6.4
 * Ubuntu >= 12.04

Chef:
 * >= 11.4.0

Other variants of Ubuntu and Fedora may work, something crazy like
Solaris probably will not.  YMMV, objects in mirror, etc.

This differs from the rcbops OpenStack Swift cookbooks in that it
tries to do much less with the swift cluster.  Specifically:

 * It does not do swauth auth.  It just does keystone.

 * It does not do ring management, or set up a repo for storing rings in.

 * It does not do drive detection, formatting, mounting or unmounting

Generally this means that it does not do things that could potentially
cause cluster data loss, preferring to leave that to experienced
system administrators.

This cookbook leverages the rcbops swift-lite cookbook to do the heavy
swift lifting.

Attributes
==========

 * swift-private-cloud
   * common
     * ssh_user - unix admin user.
                      default: "swiftops"
     * ssh_key - ???
     * swift_generic - space separated list of packages to install on all boxes
     * swift_proxy - space separated list of packages to install on proxies
     * swift_storage - space separated list of packages to install on storage
     * swift_others - other random packages to install on all boxes
     * apt_options - default apt options when installing packages
   * network
     * management - cidr of management (swift network) ip range [REQUIRED]
     * exnet - cidr of exnet (public LB vip network) ip range [REQUIRED]
   * swift_common
     * admin_ip - ip of the admin box (with git ring repo and suchlike)
     * syslog_ip - ip of upstream syslog server (boxes will stream logs here)
     * swift_hash_prefix - swift hash prefix (preferred over suffix)
     * swift_hash_suffix - hash suffix (compatibility only)
     * log_statsd_host (statsd host to report metrics to, defaults to nil)
     * log_statsd_port (defaults to 8125)
     * log_statsd_default_sample_rate (defaults to 1.0)
     * log_statsd_sample_rate_factor (defaults to 1.0)
     * log_statsd_metric_prefix (defaults to nil)
   * proxy
     * pipeline - proxy-server.conf pipline
     * memcache_maxmem - memcache per proxy, this is maxmem (default 512M)
     * sim_connections - ???
     * memcache_server_list - space separated list of memcache servers "server:port server:port"
     * authtoken_factory - defaults to keystone
     * sysctl - key/value sysctl pairs, like { "net.ipv4.tcp_tw_recycle" => "1" }
   * storage
     * sysctl - key/value sysctl pairs, like { "net.ipv4.tcp_tw_recycle" => "1" }
   * mailing
     * email_addr - address to send notifications from
     * pager_addr - used by scripts / crons as a more severe notification email address.
     * smarthost - ip of smarthost
     * outgoing_domain - domain suffix
   * versioning
     * versioning_system - rcs to use for ring control.  only git supported now
     * repository_base - where to drop the git
     * repository_name - what repo to check out for ring updatres
   * keystone
     * keystone_ip - lb vip of keystone
     * keystone_port - management port
     * ... this all seems broken to me
   * dispersion
     * dis_tenant - tenant for dispersion reports (created automatically)
     * dis_user - user for dispersion reports (created automatically)
     * dis_key - password/key for dispersion user (no default)
     * dis_coverage - the percentage of partition coverage used in dispersion reporting
                          default: 1


Deps
====

 * dsh
 * keystone
 * openssl
 * osops-utils
 * sysctl

Roles
=====

Some example roles have been provided in contrib/roles

Small "starter" config:

  * spc-starter-controller
    * dsh
    * syslog collector
    * keystone
    * object-expirer
    * central ntpd
  * spc-starter-proxy
    * swift-proxy
    * memcache
  * spc-starter-storage
    * swift-object
    * swift-container
    * swift-account

Larger "scalable" config:

  * spc-scalable-controller
    * as starter, minus syslog
  * spc-scalable-proxy
    * as starter
  * spc-scalable-syslog
    * syslog collector
  * spc-scalable-storage
    * as starter

Example Deployment
==================

"Starter":

  * 2 nodes with runlist of "role[spc-starter-proxy]"
  * 3 (or more) nodes with runlist of "role[spc-starter-storage]"
  * 1 node with runlist of "role[spc-starter-controller]"

Environment (minimum)

~~~~
    ...
    "override_attributes": {
        "swift-private-cloud": {
            "swift_common": {
                "swift_hash_prefix": "<some random string>",
                "swift_hash_suffix": "<some random string>"
            },
            "network": {
                "management": "<cidr of private management net>",
                "exnet": "<cidr of lb public net>"
            },
            "keystone": {
                "auth_password": "xxx",
                "admin_password": "xxx",
                "ops_password": "xxx",
                "swift_admin_url": "http://xxxxx:8080/v1/AUTH_%(tenant_id)s",
                "swift_public_url": "http://xxxxx:8080/v1/AUTH_%(tenant_id)s",
                "swift_internal_url": "http://xxxxx:8080/v1/AUTH_%(tenant_id)s"
            },
            "dispersion": {
                "dis_key": "not_automatically_created"
            }
        }
    }
    ...
~~~~




License and Author
==================

|                     |                                                   |
|:--------------------|:--------------------------------------------------|
| **Authors**         | Ron Pedde (<ron.pedde@rackspace.com>)             |
|                     | Will Kelly (<will.kelly@rackspace.com>)           |
|                     | Chris Laco (<chris.laco@rackspace.com>)           |
|                     | Andy McCrae (<andrew.mccrae@rackspace.co.uk>)     |
|                     | Hugh Saunders (<hugh.saunders@rackspace.co.uk>)   |
|                     | Marcelo Martins (<marcelo.martins@rackspace.com>) |
|                     |                                                   |
| **Copyright**       | 2012, 2013 Rackspace US, Inc.                     |

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
