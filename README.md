# moe-log-watcher

## 事前準備

処理済みのログを記録するファイルを作成
```
touch outer.log
```

## 起動方法

```
$ ./main.rb
========== MoE Log Watcher ===============
監視ログ場所: /mnt/c/MOE/Master of Epic/userdata/HOGE_マイキャラネーム_/
受理ログ場所: ./outer.log
==========================================
終了は Ctrl + C
==========================================
```

## いろいろやりたい

`main.rb` 内で MoELogWatcherクラスの `throw_message`メソッドを拡張してください。
