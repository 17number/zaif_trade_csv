def load_gems
  require "date"
  require "active_support/all"
  gem_files = Dir[File.expand_path("../vendor/bundle/**/gems", __FILE__) << '/*/lib/*.rb']
  lib_files = Dir[File.expand_path("../lib/**/", __FILE__) << '/*.rb']
  gem_files.concat(lib_files).each {|file| require file}
end

def get_base_dir
  base_file = ENV['OCRA_EXECUTABLE'] || $0
  File.expand_path(File.dirname(base_file))
end

# 実行ディレクトリ
base_dir = get_base_dir

# 証明書 設定
ENV['SSL_CERT_FILE'] = "#{base_dir}/pem/cacert.pem"

# ライブラリ読込み
load_gems

# Config 設定
conf = Config.new(base_dir)

# Logger 初期化
TRLogging.init(conf.params.logging, "#{base_dir}/log/tr.log")

# 確定申告 対象年
AnalyzeExchange.set_year(conf.params.year)

# 集計対象 取引所
anl_zaif = AnalyzeZaif.new(base_dir)

# 取引所別 集計
anl_zaif.create_trade_csv
