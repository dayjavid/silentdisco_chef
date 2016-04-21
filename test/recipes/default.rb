#
# Cookbook Name:: test
# Recipe:: default
#
# Copyright 2016, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#
 
require 'pp'

elasticDataBag = data_bag_item('elasticstack', 'elasticbasecore')
 
server_memory_kb = node['memory']['total'].to_i
server_memory_gb = (server_memory_kb + 500000) / 1000000
server_memory_kb_rounded = server_memory_gb * 1000000
elasticsearch_heap_size_gb = 0
elasticsearch_heap_size_kb = 256000
num_es_instances = ((server_memory_kb_rounded / 2.0) / elasticsearch_heap_size_kb).round
count=0
 
db_hostname = #{node.name}
 
log "Hello World from machine: #{db_hostname}. Currently has #{server_memory_kb}kb memory available. That is #{server_memory_gb}GB.\n We could put #{num_es_instances} elasticsearch instances on this host.\n\
     Server Memory KB: #{server_memory_kb}\n \
     Server Memory KB Rounded: #{server_memory_kb_rounded}\n \
     Server Memory GB: #{server_memory_gb}\n \
     ES Heap Size GB: #{elasticsearch_heap_size_gb}\n \
     ES Heap Size KB: #{elasticsearch_heap_size_kb}\n \
     Number of Instances: #{num_es_instances}\n \
     Count: #{count}"  do
    level :info
end
 
#Create etc directory for elasticsearch
directory "#{elasticDataBag['global']['elasticsearch']['etc_dir']}" do
  owner 'jdavidmcclain'
  group 'jdavidmcclain'
  mode '0755'
  action :create
  recursive true
end
 
#Create dir path directory for elasticsearch
directory "#{elasticDataBag['global']['elasticsearch']['dir_path']}" do
  owner 'jdavidmcclain'
  group 'jdavidmcclain'
  mode '0755'
  action :create
  recursive true
end
 
count=0
while count < num_es_instances do
  directory "#{elasticDataBag['lab']['elasticsearch']['path_data_root']}/node#{count+1}/data" do
    owner 'jdavidmcclain'
    group 'jdavidmcclain'
    mode '0755'
    action :create
    recursive true
  end

  directory "#{elasticDataBag['global']['elasticsearch']['opt_path']}/node#{count+1}" do
    owner 'jdavidmcclain'
    group 'jdavidmcclain'
    mode '0755'
    action :create
    recursive true
  end
  
  bash 'setup_node_level_symlinks' do
  code <<-EOH
    unlink #{elasticDataBag['global']['elasticsearch']['opt_path']}/node#{count+1}/bin
    unlink #{elasticDataBag['global']['elasticsearch']['opt_path']}/node#{count+1}/lib
    unlink #{elasticDataBag['global']['elasticsearch']['opt_path']}/node#{count+1}/modules
    unlink #{elasticDataBag['global']['elasticsearch']['opt_path']}/node#{count+1}/plugins
    unlink #{elasticDataBag['global']['elasticsearch']['opt_path']}/node#{count+1}/tmp
    
    ln -s #{elasticDataBag['global']['elasticsearch']['dir_path']}/bin     #{elasticDataBag['global']['elasticsearch']['opt_path']}/node#{count+1}/bin
    ln -s #{elasticDataBag['global']['elasticsearch']['dir_path']}/lib     #{elasticDataBag['global']['elasticsearch']['opt_path']}/node#{count+1}/lib
    ln -s #{elasticDataBag['global']['elasticsearch']['dir_path']}/modules #{elasticDataBag['global']['elasticsearch']['opt_path']}/node#{count+1}/modules
    ln -s #{elasticDataBag['global']['elasticsearch']['dir_path']}/plugins #{elasticDataBag['global']['elasticsearch']['opt_path']}/node#{count+1}/plugins
    ln -s #{elasticDataBag['global']['elasticsearch']['dir_path']}/tmp     #{elasticDataBag['global']['elasticsearch']['opt_path']}/node#{count+1}/tmp
  EOH
  end

  directory "#{elasticDataBag['global']['elasticsearch']['opt_path']}/node#{count+1}/config" do
    owner 'jdavidmcclain'
    group 'jdavidmcclain'
    mode '0755'
    action :create
    recursive true
  end

  #Calculate port
  http_port_base = elasticDataBag['lab']['elasticsearch']['http_port_base']

  log "HTTP Port Base from Data Bag is: #{http_port_base}" do
    level :info
  end

  http_port = (Integer(elasticDataBag['lab']['elasticsearch']['http_port_base'])+(count+1)).to_s
  
  log "Calculated HTTP Port for node #{count+1} is: #{http_port}" do
    level :info
  end
  
  template "#{elasticDataBag['global']['elasticsearch']['opt_path']}/node#{count+1}/config/elasticsearch.yml" do
    source 'elasticsearch/elasticsearch.yml.erb'
    variables(
      :elasticsearch_cluster_name => "#{elasticDataBag['lab']['elasticsearch']['cluster_name']}",
      :elasticsearch_node_number => "#{count+1}",
      :elasticsearch_host => "silentdisco",
      :elasticsearch_number_of_shards => "#{elasticDataBag['lab']['elasticsearch']['number_of_shards']}",
      :elasticsearch_path_to_data => "#{elasticDataBag['lab']['elasticsearch']['path_data_root']}/node#{count+1}/data",
      :elasticsearch_path_to_logs => "#{elasticDataBag['lab']['elasticsearch']['path_data_root']}/node#{count+1}/logs",
      :elasticsearch_http_port => "#{http_port}"
    )
  end

  template "#{elasticDataBag['global']['elasticsearch']['opt_path']}/node#{count+1}/config/logging.yml" do
    source 'elasticsearch/logging.yml.erb'
  end
 
  template "/etc/init.d/elasticsearch_node#{count+1}" do
    source "elasticsearch/elasticsearch.erb"
    mode '0755'
    variables(
      :elasticsearch_node_number => count+1
    )
  end
 
  bash 'run_elasticsearch_add-service' do
  code <<-EOH
    cd /etc/init.d
    chmod 755 /opt/elasticsearch/init.d/elasticsearch_node#{count+1}
    chkconfig --add elasticsearch_node#{count+1}
    chkconfig --add elasticsearch_node#{count+1}
    chkconfig --level 234 elasticsearch_node#{count+1} on
    chkconfig --list elasticsearch_node#{count+1}
    EOH
  end

 
 
 
  count+=1
end
