# This is a basic adaption of the rails plugin to merb. It does not have all the features of the original.
# - This plugin can be found at http://github.com/joakimk/hoptoad_notifier_merb/tree/master
# - The original rails plugin can be found at http://github.com/thoughtbot/hoptoad_notifier/tree/master

require 'net/http'

class String
  def camelize
    self.split("_").map { |x| x.capitalize }.join
  end
end

module HoptoadNotifier
  class << self
    attr_accessor :api_key, :logger
    
    def configure
      yield self
    end    
    
    def logger
      @logger || Merb.logger
    end
    
    def notify_hoptoad(request, session)      
      params = request.params
      exception = params[:exception]
      
      data = {
        :api_key       => HoptoadNotifier.api_key,
        :error_class   => exception.class.name.camelize,
        :error_message => "#{exception.class.name.camelize}: #{exception.message}",
        :backtrace     => exception.backtrace,
        :environment   => ENV.to_hash
      }
                    
      data[:request] = {
        :params => params[:original_params].to_hash
      }
 
      data[:environment].merge!(request.env.to_hash)
      data[:environment][:RAILS_ENV] = Merb.env
       
      data[:session] = {
         :key         => session.instance_variable_get("@session_id"),
         :data        => session.instance_variable_get("@data")
      }
      
      send_to_hoptoad :notice => default_notice_options.merge(data)                 
    end
    
    def send_to_hoptoad(data) #:nodoc:
      url = URI.parse("http://hoptoadapp.com:80/notices/")
      
      Net::HTTP.start(url.host, url.port) do |http|
        headers = {
          'Content-type' => 'application/x-yaml',
          'Accept' => 'text/xml, application/xml'
        }
        http.read_timeout = 5 # seconds
        http.open_timeout = 2 # seconds
        # http.use_ssl = HoptoadNotifier.secure
        response = begin
                     http.post(url.path, stringify_keys(data).to_yaml, headers)
                   rescue TimeoutError => e
                     logger.error "Timeout while contacting the Hoptoad server."
                     nil
                   end
        case response
        when Net::HTTPSuccess then
          logger.info "Hoptoad Success: #{response.class}"
        else
          logger.error "Hoptoad Failure: #{response.class}\n#{response.body if response.respond_to? :body}"
        end
      end            
    end
    
    def default_notice_options #:nodoc:
      {
        :api_key       => HoptoadNotifier.api_key,
        :error_message => 'Notification',
        :backtrace     => caller,
        :request       => {},
        :session       => {},
        :environment   => ENV.to_hash
      }
    end     
    
    def stringify_keys(hash) #:nodoc:
      hash.inject({}) do |h, pair|
        h[pair.first.to_s] = pair.last.is_a?(Hash) ? stringify_keys(pair.last) : pair.last
        h
      end
    end       
  end
end
