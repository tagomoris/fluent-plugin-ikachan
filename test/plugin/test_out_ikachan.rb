require 'helper'

class IkachanOutputTest < Test::Unit::TestCase
  CONFIG = %[
    host localhost
    channel morischan
    message out_ikachan: %s [%s] %s
    out_keys tag,time,msg
    privmsg_message out_ikachan: %s [%s] %s
    privmsg_out_keys tag,time,msg
    time_key time
    time_format %Y/%m/%d %H:%M:%S
    tag_key tag
  ]

  CONFIG_NOTICE_ONLY = %[
    host localhost
    channel morischan
    message out_ikachan: %s [%s] %s
    out_keys tag,time,msg
    time_key time
    time_format %Y/%m/%d %H:%M:%S
    tag_key tag
  ]

  CONFIG_PRIVMSG_ONLY = %[
    host localhost
    channel morischan
    privmsg_message out_ikachan: %s [%s] %s
    privmsg_out_keys tag,time,msg
    time_key time
    time_format %Y/%m/%d %H:%M:%S
    tag_key tag
  ]

  def create_driver(conf=CONFIG,tag='test')
    Fluent::Test::OutputTestDriver.new(Fluent::IkachanOutput, tag).configure(conf)
  end

  def test_configure
    d = create_driver
    assert_equal '#morischan', d.instance.channel
    d = create_driver(CONFIG_NOTICE_ONLY)
    assert_equal '#morischan', d.instance.channel
    d = create_driver(CONFIG_PRIVMSG_ONLY)
    assert_equal '#morischan', d.instance.channel
  end

  def test_notice_and_privmsg
    # To test this code, execute ikachan on your own host
    d = create_driver
    time = Time.now.to_i
    d.run do
      d.emit({'msg' => "both notice and privmsg message from fluentd out_ikachan: testing now"}, time)
      d.emit({'msg' => "both notice and privmsg message from fluentd out_ikachan: testing second line"}, time)
    end
  end

  def test_notice_only
    # To test this code, execute ikachan on your own host
    d = create_driver(CONFIG_NOTICE_ONLY)
    time = Time.now.to_i
    d.run do
      d.emit({'msg' => "notice message from fluentd out_ikachan: testing now"}, time)
      d.emit({'msg' => "notice message from fluentd out_ikachan: testing second line"}, time)
    end
  end

  def test_privmsg_only
    # To test this code, execute ikachan on your own host
    d = create_driver(CONFIG_PRIVMSG_ONLY)
    time = Time.now.to_i
    d.run do
      d.emit({'msg' => "privmsg message from fluentd out_ikachan: testing now"}, time)
      d.emit({'msg' => "privmsg message from fluentd out_ikachan: testing second line"}, time)
    end
  end
end
