#
# Cookbook Name:: swift-private-cloud
# Recipe:: admin-server-object-expirer.rb
#
# Copyright 2013, Rackspace US, Inc.
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

# this recipe assumes that the admin server role is not running a
# proxy server or an object server, as that is our reference
# architecture.  It will actively delete configs to prevent those
# services from starting.

include_recipe "swift-private-cloud::base"
include_recipe "swift-lite::common"

package "swift-proxy-package" do
  package_name "openstack-swift-proxy"
  action :install
  options node["swift-private-cloud"]["common"]["pkg_options"]
  only_if { platform_family?("redhat") }
end

package "swift-object-package" do
  package_name "swift-object"
  action :install
  options node["swift-private-cloud"]["common"]["pkg_options"]
  only_if { platform_family?("debian") }
end

file "swift-proxy.conf-file" do
  path "/etc/swift/proxy-server.conf"
  action :delete
  only_if { platform_family?("redhat") }
end

file "swift-object.conf-file" do
  path "/etc/swift/object-server.conf"
  action :delete
  only_if { platform_family?("debian") }
end

service "swift-proxy" do
  pattern "swift-proxy-server"
  action [:disable, :stop]
  only_if { platform_family?("debian") }
end

service "swift-object" do
  pattern "openstack-swift-object-server"
  action [:disable, :stop]
  only_if { platform_family?("debian") }
end

service "swift-object-expirer-service" do
  pattern "openstack-swift-object-expirer"
  action [:enable, :start]
  only_if { platform_family?("redhat") }
end

#service "swift-object-expirer-service" do
#  pattern "swift-object-expirer"
#  action [:enable, :start]
#  only_if { platform_family?("debian") }
#end

# logged bug https://bugs.launchpad.net/ubuntu/+source/swift/+bug/1235495
# when packages include an upstart job, this should be removed.
cookbook_file "object-expirer upstart job" do
  path "/etc/init/swift-object-expirer.conf"
  source "admin/etc/init/swift-object-expirer.conf"
  owner "root"
  group "root"
  mode "0644"
  only_if { platform_family?("debian") }
end

link "object expirer init script" do
  target_file "/etc/init.d/swift-object-expirer"
  to "/lib/init/upstart-job"
  owner "root"
  group "root"
  mode "755"
  only_if { platform_family?("debian") }
end

template "/etc/swift/object-expirer.conf" do
  source "admin/etc/swift/object-expirer.conf.erb"
  owner "swift"
  group "swift"
  mode "0644"
#  notifies :restart, "service[swift-object-expirer-service]", :delayed
end