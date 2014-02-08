# fluent-plugin-ikachan, a plugin for [Fluentd](http://fluentd.org)

## Component

### IkachanOutput

[Fluentd](http://fluentd.org) plugin to send message to IRC, over IRC-HTTP bridge 'Ikachan' by yappo.

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
    
You will get a notice message like `notice: alert.servicename [2012/05/10 18:51:59] alert message in attribute "msg"`.

In addition to notice, out_ikachan can send privmsg into specified channel by `privmesg_message` and `privmsg_out_keys`.

    <match alert.**>
      # ikachan host/port(default 4979)
      host localhost
      port 4979
      # channel to notify (this means #morischan)
      channel morischan
      message notice: %s [%s] %s
      out_keys tag,time,msg
      privmsg_message [%s] morischan :D
      privmsg_out_keys time
      time_key time
      time_format %Y/%m/%d %H:%M:%S
      tag_key tag
    </match>

At least one of (`message` + `out_keys`) or (`privmsg_message` + `privmsg_out_keys`) must be specified.

## TODO

* implement 'tag_mapped'
* implement 'time' and 'tag' in key_names

## Copyright

* Copyright (c) 2012- TAGOMORI Satoshi (tagomoris)
* Contributed by:
  * @sonots
* License
  * Apache License, Version 2.0
