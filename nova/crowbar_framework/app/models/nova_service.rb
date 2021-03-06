# Copyright 2011, Dell 
# 
# Licensed under the Apache License, Version 2.0 (the "License"); 
# you may not use this file except in compliance with the License. 
# You may obtain a copy of the License at 
# 
#  http://www.apache.org/licenses/LICENSE-2.0 
# 
# Unless required by applicable law or agreed to in writing, software 
# distributed under the License is distributed on an "AS IS" BASIS, 
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
# See the License for the specific language governing permissions and 
# limitations under the License. 
# 

class NovaService < ServiceObject

  def initialize(thelogger)
    @bc_name = "nova"
    @logger = thelogger
  end

# Turn off multi proposal support till it really works and people ask for it.
  def self.allow_multiple_proposals?
    false
  end

# sak - commneted out as using percona
=begin
  def proposal_dependencies(role)
    answer = []
    #answer << { "barclamp" => "database", "inst" => role.default_attributes["nova"]["db"]["database_instance"] }
    answer << { "barclamp" => "keystone", "inst" => role.default_attributes["nova"]["keystone_instance"] }
    answer << { "barclamp" => "glance", "inst" => role.default_attributes["nova"]["glance_instance"] }
    answer << { "barclamp" => "rabbitmq", "inst" => role.default_attributes["nova"]["rabbitmq_instance"] }
    answer << { "barclamp" => "cinder", "inst" => role.default_attributes[@bc_name]["cinder_instance"] }
    #if role.default_attributes[@bc_name]["use_gitrepo"]
    #  answer << { "barclamp" => "git", "inst" => role.default_attributes[@bc_name]["git_instance"] }
    #end

    if role.default_attributes[@bc_name]["networking_backend"] == "quantum"
      answer << { "barclamp" => "quantum", "inst" => role.default_attributes[@bc_name]["quantum_instance"] }
    end
    answer
  end
=end

  #
  # Lots of enhancements here.  Like:
  #    * Don't reuse machines
  #    * validate hardware.
  #
  def create_proposal
    @logger.debug("Nova create_proposal: entering")
    base = super
    @logger.debug("Nova create_proposal: done with base")

    nodes = NodeObject.all
    nodes.delete_if { |n| n.nil? }
    nodes.delete_if { |n| n.admin? } if nodes.size > 1
    head = nodes.shift
    nodes = [ head ] if nodes.empty?
    base["deployment"]["nova"]["elements"] = {
      "nova-multi-controller" => [ head.name ],
      "nova-multi-compute" => nodes.map { |x| x.name }
    }
    # automatically swap to qemu if using VMs for testing (relies on node.virtual to detect VMs)
    nodes.each do |n|
      if n.virtual?
        base["attributes"]["nova"]["libvirt_type"] = "qemu"
        break
      end
    end

# sak - commneted out as using percona
=begin
    base["attributes"][@bc_name]["git_instance"] = ""
    begin
      gitService = GitService.new(@logger)
      gits = gitService.list_active[1]
      if gits.empty?
        # No actives, look for proposals
        gits = gitService.proposals[1]
      end
      unless gits.empty?
        base["attributes"][@bc_name]["git_instance"] = gits[0]
      end
    rescue
      @logger.info("#{@bc_name} create_proposal: no git found")
    end


    base["attributes"]["nova"]["db"]["database_instance"] = ""
    begin
      databaseService = DatabaseService.new(@logger)
      dbs = databaseService.list_active[1]
      if dbs.empty?
        # No actives, look for proposals
        dbs = databaseService.proposals[1]
      end
      if dbs.empty?
        @logger.info("Nova create_proposal: no database proposal found")
      else
        base["attributes"]["nova"]["db"]["database_instance"] = dbs[0]
      end
    rescue
      @logger.info("Nova create_proposal: no database found")
    end

    if base["attributes"]["nova"]["db"]["database_instance"] == ""
      raise(I18n.t('model.service.dependency_missing', :name => @bc_name, :dependson => "database"))
    end
=end
#end of change

    base["attributes"]["nova"]["rabbitmq_instance"] = ""
    begin
      rabbitmqService = RabbitmqService.new(@logger)
      rabbitmqs = rabbitmqService.list_active[1]
      if rabbitmqs.empty?
        # No actives, look for proposals
        rabbitmqs = rabbitmqService.proposals[1]
      end
      base["attributes"]["nova"]["rabbitmq_instance"] = rabbitmqs[0] unless rabbitmqs.empty?
    rescue
      @logger.info("Nova create_proposal: no rabbitmq found")
    end

    if base["attributes"]["nova"]["rabbitmq_instance"] == ""
      raise(I18n.t('model.service.dependency_missing', :name => @bc_name, :dependson => "rabbitmq"))
    end

    base["attributes"]["nova"]["keystone_instance"] = ""
    begin
      keystoneService = KeystoneService.new(@logger)
      keystones = keystoneService.list_active[1]
      if keystones.empty?
        # No actives, look for proposals
        keystones = keystoneService.proposals[1]
      end
      base["attributes"]["nova"]["keystone_instance"] = keystones[0] unless keystones.empty?
    rescue
      @logger.info("Nova create_proposal: no keystone found")
    end

    if base["attributes"]["nova"]["keystone_instance"] == ""
      raise(I18n.t('model.service.dependency_missing', :name => @bc_name, :dependson => "keystone"))
    end

    base["attributes"]["nova"]["glance_instance"] = ""
    begin
      glanceService = GlanceService.new(@logger)
      glances = glanceService.list_active[1]
      if glances.empty?
        # No actives, look for proposals
        glances = glanceService.proposals[1]
      end
      base["attributes"]["nova"]["glance_instance"] = glances[0] unless glances.empty?
    rescue
      @logger.info("Nova create_proposal: no glance found")
    end

    if base["attributes"]["nova"]["glance_instance"] == ""
      raise(I18n.t('model.service.dependency_missing', :name => @bc_name, :dependson => "glance"))
    end

    base["attributes"]["nova"]["cinder_instance"] = ""
    begin
      cinderService = CinderService.new(@logger)
      cinders = cinderService.list_active[1]
      if cinders.empty?
        # No actives, look for proposals
        cinders = cinderService.proposals[1]
      end
      base["attributes"]["nova"]["cinder_instance"] = cinders[0] unless cinders.empty?
    rescue
      @logger.info("Nova create_proposal: no cinder found")
    end

    if base["attributes"]["nova"]["cinder_instance"] == ""
      raise(I18n.t('model.service.dependency_missing', :name => @bc_name, :dependson => "cinder"))
    end

    base["attributes"]["nova"]["quantum_instance"] = ""
    begin
      quantumService = QuantumService.new(@logger)
      quantums = quantumService.list_active[1]
      if quantums.empty?
        # No actives, look for proposals
        quantums = quantumService.proposals[1]
      end
      base["attributes"]["nova"]["quantum_instance"] = quantums[0] unless quantums.empty?
    rescue
      @logger.info("Nova create_proposal: no quantum found")
    end

    if base["attributes"]["nova"]["quantum_instance"] == ""
      raise(I18n.t('model.service.dependency_missing', :name => @bc_name, :dependson => "quantum"))
    end

    # password unique for all nova services
    base["attributes"]["nova"]["service_password"] = '%012d' % rand(1e12)
    base["attributes"]["nova"]["db"]["password"] = random_password

    @logger.debug("Nova create_proposal: exiting")
    base
  end

  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("Nova apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    return if all_nodes.empty?

    # Handle addressing
    #
    # Make sure that the front-end pieces have public ip addreses.
    #   - if we are in HA mode, then that is all nodes.
    #
    # if tenants are enabled, we don't manage interfaces on nova-fixed.
    #
    net_svc = NetworkService.new @logger
    tnodes = role.override_attributes["nova"]["elements"]["nova-multi-controller"]
    if role.default_attributes["nova"]["networking_backend"]=="quantum"
      quantum = ProposalObject.find_proposal("quantum",role.default_attributes["nova"]["quantum_instance"])
      all_nodes.each do |n|
        if quantum["attributes"]["quantum"]["networking_mode"] == "gre"
          # If GRE we need to create 2 network interfaces, public and os_sdn on every node 
          @logger.info("Creates public and os_sdn interfaces on nova node")
          net_svc.allocate_ip "default","public","host",n
          net_svc.allocate_ip "default", "os_sdn", "host", n
        else
          net_svc.enable_interface "default", "nova_fixed", n
        end
      end unless all_nodes.nil?
    else
      tnodes = all_nodes if role.default_attributes["nova"]["network"]["ha_enabled"]
      unless tnodes.nil? or tnodes.empty?
        tnodes.each do |n|
          net_svc.allocate_ip "default", "public", "host", n
          unless role.default_attributes["nova"]["network"]["tenant_vlans"]
            net_svc.allocate_ip "default", "nova_fixed", "router", n
          end
        end
      end

      unless role.default_attributes["nova"]["network"]["tenant_vlans"]
        all_nodes.each do |n|
          net_svc.enable_interface "default", "nova_fixed", n
        end
      end
    end
    @logger.debug("Nova apply_role_pre_chef_call: leaving")
  end

end

