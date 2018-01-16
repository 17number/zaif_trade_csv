class AnalyzeZaif < AnalyzeExchange
  COUNTS = 1000
  SLEEP_SEC = 3.0

  def initialize
    @exchange  = "zaif"
    super
    @api_client = ZaifClient.new
    @lock = Mutex.new
    conf_file =  File.expand_path("../../config/#{@exchange}.yaml", __FILE__)
    conf = Hashie::Mash.load(conf_file)
    set_currency_pairs(conf)
    @start_timestamp = if @@year.present?
      Time.parse("#{@@year}-01-01").to_i
    else
      0
    end
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
      write_data(out_files["all"], d)
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
    data[:action] = action
    data
  end

  def extract_trade_data(trade, id)
    if trade["your_action"] == "bid"
      extract_buy_sell_data(trade, id, "買い")
    elsif trade["your_action"] == "ask"
      extract_buy_sell_data(trade, id, "売り")
    elsif trade["your_action"] == "both"
      TRLogging.log(@logger, :info, "Detected self trades!! #{id} : #{trade}")
      extract_buy_sell_data(trade, id, "買い")
      trade[:fee] = 0.0
      trade[:fee_amount] = 0.0
      extract_buy_sell_data(trade, id, "売り")
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
    out_files["all"] = File.open("results/all.csv", "w")
    write_header(out_files["all"])
    currency_pairs = @ex_data.group_by{|d| d[:market]}.keys
    currency_pairs.each do |pair|
      out_files[pair] = File.open("results/#{pair}.csv", "w")
      write_header(out_files[pair])
    end
    out_files
  end

  def write_header(out_f)
    out_f.puts "マーケット,取引種別,価格,数量,取引手数料,ボーナス円,日時,コメント"
  end

  def write_data(out_f, d)
    out_f.puts "#{d[:market]},#{d[:action]},#{format("%.8f", d[:rate])},#{format("%.8f", d[:amount_a])},#{format("%.8f", d[:fee])},#{format("%.8f", d[:bonus]) if d[:bonus].present?},#{d[:datetime]},#{d[:comment]}"
  end
end

