#!/usr/bin/env ruby

require 'pp'
require 'json'
require 'listen'
require 'digest/md5'
require 'time'


class MoELogRecord

  attr_accessor :date,:time,:message, :finger_print
  attr_accessor :received_date, :received_time
  attr_accessor :recorded_file

  def initialize date,time,message,file_path=nil
    @date = date
    @time = time
    @message = message
    # 比較用にハッシュ値を格納しておく
    @finger_print = Digest::MD5.hexdigest(@date+@time+@message) 
    @received_date = Time.now.strftime("%y/%m/%d")
    @received_time = Time.now.strftime("%X")
    @recorded_file =file_path
  end

  def print
    puts inspect
  end

  def inspect
    "#{@date} #{@time}: #{@message}"
  end

  def to_json
    { date: @date, time: @time, message: @message,
      finger_print: @finger_print,  
      received_date: @received_date, 
      received_time: @received_time,
      recorded_file: @recorded_file,
    }.to_json
  end
  def self.from_json json_object
    msg = MoELogRecord.new(json_object["date"],json_object["time"],json_object["message"],json_object["recorded_file"])
    msg.received_date = json_object["received_date"]
    msg.received_time = json_object["received_time"]
    msg 
  end

  ## メッセージタイプ判別
  def is_tell?
    @message.match(/(?<from_name>\S+) は (?<to_name>\S+) に言った : (?<message>.+)/)
  end
end


class MoELogWatcher
  def initialize userdata_path
    # WSLからみた 対象とするキャラクターのuser_data path
    @userdata_path = userdata_path
    # 処理済みlogのfile path
    outer_log_path = "./outer.log"

    @msg_store = nil #オンメモリでmsgを保持
    @log_store_fs = nil # 処理済みのログを記録するfs 

    puts "========== MoE Log Watcher ==============="
    puts "監視ログ場所: #{@userdata_path}"
    puts "受理ログ場所: #{outer_log_path}"
    puts "=========================================="
    puts "終了は Ctrl + C"
    puts "=========================================="

    # 過去の処理済みlogをオンメモリに読み込み
    @msg_store = File.readlines(outer_log_path).map do |json_line| 
      msg = MoELogRecord.from_json(JSON.parse(json_line))
      #puts "処理済みコメント： #{log_line}"
      msg
    end

    # 処理済みlog書き込み用FileStream
    @log_store_fs = File.open(outer_log_path,"a")
  end

  # 特定のログファイルを全て読み込んでMoEMessage オブジェクトの配列に変換
  def read_log_file(file_path)
    body = File.read(file_path, encoding: 'Shift_JIS:UTF-8')
    res =  body.split(/(?<date>\d{2}\/\d{2}\/\d{2}) (?<time>\d{2}:\d{2}:\d{2}):/)
    res.shift # 先頭の空文字列を削除
    res.map(&:chomp).each_slice(3).map{|date,time,message| MoELogRecord.new(date,time,message,file_path) }
  end

  def run
    # listener生成
    listener = Listen.to(@userdata_path) do |modified, added, removed| 
      pp modified
      # メッセージログだけ抜き出す
      modified_message_log_list = modified.grep(/mlog/)
      modified_message_log_list.each do |modified_message_log|
        # 改変があったログファイルを全部読み込み+MoEMessageの配列に変換
        read_log_file(modified_message_log).each do |msg|
          if not @msg_store.any?{|processed_log| processed_log.finger_print == msg.finger_print} then
            #新しいメッセージならば
            @msg_store << msg
            @log_store_fs.write(msg.to_json + "\n") 
            throw_message msg
          end
        end
      end
    end

    begin
      # listenerを実行して、活かすために一生sleep
      # 多分もっと上手い方法ある
      listener.start
      sleep
    rescue Interrupt
      puts "MoE Log Watcher を終了します"
      @log_store_fs.close
    end
  end

  # 受け取ったmessageを処理
  # ここを各自で実装
  def throw_message msg
    puts "#{msg.received_date} #{msg.received_time}: 受理"
    msg.print
  end
end


