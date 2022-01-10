#!/usr/bin/env ruby

require "./log_watcher"


class MoELogWatcher
  def throw_message msg
    p msg
    if res = msg.is_auction_channel? then
      p res["channel_name"]
      p res["from_name"]
      p res["message"]
    end
  end
end

moe_log_watcher = MoELogWatcher.new("/mnt/c/MOE/Master of Epic/userdata/DIAMOND_カリガカリ_/")
moe_log_watcher.run

