#!/usr/bin/env ruby

require "./log_watcher"


class MoEMessageLogger
  def throw_message msg
    puts "#{msg.received_date} #{msg.received_time}: 受理"
    msg.print
    if res = msg.is_tell? then
      p res
    end
  end
end

moe_logger = MoEMessageLogger.new("/mnt/c/MOE/Master of Epic/userdata/DIAMOND_カリガカリ_/")
moe_logger.run

