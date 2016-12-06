require 'helper'
require 'fluent/test/driver/output'
require 'fluent/test/helpers'
require 'cgi'
require 'uri'

class IkachanOutputTest < Test::Unit::TestCase
  include Fluent::Test::Helpers

  IKACHAN_TEST_LISTEN_PORT = 4979

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

  # Please notice that the line feed is "\n" in fluentd config file, not "\\n" as belows:
  CONFIG_LINE_FEED = %[
    host localhost
    channel morischan
    message out_ikachan: %s [%s] %s\\nRETURN
    out_keys tag,time,msg
    privmsg_message out_ikachan: %s [%s] %s\\nRETURN
    privmsg_out_keys tag,time,msg
    time_key time
    time_format %Y/%m/%d %H:%M:%S
    tag_key tag
  ]

  CONFIG_POST_PER_LINE_FALSE = %[
    host localhost
    channel morischan
    message out_ikachan: %s [%s] %s\\nRETURN
    out_keys tag,time,msg
    privmsg_message out_ikachan: %s [%s] %s\\nRETURN
    privmsg_out_keys tag,time,msg
    time_key time
    time_format %Y/%m/%d %H:%M:%S
    tag_key tag
    post_per_line false
  ]

  CONFIG_HOST_NIL = %[
    channel morischan
    message out_ikachan: %s [%s] %s
    out_keys tag,time,msg
    time_key time
    time_format %Y/%m/%d %H:%M:%S
    tag_key tag
  ]

  CONFIG_INVALID_BASE_URI = %[
    base_uri http://localhost:4979/ikachan
    channel morischan
    message out_ikachan: %s [%s] %s
    out_keys tag,time,msg
    time_key time
    time_format %Y/%m/%d %H:%M:%S
    tag_key tag
  ]

  CONFIG_BASE_URI = %[
    base_uri http://localhost:4979/ikachan/
    channel morischan
    message out_ikachan: %s [%s] %s
    out_keys tag,time,msg
    time_key time
    time_format %Y/%m/%d %H:%M:%S
    tag_key tag
  ]

  CONFIG_BASIC_SSL = %[
    host localhost
    ssl true
    verify_ssl false
    channel morischan
    message out_ikachan: %s [%s] %s
    out_keys tag,time,msg
    time_key time
    time_format %Y/%m/%d %H:%M:%S
    tag_key tag
  ]

  # base_uri starts with http, but ssl option is true
  CONFIG_INVALID_SSL_1 = %[
    base_uri http://localhost/
    ssl true
    channel morischan
    message out_ikachan: %s [%s] %s
    out_keys tag,time,msg
    time_key time
    time_format %Y/%m/%d %H:%M:%S
    tag_key tag
  ]

  # base_uri starts with https, but ssl option is false
  CONFIG_INVALID_SSL_2 = %[
    base_uri https://localhost/
    ssl false
    channel morischan
    message out_ikachan: %s [%s] %s
    out_keys tag,time,msg
    time_key time
    time_format %Y/%m/%d %H:%M:%S
    tag_key tag
  ]

  CONFIG_AUTO_ENABLE_SSL = %[
    base_uri https://localhost/
    channel morischan
    message out_ikachan: %s [%s] %s
    out_keys tag,time,msg
    time_key time
    time_format %Y/%m/%d %H:%M:%S
    tag_key tag
  ]

  def create_driver(conf=CONFIG)
    Fluent::Test::Driver::Output.new(Fluent::Plugin::IkachanOutput).configure(conf)
  end

  def test_configure
    d = create_driver
    assert_equal '#morischan', d.instance.channel
    assert_equal 'http://localhost:4979/', d.instance.base_uri
    assert_equal false, d.instance.ssl
    d = create_driver(CONFIG_NOTICE_ONLY)
    assert_equal '#morischan', d.instance.channel
    d = create_driver(CONFIG_PRIVMSG_ONLY)
    assert_equal '#morischan', d.instance.channel
    d = create_driver(CONFIG_LINE_FEED)
    assert_equal '#morischan', d.instance.channel
    d = create_driver(CONFIG_POST_PER_LINE_FALSE)
    assert_equal '#morischan', d.instance.channel
    assert_raise Fluent::ConfigError do
      create_driver(CONFIG_HOST_NIL)
    end
    assert_raise Fluent::ConfigError do
      create_driver(CONFIG_INVALID_BASE_URI)
    end
    d = create_driver(CONFIG_BASE_URI)
    assert_equal '#morischan', d.instance.channel
    assert_equal 'http://localhost:4979/ikachan/', d.instance.base_uri
    d = create_driver(CONFIG_BASIC_SSL)
    assert_equal '#morischan', d.instance.channel
    assert_raise Fluent::ConfigError do
      create_driver(CONFIG_INVALID_SSL_1)
    end
    assert_raise Fluent::ConfigError do
      create_driver(CONFIG_INVALID_SSL_2)
    end
    d = create_driver(CONFIG_AUTO_ENABLE_SSL)
    assert_equal '#morischan', d.instance.channel
    assert_equal true, d.instance.ssl
  end

  # CONFIG = %[
  #   host localhost
  #   channel morischan
  #   message out_ikachan: %s [%s] %s
  #   out_keys tag,time,msg
  #   privmsg_message out_ikachan: %s [%s] %s
  #   privmsg_out_keys tag,time,msg
  #   time_key time
  #   time_format %Y/%m/%d %H:%M:%S
  #   tag_key tag
  # ]
  def test_notice_and_privmsg
    d = create_driver
    time = event_time
    ts = Time.at(time.to_r).strftime(d.instance.time_format)
    d.run(default_tag: 'test') do
      d.feed(time, {'msg' => "both notice and privmsg message from fluentd out_ikachan: testing now"})
      d.feed(time, {'msg' => "both notice and privmsg message from fluentd out_ikachan: testing second line"})
    end

    assert_equal 4, @posted.length

    assert_equal 'notice', @posted[0][:method]
    assert_equal '#morischan', @posted[0][:channel]
    assert_equal "out_ikachan: test [#{ts}] both notice and privmsg message from fluentd out_ikachan: testing now", @posted[0][:message]

    assert_equal 'privmsg', @posted[1][:method]
    assert_equal '#morischan', @posted[1][:channel]
    assert_equal "out_ikachan: test [#{ts}] both notice and privmsg message from fluentd out_ikachan: testing now", @posted[1][:message]

    assert_equal 'notice', @posted[2][:method]
    assert_equal '#morischan', @posted[2][:channel]
    assert_equal "out_ikachan: test [#{ts}] both notice and privmsg message from fluentd out_ikachan: testing second line", @posted[2][:message]
    assert_equal 'privmsg', @posted[3][:method]
    assert_equal '#morischan', @posted[3][:channel]
    assert_equal "out_ikachan: test [#{ts}] both notice and privmsg message from fluentd out_ikachan: testing second line", @posted[3][:message]
  end

  # CONFIG_NOTICE_ONLY = %[
  #   host localhost
  #   channel morischan
  #   message out_ikachan: %s [%s] %s
  #   out_keys tag,time,msg
  #   time_key time
  #   time_format %Y/%m/%d %H:%M:%S
  #   tag_key tag
  # ]
  def test_notice_only
    d = create_driver(CONFIG_NOTICE_ONLY)
    time = event_time
    ts = Time.at(time.to_r).strftime(d.instance.time_format)
    d.run(default_tag: 'test') do
      d.feed(time, {'msg' => "notice message from fluentd out_ikachan: testing now"})
      d.feed(time, {'msg' => "notice message from fluentd out_ikachan: testing second line"})
    end

    assert_equal 2, @posted.length

    assert_equal 'notice', @posted[0][:method]
    assert_equal '#morischan', @posted[0][:channel]
    assert_equal "out_ikachan: test [#{ts}] notice message from fluentd out_ikachan: testing now", @posted[0][:message]

    assert_equal 'notice', @posted[1][:method]
    assert_equal '#morischan', @posted[1][:channel]
    assert_equal "out_ikachan: test [#{ts}] notice message from fluentd out_ikachan: testing second line", @posted[1][:message]
  end

  # CONFIG_PRIVMSG_ONLY = %[
  #   host localhost
  #   channel morischan
  #   privmsg_message out_ikachan: %s [%s] %s
  #   privmsg_out_keys tag,time,msg
  #   time_key time
  #   time_format %Y/%m/%d %H:%M:%S
  #   tag_key tag
  # ]
  def test_privmsg_only
    d = create_driver(CONFIG_PRIVMSG_ONLY)
    time = event_time
    ts = Time.at(time.to_r).strftime(d.instance.time_format)
    d.run(default_tag: 'test') do
      d.feed({'msg' => "privmsg message from fluentd out_ikachan: testing now"})
      d.feed({'msg' => "privmsg message from fluentd out_ikachan: testing second line"})
    end

    assert_equal 2, @posted.length

    assert_equal 'privmsg', @posted[0][:method]
    assert_equal '#morischan', @posted[0][:channel]
    assert_equal "out_ikachan: test [#{ts}] privmsg message from fluentd out_ikachan: testing now", @posted[0][:message]

    assert_equal 'privmsg', @posted[1][:method]
    assert_equal '#morischan', @posted[1][:channel]
    assert_equal "out_ikachan: test [#{ts}] privmsg message from fluentd out_ikachan: testing second line", @posted[1][:message]
  end

  # CONFIG = %[
  #   host localhost
  #   channel morischan
  #   message out_ikachan: %s [%s] %s\nRETURN
  #   out_keys tag,time,msg
  #   privmsg_message out_ikachan: %s [%s] %s\nRETURN
  #   privmsg_out_keys tag,time,msg
  #   time_key time
  #   time_format %Y/%m/%d %H:%M:%S
  #   tag_key tag
  # ]
  def test_line_feed
    d = create_driver(CONFIG_LINE_FEED)
    time = event_time
    ts = Time.at(time.to_r).strftime(d.instance.time_format)
    d.run(default_tag: 'test') do
      d.feed(time, {'msg' => "both notice and privmsg message from fluentd out_ikachan: testing now\ntesting second line"})
    end

    assert_equal 6, @posted.length

    i = 0
    assert_equal 'notice', @posted[i][:method]
    assert_equal '#morischan', @posted[i][:channel]
    assert_equal "out_ikachan: test [#{ts}] both notice and privmsg message from fluentd out_ikachan: testing now", @posted[i][:message]

    i += 1
    assert_equal 'notice', @posted[i][:method]
    assert_equal '#morischan', @posted[i][:channel]
    assert_equal "testing second line", @posted[i][:message]

    i += 1
    assert_equal 'notice', @posted[i][:method]
    assert_equal '#morischan', @posted[i][:channel]
    assert_equal "RETURN", @posted[i][:message]

    i += 1
    assert_equal 'privmsg', @posted[i][:method]
    assert_equal '#morischan', @posted[i][:channel]
    assert_equal "out_ikachan: test [#{ts}] both notice and privmsg message from fluentd out_ikachan: testing now", @posted[i][:message]

    i += 1
    assert_equal 'privmsg', @posted[i][:method]
    assert_equal '#morischan', @posted[i][:channel]
    assert_equal "testing second line", @posted[i][:message]

    i += 1
    assert_equal 'privmsg', @posted[i][:method]
    assert_equal '#morischan', @posted[i][:channel]
    assert_equal "RETURN", @posted[i][:message]
  end

  # CONFIG_POST_PER_LINE_FALSE = %[
  #   host localhost
  #   channel morischan
  #   message out_ikachan: %s [%s] %s\\nRETURN
  #   out_keys tag,time,msg
  #   privmsg_message out_ikachan: %s [%s] %s\\nRETURN
  #   privmsg_out_keys tag,time,msg
  #   time_key time
  #   time_format %Y/%m/%d %H:%M:%S
  #   tag_key tag
  #   post_per_line false
  # ]
  def test_post_per_line_false
    d = create_driver(CONFIG_POST_PER_LINE_FALSE)
    time = event_time
    ts = Time.at(time.to_r).strftime(d.instance.time_format)
    d.run(default_tag: 'test') do
      d.feed(time, {'msg' => "both notice and privmsg message from fluentd out_ikachan: testing now\ntesting second line"})
    end

    assert_equal 2, @posted.length

    i = 0
    assert_equal 'notice', @posted[i][:method]
    assert_equal '#morischan', @posted[i][:channel]
    assert_equal "out_ikachan: test [#{ts}] both notice and privmsg message from fluentd out_ikachan: testing now\ntesting second line\nRETURN", @posted[i][:message]

    i += 1
    assert_equal 'privmsg', @posted[i][:method]
    assert_equal '#morischan', @posted[i][:channel]
    assert_equal "out_ikachan: test [#{ts}] both notice and privmsg message from fluentd out_ikachan: testing now\ntesting second line\nRETURN", @posted[i][:message]
  end

  # CONFIG_BASE_URI = %[
  #   base_uri http://localhost:4979/ikachan/
  #   channel morischan
  #   message out_ikachan: %s [%s] %s
  #   out_keys tag,time,msg
  #   time_key time
  #   time_format %Y/%m/%d %H:%M:%S
  #   tag_key tag
  # ]
  def test_base_uri
    with_base_path('/ikachan/') do
      d = create_driver(CONFIG_BASE_URI)
      time = event_time
      ts = Time.at(time.to_r).strftime(d.instance.time_format)
      d.run(default_tag: 'test') do
        d.feed(time, {'msg' => "notice message from fluentd out_ikachan: testing now"})
        d.feed(time, {'msg' => "notice message from fluentd out_ikachan: testing second line"})
      end

      assert_equal 2, @posted.length

      assert_equal 'notice', @posted[0][:method]
      assert_equal '#morischan', @posted[0][:channel]
      assert_equal "out_ikachan: test [#{ts}] notice message from fluentd out_ikachan: testing now", @posted[0][:message]

      assert_equal 'notice', @posted[1][:method]
      assert_equal '#morischan', @posted[1][:channel]
      assert_equal "out_ikachan: test [#{ts}] notice message from fluentd out_ikachan: testing second line", @posted[1][:message]
    end
  end

  # setup / teardown for servers
  def setup
    Fluent::Test.setup
    @posted = []
    @prohibited = 0
    @auth = false
    @mount = '/' # @mount 's first and last char should be '/'. it is for dummy server path handling
    @dummy_server_thread = Thread.new do
      srv = if ENV['VERBOSE']
              WEBrick::HTTPServer.new({:BindAddress => '127.0.0.1', :Port => IKACHAN_TEST_LISTEN_PORT})
            else
              logger = WEBrick::Log.new('/dev/null', WEBrick::BasicLog::DEBUG)
              WEBrick::HTTPServer.new({:BindAddress => '127.0.0.1', :Port => IKACHAN_TEST_LISTEN_PORT, :Logger => logger, :AccessLog => []})
            end
      begin
        srv.mount_proc('/') { |req,res| # /join, /notice, /privmsg
          # setup called before each test method. so @mount can not use for mount_proc.
          unless req.path =~ /^#{@mount}/
            res.status = 404
            next
          end
          # POST /join?channel=#channel&channel_keyword=keyword
          # POST /notice?channel=#channel&message=your_message
          # POST /privmsg?channel=#channel&message=your_message
          unless req.request_method == 'POST'
            res.status = 405
            res.body = 'request method mismatch'
            next
          end
          if @auth and req.header['authorization'][0] == 'Basic YWxpY2U6c2VjcmV0IQ==' # pattern of user='alice' passwd='secret!'    
            # ok, authorized
          elsif @auth
            res.status = 403
            @prohibited += 1
            next
          else
            # ok, authorization not required
          end

          if req.path == @mount
            res.status = 200
            next
          end

          unless req.path =~ /^#{@mount}(join|notice|privmsg)$/
            res.status = 404
            next
          end

          method = $1
          post_param = CGI.parse(req.body)

          if method == 'join'
            res.status = 200
            next
          end

          @posted.push({ :method => method, :channel => post_param['channel'].first, :message => post_param['message'].first})
          res.status = 200
        }
        srv.start
      ensure
        srv.shutdown
      end
    end
    # to wait completion of dummy server.start()
    require 'thread'
    cv = ConditionVariable.new
    watcher = Thread.new {
      connected = false
      while not connected
        begin
          get_content('localhost', IKACHAN_TEST_LISTEN_PORT, '/')
          connected = true
        rescue Errno::ECONNREFUSED
          sleep 0.1
        rescue StandardError => e
          p e
          sleep 0.1
        end
      end
      cv.signal
    }
    mutex = Mutex.new
    mutex.synchronize {
      cv.wait(mutex)
    }
  end

  def test_dummy_server
    d = create_driver
    host = d.instance.host
    port = d.instance.port
    client = Net::HTTP.start(host, port)

    header = {"Content-Type" => "application/x-www-form-urlencoded"}
    assert_equal '200', client.request_post('/', '', header).code
    assert_equal '200', client.request_post('/join', 'channel=#test', header).code

    assert_equal 0, @posted.size

    assert_equal '200', client.request_post('/notice', 'channel=#test&message=NOW TESTING', header).code
    assert_equal '200', client.request_post('/privmsg', 'channel=#test&message=NOW TESTING 2', header).code

    assert_equal 2, @posted.size

    assert_equal 'notice', @posted[0][:method]
    assert_equal '#test', @posted[0][:channel]
    assert_equal 'NOW TESTING', @posted[0][:message]

    @mount = '/ikachan/'
    assert_equal '404', client.request_post('/', '', header).code
    assert_equal '404', client.request_post('/join', 'channel=#test', header).code

    assert_equal '200', client.request_post('/ikachan/', '', header).code
    assert_equal '404', client.request_post('/ikachan/test', 'channel=#test', header).code
    assert_equal '200', client.request_post('/ikachan/join', 'channel=#test', header).code
  end

  def teardown
    @dummy_server_thread.kill
    @dummy_server_thread.join
  end
end
