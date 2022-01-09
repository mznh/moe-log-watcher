#!/usr/bin/env ruby

require 'pp'
require 'listen'
require 'digest/md5'
require 'time'

# log/ログ : mlog_***_**_**.txt の1行
# msg/メッセージ : logを解釈してオブジェクトにしたもの

#TODO オンメモリで管理するログはredisに移したい

class MoEMessage
  attr_accessor :date,:time,:message, :finger_print
  attr_accessor :received_date, :received_time
  def initialize raw_log, log_pattern
    res = raw_log.match(log_pattern)
    
    @date = res[:date]
    @time = res[:time]
    @message = res[:message]
    # 比較用にハッシュ値を格納しておく
    @finger_print = Digest::MD5.hexdigest(@date+@time+@message) 
    @received_date = Time.now.strftime("%y/%m/%d")
    @received_time = Time.now.strftime("%X")
  end
  def print
    puts inspect
  end
  def inspect
    "#{@date} #{@time}: #{@message}"
  end
end

class MoEMessageLogger
  # 汎用 
  LOG_PATTERN = /(?<date>\d{2}\/\d{2}\/\d{2}) (?<time>\d{2}:\d{2}:\d{2}): (?<message>.+)/
  
  # TELL 解釈用
  #LOG_PATTERN = /(?<date>\d{2}\/\d{2}\/\d{2}) (?<time>\d{2}:\d{2}:\d{2}): (?<from_name>\S+) は (?<to_name>\S+) に言った : (?<message>\S+)/


  def initialize
    # 処理済みlogのfile path
    outer_log_path = "./outer.log"
    # WSLからみた 対象とするキャラクターのuser_data path
    @userdata_path = "/mnt/c/MOE/Master of Epic/userdata/DIAMOND_カリガカリ_/"

    @msg_store = nil #オンメモリでmsgを保持
    @log_store_fs = nil # 処理済みのログを記録するfs 

    puts "========== MoE Log Watcher ==============="
    puts "監視ログ場所: #{@userdata_path}"
    puts "受理ログ場所: #{outer_log_path}"
    puts "=========================================="

    # 過去の処理済みlogをオンメモリに読み込み
    @msg_store = File.readlines(outer_log_path).map do |log_line| 
      msg = MoEMessage.new(log_line,LOG_PATTERN)
      #puts "処理済みコメント： #{log_line}"
      msg
    end

    # 処理済みlog書き込み用FileStream
    @log_store_fs = File.open(outer_log_path,"a")

  end

  def run
    # listener生成
    listener = Listen.to(@userdata_path) do |modified, added, removed| 
      # メッセージログだけ抜き出す
      modified_message_log_list = modified.grep(/mlog/)
      if modified_message_log_list.empty? then
        # ログ以外が改変されてたら無視
        next
      end

      #MoE側の設定で保存するmlogは一つだけと仮定
      modified_message_log_list.each do |modified_message_log|
        # 改変があったログファイルを全部読み込み
        modified_logs = File.readlines(modified_message_log, encoding: Encoding::Shift_JIS).map{|raw_log| raw_log.chomp.encode(Encoding::UTF_8)}
        modified_logs.each do |log|
          msg = MoEMessage.new(log,LOG_PATTERN)
          if not @msg_store.any?{|processed_log| processed_log.finger_print == msg.finger_print} then
            #新しいメッセージならば
            #処理済み
            @log_store_fs.write log + "\n"
            throw_message msg
          end
        end
      end
    end

    begin
      # listenerを実行して、活かすために一生sleep
      listener.start
      sleep
    rescue Interrupt
      puts "MoE MessageLogger を終了します"
      @log_store_fs.close
    end
  end

  def throw_message msg
    @msg_store << msg
    puts "#{msg.received_date} #{msg.received_time}: 受理"
    msg.print
  end
end


moe_logger = MoEMessageLogger.new()
moe_logger.run
