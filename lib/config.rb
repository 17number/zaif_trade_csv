class Config
  attr_accessor :params

  def initialize(base_dir)
    conf_file =  "#{base_dir}/config/config.yaml"
    @params = Hashie::Mash.load(conf_file)
  end
end
