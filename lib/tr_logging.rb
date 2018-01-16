class TRLogging
  def self.init(conf, file = 'log/tr.log')
    @@file = conf.file || file
    @@age = conf.rotate_age || 'daily'
    @@size = conf.rotate_size || 0
    @@lock = Mutex.new
    set_color_scheme
    set_layouts
    set_appender_stdout(conf.level.stdout)
    set_appender_file(conf.level.file)
  end

  # logger 設定
  def self.logger(id)
    logger = Logging.logger[id]
    logger.add_appenders 'stdout', @@file
  end

  # log 出力
  def self.log(logger, level, *msgs)
    @@lock.synchronize {
      msgs.each do |msg|
        logger.send(level, msg)
      end
    }
  end

  private
  # appender 設定に用いるパラメータ
  def self.set_appender_params(level, layout, age = "", size = 0)
    params_hash = {
      level: level,
      layout: layout,
    }
    params_hash = params_hash.merge(age: age) if age.match(/daily|weekly|monthly|\d+/)
    params_hash = params_hash.merge(size: size) if size > 0
    params_hash
  end

  # 標準出力
  def self.set_appender_stdout(level)
    Logging.appenders.stdout(
      set_appender_params(level, @@layout_stdout),
    )
  end

  # ファイル出力(ログローテーション)
  def self.set_appender_file(level)
    Logging.appenders.rolling_file(
      @@file,
      set_appender_params(level, @@layout_file, @@age, @@size),
    )
  end

  # 標準出力の色設定
  def self.set_color_scheme
    Logging.color_scheme('bright',
      :levels => {
        :info  => :green,
        :warn  => :yellow,
        :error => :red,
        :fatal => [:white, :on_red]
      },
      :date => :blue,
      :logger => :cyan,
      :message => :magenta
    )
  end

  # ログ フォーマット
  def self.set_layouts
    params_hash = {
      pattern: '%d %-5l %c: %m\n',
      date_pattern: '%Y-%m-%d %H:%M:%S.%6N',
    }
    @@layout_stdout = set_layout(params_hash.merge(color_scheme: 'bright',))
    @@layout_file = set_layout(params_hash)
  end

  # ログ フォーマット(共通部)
  def self.set_layout(params)
    Logging.layouts.pattern(params)
  end
end
