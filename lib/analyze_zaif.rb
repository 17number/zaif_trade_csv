class AnalyzeZaif < AnalyzeExchange
  COUNTS = 1000
  SLEEP_SEC = 3.0

  def initialize(base_dir)
    @base_dir = base_dir
    @exchange = "zaif"
    super()
    @api_client = ZaifClient.new(@base_dir)
    @lock = Mutex.new
    conf_file = "#{@base_dir}/config/#{@exchange}.yaml"
    conf = Hashie::Mash.load(conf_file)
    set_currency_pairs(conf)
    @start_timestamp = if @@year.present?
      Time.parse("#{@@year}-01-01").to_i
    else
      0
    end
    @action_english = conf.action_english
  end

  def create_trade_csv
    # 現物取引履歴
    get_trade_api_data

    # 日時でソート
    sort_by_date_and_id

    # ファイルオープン
    out_files = open_out_files

    # データ書き込み
    @ex_data.each do |d|
      market = d[:market]
      out_file = out_files[market]
      write_data(out_file, d)
      write_data(out_files["all_btc"], d) if market.include?("_btc")
      write_data(out_files["all_jpy"], d) unless market.include?("_btc")
    end

    # ファイルクローズ
    out_files.each{|pair, file| file.close}
  end

  private
  def set_currency_pairs(conf)
    if conf.currency_pairs.all == 1
      @currency_pairs = @api_client.call_api(:get_currency_pairs).map{|c| c["currency_pair"]}
    else
      @currency_pairs = conf.currency_pairs.select{|k, v| v == 1}.keys
    end
    TRLogging.log(@logger, :info, "currency_pairs: #{@currency_pairs}")
  end

  def get_trade_api_data
    Parallel.map(@currency_pairs, in_threads: Parallel.processor_count) do |currency_pair|
      from_id = 0
      trades = @api_client.call_api(:get_my_trades, {currency_pair: currency_pair, order: "ASC", since: @start_timestamp})
      TRLogging.log(@logger, :info, "currency_pair: #{currency_pair}'s trades(#{trades.size}) will be processed.")
      while trades.present?
        trades.each do |id, trade|
          from_id = id.to_i + 1
          next unless is_target_year?(trade["datetime"].strftime("%Y"))
          extract_trade_data(trade, id)
        end
        sleep SLEEP_SEC
        break if trades.size < COUNTS / 2
        trades = @api_client.call_api(:get_my_trades, {currency_pair: currency_pair, order: "ASC", from_id: from_id})
        TRLogging.log(@logger, :info, "currency_pair: #{currency_pair}'s trades(#{trades.size}) will be processed.")
      end
    end
  end

  def extract_api_data_common(api_data, id, action, key_datetime)
    data = {}
    data[:id] = id.to_i
    data[:market] = api_data["currency_pair"]
    data[:datetime] = get_datetime(api_data[key_datetime])
    if @action_english == 0
      action = action == "bid" ? "買い" : "売り"
    end
    data[:action] = action
    data
  end

  def extract_trade_data(trade, id)
    action = trade["your_action"]
    if action == "both"
      TRLogging.log(@logger, :info, "Detected self trades!! #{id} : #{trade}")
      extract_buy_sell_data(trade, id, "bid")
      trade[:fee] = 0.0
      trade[:fee_amount] = 0.0
      extract_buy_sell_data(trade, id, "ask")
    else
      extract_buy_sell_data(trade, id, action)
    end
  end

  def extract_buy_sell_data(trade, id, action)
    data = extract_api_data_common(trade, id, action, "datetime")
    data[:rate] = trade["price"]
    data[:amount_a] = trade["amount"]
    data[:fee] = trade["fee"] || 0.0
    data[:fee] += trade["fee_amount"] || 0.0
    data[:bonus] = trade["bonus"] || ""
    data[:comment] = trade["comment"] || ""
    @lock.synchronize { @ex_data << data }
  end

  def get_datetime(datetime)
    datetime.strftime("%Y/%m/%d %H:%M:%S.%6N")
  end

  def open_out_files
    out_files = {}

    extra_file_names = ["all_btc", "all_jpy"]
    extra_file_names.each do |name|
      out_files[name] = File.open("#{@base_dir}/results/#{name}.csv", "w")
      write_header(out_files[name], name)
    end

    currency_pairs = @ex_data.group_by{|d| d[:market]}.keys
    currency_pairs.each do |pair|
      out_files[pair] = File.open("#{@base_dir}/results/#{pair}.csv", "w")
      write_header(out_files[pair], pair)
    end

    out_files
  end

  def write_header(out_f, pair)
    str  = "マーケット"
    str += ",取引種別"
    str += ",価格"
    str += ",数量"
    str += ",取引手数料"
    str += ",ボーナス円" unless pair.include?("_btc")
    str += ",日時"
    str += ",コメント"
    out_f.puts str
  end

  def write_data(out_f, d)
    str  = "#{d[:market]}"
    str += ",#{d[:action]}"
    str += ",#{format("%.8f", d[:rate])}"
    str += ",#{format("%.8f", d[:amount_a])}"
    str += ",#{format("%.8f", d[:fee])}"
    str += ",#{format("%.8f", d[:bonus]) if d[:bonus].present?}" unless d[:market].include?("_btc")
    str += ",#{d[:datetime]}"
    str += ",#{d[:comment]}"
    out_f.puts str
  end
end
