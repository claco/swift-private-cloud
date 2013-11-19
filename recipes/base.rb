#
# Cookbook Name:: swift-private-cloud
# Recipe:: common
#
# Copyright 2012, Rackspace US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe "swift-private-cloud::attr-remap"
include_recipe "swift-private-cloud::packages"
include_recipe "swift-lite::ntp"
include_recipe "swift-private-cloud::logging"
include_recipe "swift-private-cloud::mail"
include_recipe "swift-private-cloud::snmp"
include_recipe "swift-private-cloud::sysctl"
include_recipe "swift-lite::common"
include_recipe "git"


resources("directory[/etc/swift]").mode "0755"
resources("template[/etc/swift/swift.conf]").mode "0644"

# make sure we have a swift lock directory - should this be in swift-lite?
directory "/var/lock/swift" do
  owner "swift"
  group "swift"
  mode "0750"
  action :create
end

template "/etc/default/megaclisas-statusd" do
  source "common/etc/default/megaclisas-statusd.erb"
  only_if { platform_family?("debian") }
end

# /etc/exim4
if not node["swift-private-cloud"]["mailing"]["relay_nets"]
  relay_nets = ["127.0.0.1", "::::1"]
else
  relay_nets = node["swift-private-cloud"]["network"]
end

relay_hosts = relay_nets.join(platform_family?("debian") ? ";" :  " : ")
smarthost = node["swift-private-cloud"]["mailing"]["smarthost"]

template "/etc/exim4/update-exim4.conf.conf" do
  source "common/etc/exim4/update-exim4.conf.conf.erb"
  variables(
    :config_type => "satellite",
    :local_interfaces => "127.0.0.1",
    :hide_mailname => "true",
    :outgoing_domain => node["swift-private-cloud"]["mailing"]["outgoing_domain"],
    :smarthost => smarthost
  )
  notifies :run, "execute[update-exim-config]", :delayed
  only_if { platform_family?("debian") }
end

template "/etc/exim/exim.conf" do
  source "common/etc/exim4/exim.conf.erb"
  variables(
    :local_interfaces => "127.0.0.1",
    :outgoing_domain => node["swift-private-cloud"]["mailing"]["outgoing_domain"],
    :relay_hosts => relay_hosts,
    :smarthost => smarthost
  )
  notifies :restart, "service[#{node['exim']['platform']['service']}]", :delayed
  only_if { platform_family?("rhel") }
end

# /etc/logrotate.d
template "/etc/logrotate.d/swift" do
  source "common/etc/logrotate.d/swift.erb"
  variables(
    :postrotate_command => platform_family?("debian") ?
      "/usr/sbin/invoke-rc.d syslog-ng reload >/dev/null" :
      "/sbin/service syslog-ng reload >/dev/null")
end

# /etc/snmp
template "/etc/snmp/snmp.conf" do
  source "common/etc/snmp/snmp.conf.erb"
  notifies :restart, "service[#{node['snmp']['platform']['service']}]", :delayed
end

template "/etc/snmp/snmpd.conf" do
  source "common/etc/snmp/snmpd.conf.erb"
  notifies :restart, "service[#{node['snmp']['platform']['service']}]", :delayed
end


# /etc/swift
template "/etc/swift/mime.types" do
  source "common/etc/swift/mime.types.erb"
  owner "swift"
  group "swift"
  mode "0644"
end

# syslog-ng
template "/etc/syslog-ng/syslog-ng.conf" do
  source "common/etc/syslog-ng/syslog-ng.conf.erb"
  variables(
    :remote_syslog_ip => node["swift-private-cloud"]["swift_common"]["syslog_ip"]
  )
  notifies :reload, "service[syslog-ng]", :delayed
end

# Mail
execute "rehash-aliases" do
  command "exim_dbmbuild /etc/aliases /etc/aliases.db"
  action :nothing
end

template "/etc/aliases" do
  source "common/etc/aliases.erb"
  variables(
    :email_addr => node["swift-private-cloud"]["mailing"]["email_addr"],
    :pager_addr => node["swift-private-cloud"]["mailing"]["pager_addr"]
  )

  notifies :run, "execute[rehash-aliases]", :immediately
end

# NTP
resources("template[/etc/ntp.conf]") do
  cookbook "swift-private-cloud"
  source "common/etc/ntp.conf"
end

# Swift Ring
template "/usr/local/bin/pull-rings.sh" do
  source "common/usr/local/bin/pull-rings.sh.erb"
  user "swift"
  group "swift"
  mode "0700"
  variables(
    :repo => node["swift-private-cloud"]["versioning"]["repository_name"],
    :builder_ip => node["swift-private-cloud"]["versioning"]["repository_host"],
    :service_prefix => platform_family?("debian") ? "" : "openstack-")
  only_if "/usr/bin/id swift"
end

# Adding some helpful/needed packages
centos_pkgs = [
  "patch", "dstat", "iptraf", "iptraf-ng", "htop", "sysstat",
  "strace", "iotop", "mailx", "screen", "bonnie++", "sqlite"]

ubuntu_pkgs = [
  "python-software-properties", "patch", "debconf", "bonnie++", "dstat",
  "ethtool", "python-configobj", "curl", "iptraf", "htop", "nmon", "sysstat",
  "strace", "iotop", "debsums", "python-pip", "bsd-mailx", "screen", "sqlite3"]

packages = value_for_platform(
  "centos" => { "default" => centos_pkgs },
  "ubuntu" => { "default" => ubuntu_pkgs },
  "default" => []
)

packages.each do |pkg|
  package pkg do
    action :install
  end
end

template "/etc/default/sysstat" do
  source "common/etc/default/sysstat.erb"
  user "root"
  group "root"
  mode "0644"
  only_if { node.platform_family?("debian") }
  notifies :restart, "service[sysstat]", :delayed
end

service "sysstat" do
  supports :restart => true
  action [:enable, :start]
end
