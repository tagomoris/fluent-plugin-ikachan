require 'helper'

class IkachanOutputTest < Test::Unit::TestCase
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
    d = create_driver
    time = Time.now.to_i
    d.run do
      d.emit({'msg' => "both notice and privmsg message from fluentd out_ikachan: testing now"}, time)
      d.emit({'msg' => "both notice and privmsg message from fluentd out_ikachan: testing second line"}, time)
    end
  end

  def test_notice_only
    d = create_driver(CONFIG_NOTICE_ONLY)
    time = Time.now.to_i
    d.run do
      d.emit({'msg' => "notice message from fluentd out_ikachan: testing now"}, time)
      d.emit({'msg' => "notice message from fluentd out_ikachan: testing second line"}, time)
    end
  end

  def test_privmsg_only
    d = create_driver(CONFIG_PRIVMSG_ONLY)
    time = Time.now.to_i
    d.run do
      d.emit({'msg' => "privmsg message from fluentd out_ikachan: testing now"}, time)
      d.emit({'msg' => "privmsg message from fluentd out_ikachan: testing second line"}, time)
    end
  end

  # setup / teardown for servers
  def setup
    Fluent::Test.setup
    @posted = []
    @prohibited = 0
    @auth = false
    @dummy_server_thread = Thread.new do
      srv = if ENV['VERBOSE']
              WEBrick::HTTPServer.new({:BindAddress => '127.0.0.1', :Port => IKACHAN_TEST_LISTEN_PORT})
            else
              logger = WEBrick::Log.new('/dev/null', WEBrick::BasicLog::DEBUG)
              WEBrick::HTTPServer.new({:BindAddress => '127.0.0.1', :Port => IKACHAN_TEST_LISTEN_PORT, :Logger => logger, :AccessLog => []})
            end
      begin
        srv.mount_proc('/') { |req,res| # /join, /notice, /privmsg
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

          if req.path == '/'
            res.status = 200
            next
          end

          req.path =~ /^\/(join|notice|privmsg)$/
          method = $1
          post_param = Hash[*(req.body.split('&').map{|kv|kv.split('=')}.flatten)]

          if method == 'join'
            res.status = 200
            next
          end

          @posted.push({ :method => method, :channel => post_param['channel'], :message => post_param['message'] })
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

    assert_equal '200', client.request_post('/', '').code
    assert_equal '200', client.request_post('/join', 'channel=#test').code

    assert_equal 0, @posted.size

    assert_equal '200', client.request_post('/notice', 'channel=#test&message=NOW TESTING').code
    assert_equal '200', client.request_post('/privmsg', 'channel=#test&message=NOW TESTING 2').code

    assert_equal 2, @posted.size

    assert_equal 'notice', @posted[0][:method]
    assert_equal '#test', @posted[0][:channel]
    assert_equal 'NOW TESTING', @posted[0][:message]
  end

  def teardown
    @dummy_server_thread.kill
    @dummy_server_thread.join
  end
end
