# fluent-plugin-ikachan

## Component

### IkachanOutput

Plugin to send message to IRC, over IRC-HTTP bridge 'Ikachan' by yappo.

About Ikachan:
 * https://metacpan.org/module/ikachan
 * http://blog.yappo.jp/yappo/archives/000760.html (Japanese)

## Configuration

### IkachanOutput

Before testing of fluent-plugin-ikachan, you should invoke 'ikachan' process::

    ### at first, install perl and cpanm (App::cpanminus)
    cpanm App::ikachan
    ikachan -S your.own.irc.server -P port

And then, configure out_ikachan::

    <match alert.**>
      # ikachan host/port(default 4979)
      host localhost
      port 4979
      # channel to notify (this means #morischan)
      channel morischan
      message notice: %s [%s] %s
      out_keys tag,time,msg
      time_key time
      time_format %Y/%m/%d %H:%M:%S
      tag_key tag
    </match>
    
You will got message like 'notice: alert.servicename [2012/05/10 18:51:59] alert message in attribute "msg"'.

## TODO

* implement 'tag_mapped'
* implement 'time' and 'tag' in key_names

## Copyright

* Copyright
  * Copyright (c) 2012- TAGOMORI Satoshi (tagomoris)
* License
  * Apache License, Version 2.0
