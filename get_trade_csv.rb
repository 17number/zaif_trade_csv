def load_gems
  require "date"
  require "active_support/all"
  gem_files = Dir[File.expand_path("../vendor/bundle/**/gems", __FILE__) << '/*/lib/*.rb']
  lib_files = Dir[File.expand_path("../lib/**/", __FILE__) << '/*.rb']
  gem_files.concat(lib_files).each {|file| require file}
end

# ライブラリ読込み
load_gems

# Config 設定
conf = Config.new

# Logger 初期化
TRLogging.init(conf.params.logging)

# 確定申告 対象年
AnalyzeExchange.set_year(conf.params.year)

# 集計対象 取引所
anl_zaif = AnalyzeZaif.new

# 取引所別 集計
anl_zaif.create_trade_csv
