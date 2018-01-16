class Config
  attr_accessor :params

  def initialize
    conf_file =  File.expand_path("../../config/config.yaml", __FILE__)
    @params = Hashie::Mash.load(conf_file)
  end
end
