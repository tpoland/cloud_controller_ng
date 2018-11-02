module VCAP::CloudController
  module Diego
    class Protocol
      class OpenProcessPorts
        attr_reader :process

        def initialize(process)
          @process = process
        end

        def to_a
          process_ports.concat(process.route_mappings.map(&:app_port)).uniq
        end

        def process_ports
          return process.ports unless process.ports.nil?
          return process.docker_ports if process.docker?
          return [VCAP::CloudController::ProcessModel::DEFAULT_HTTP_PORT] if process.web?
          []
        end
      end
    end
  end
end
