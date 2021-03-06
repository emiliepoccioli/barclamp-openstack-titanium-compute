#
# Cookbook Name:: nova
# Recipe:: compute
#
# Copyright 2010, Opscode, Inc.
# Copyright 2011, Dell, Inc.
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

# We are on computes nodes, nova.conf needs to have specific metadata settings
node.set[:nova][:nova_computes] = true 


if node[:nova][:networking_backend]=="quantum"
#unless node[:nova][:use_gitrepo]
#  package "quantum" do
#    action :install
#  end
#else
  include_recipe "nova::quantum"
#  pfs_and_install_deps "quantum" do
#    cookbook "quantum"
#    cnode quantum
#  end
#end
end

include_recipe "nova::config"


nova_package("compute")
nova_package("api")

# get VIP
haproxy = search(:node, "roles:haproxy").first
if haproxy.length > 0
  admin_vip = haproxy.haproxy.admin_ip
end

env_filter = " AND keystone_config_environment:keystone-config-#{node[:nova][:keystone_instance]}"
keystones = search(:node, "recipes:keystone\\:\\:server#{env_filter}") || []
if keystones.length > 0
  keystone = keystones[0]
  keystone = node if keystone.name == node.name
else
  keystone = node
end

# use VIP
keystone_address = admin_vip
keystone_token = keystone["keystone"]["service"]["token"]
keystone_service_port = keystone["keystone"]["api"]["service_port"]
keystone_admin_port = keystone["keystone"]["api"]["admin_port"]
keystone_service_tenant = keystone["keystone"]["service"]["tenant"]
keystone_service_user = node["nova"]["service_user"]
keystone_service_password = node["nova"]["service_password"]

Chef::Log.info("Keystone server found at #{keystone_address}")
Chef::Log.info("Keystone token:            #{keystone_token}")
Chef::Log.info("Keystone service port:     #{keystone_service_port}")
Chef::Log.info("Keystone admin port:       #{keystone_admin_port}")
Chef::Log.info("Keystone service tenant:   #{keystone_service_tenant}")
Chef::Log.info("Keystone service user:     #{keystone_service_user}")
Chef::Log.info("Keystone service password: #{keystone_service_password}")
Chef::Log.info("Keystone admin username:   #{keystone_service_user}")
Chef::Log.info("Keystone admin password    #{keystone_service_password}")

template "/etc/nova/api-paste.ini" do
  source "api-paste.ini.erb"
  owner node[:nova][:user]
  group "root"
  mode "0640"
  variables(
    :keystone_address => keystone_address,
    :keystone_admin_token => keystone_token,
    :keystone_service_port => keystone_service_port,
    :keystone_service_tenant => keystone_service_tenant,
    :keystone_service_user => keystone_service_user,
    :keystone_service_password => keystone_service_password,
    :keystone_admin_port => keystone_admin_port
  )
  notifies :restart, resources(:service => "nova-api"), :immediately
end

# ha_enabled activates Nova High Availability (HA) networking.
# The nova "network" and "api" recipes need to be included on the compute nodes and
# we must specify the --multi_host=T switch on "nova-manage network create".     

if node[:nova][:network][:ha_enabled] and node[:nova][:networking_backend]=='nova-network'
  include_recipe "nova::api"
  include_recipe "nova::network"
end

template "/etc/nova/nova-compute.conf" do
  source "nova-compute.conf.erb"
  owner "root"
  group "root"
  mode 0644
  notifies :restart, "service[nova-compute]"
end

# kill all the libvirt default networks.
execute "Destroy the libvirt default network" do
  command "virsh net-destroy default"
  only_if "virsh net-list |grep -q default"
end

link "/etc/libvirt/qemu/networks/autostart/default.xml" do
  action :delete
end

# enable or disable the ksm setting (performance)
  
template "/etc/default/qemu-kvm" do
  source "qemu-kvm.erb" 
  variables({ 
    :kvm => node[:nova][:kvm] 
  })
  mode "0644"
end

execute "set ksm value" do
  command "echo #{node[:nova][:kvm][:ksm_enabled]} > /sys/kernel/mm/ksm/run"
end

execute "set tranparent huge page enabled support" do
  # note path to setting is OS dependent
  # redhat /sys/kernel/mm/redhat_transparent_hugepage/enabled
  # Below will work on both Ubuntu and SLES
  command "echo #{node[:nova][:hugepage][:tranparent_hugepage_enabled]} > /sys/kernel/mm/transparent_hugepage/enabled"
  # not_if 'grep -q \\[always\\] /sys/kernel/mm/transparent_hugepage/enabled'
end

execute "set tranparent huge page defrag support" do
  command "echo #{node[:nova][:hugepage][:tranparent_hugepage_defrag]} > /sys/kernel/mm/transparent_hugepage/defrag"
end


execute "set vhost_net module" do
  command "grep -q 'vhost_net' /etc/modules || echo 'vhost_net' >> /etc/modules"
end

execute "IO scheduler" do
  command "find /sys/block -type l -name 'sd*' -exec sh -c 'echo deadline > {}/queue/scheduler' \\;"
end  

if node[:nova][:networking_backend]=="quantum"
  #since using native ovs we have to gain acess to lower networking functions
  service "libvirt-bin" do
    action :nothing
    supports :status => true, :start => true, :stop => true, :restart => true
  end

=begin
  # Volume template files
  cookbook_file "_create.html" do
    path  "#{pathDashboard}/dashboards/project/volumes/templates/volumes/_create.html"
    #path  '/usr/share/openstack-dashboard/openstack_dashboard/dashboards/project/volumes/templates/volumes/_create.html'
    action   :create
  end
=end

  cookbook_file "/etc/libvirt/qemu.conf" do
    user "root"
    group "root"
    mode "0644"
    source "qemu.conf"
    notifies :restart, "service[libvirt-bin]"
  end
end
