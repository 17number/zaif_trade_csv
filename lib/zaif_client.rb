class ZaifClient
  def initialize
    conf_file =  File.expand_path("../../keys/zaif.yaml", __FILE__)
    conf = Hashie::Mash.load(conf_file)

    @clients = conf["api_keys"].map.with_index do |key, i|
      Zaif::API.new(api_key: key, api_secret: conf["api_secrets"][i])
    end
    @logger = TRLogging.logger(self)
  end

  def call_api(name, params = nil)
    TRLogging.log(@logger, :debug, "API : #{name}, params : #{params}")
    begin
      response = nil
      if params.nil?
        response = get_api.send(name)
      else
        if params.is_a?(Array)
          response = get_api.send(name, *params)
        else
          response = get_api.send(name, params)
        end
      end
    rescue => e
      puts e
      # print_exception_info_l(e, __method__.to_s)
      if e.to_s.include?("Net::OpenTimeout") ||
         e.to_s.include?("Net::ReadTimeout") ||
         e.to_s.include?("Bad Gateway") ||
         e.to_s.include?("Bad Request") ||
         e.to_s.include?("execution expired") ||
         e.to_s.include?("nonce not incremented") ||
         e.to_s.include?("Failed to open TCP connection to api") ||
         e.to_s.include?("trade temporarily unavailable")
        sleep(rand(1..3))
        retry
      elsif e.to_s.include?("time wait restriction")
        sleep(rand(5..10))
        retry
      else
        raise e
      end
    end
    response
  end

  private
  def get_api
    @clients.sample
  end
end
