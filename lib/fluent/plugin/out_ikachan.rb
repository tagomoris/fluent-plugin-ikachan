class Fluent::IkachanOutput < Fluent::Output
  Fluent::Plugin.register_output('ikachan', self)

  config_param :host, :string
  config_param :port, :integer, :default => 4979
  config_param :channel, :string
  config_param :message, :string
  config_param :out_keys, :string
  config_param :time_key, :string, :default => nil
  config_param :time_format, :string, :default => nil
  config_param :tag_key, :string, :default => 'tag'

  def initialize
    super
    require 'net/http'
    require 'uri'
  end

  def configure(conf)
    super

    @channel = '#' + @channel
    @join_uri = URI.parse "http://#{@host}:#{@port}/join"
    @notice_uri = URI.parse "http://#{@host}:#{@port}/notice"

    @out_keys = conf['out_keys'].split(',')

    begin
      @message % (['1'] * @out_keys.length)
    rescue ArgumentError
      raise Fluent::ConfigError, "string specifier '%s' and out_keys specification mismatch"
    end

    if @time_key
      if @time_format
        f = @time_format
        tf = Fluent::TimeFormatter.new(f, @localtime)
        @time_format_proc = tf.method(:format)
        @time_parse_proc = Proc.new {|str| Time.strptime(str, f).to_i }
      else
        @time_format_proc = Proc.new {|time| time.to_s }
        @time_parse_proc = Proc.new {|str| str.to_i }
      end
    end
  end

  def start
    res = Net::HTTP.post_form(@join_uri, {'channel' => @channel})
    if res.code.to_i == 200
      # ok
    elsif res.code.to_i == 403 and res.body == "joinned channel: #{@channel}"
      # ok
    else
      raise Fluent::ConfigError, "failed to connect ikachan server #{@host}:#{@port}"
    end
  end

  def shutdown
  end

  def emit(tag, es, chain)
    messages = []

    es.each {|time,record|
      values = []
      last = @out_keys.length - 1

      values = @out_keys.map do |key|
        case key
        when @time_key
          @time_format_proc.call(time)
        when @tag_key
          tag
        else
          record[key].to_s
        end
      end
      messages.push (@message % values)
    }

    messages.each do |msg|
      begin
        res = Net::HTTP.post_form(@notice_uri, {'channel' => @channel, 'message' => msg})
      rescue
        $log.warn "out_ikachan: failed to send notice to #{@host}:#{@port}, #{@channel}, message: #{msg}"
      end
    end

    chain.next
  end

end
