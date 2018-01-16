class AnalyzeExchange
  ADJUST_TIME = 0
  # 全取引所 取引履歴
  @@all_ex_data = []
  @@year = 2017

  # 確定申告対象年
  def self.set_year(year)
    @@year = year
  end

  def initialize
    @logger = TRLogging.logger(self)

    # 単一取引所内 取引履歴
    @ex_data = []

    TRLogging.log(@logger, :info, "#{@exchange.capitalize} analyzer created.")
  end

  private
  # 時系列/ID 順にソート
  def sort_by_date_and_id
    @ex_data.sort_by! do |data|
      [data[:datetime], data[:id]]
    end
  end

  # 確定申告対象年のデータか判定
  # コンフィグで対象年を設定していない(空白)の場合は全て対象
  def is_target_year?(year)
    @@year.blank? || @@year == year.to_i
  end
end
