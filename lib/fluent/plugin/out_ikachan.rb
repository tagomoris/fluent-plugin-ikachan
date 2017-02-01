require 'fluent/plugin/output'

require 'net/http'
require 'uri'

class Fluent::Plugin::IkachanOutput < Fluent::Plugin::Output
  Fluent::Plugin.register_output('ikachan', self)

  config_param :host, :string, default: nil
  config_param :port, :integer, default: 4979
  config_param :base_uri, :string, default: nil
  config_param :ssl, :bool, default: nil
  config_param :verify_ssl, :bool, default: false
  config_param :channel, :string
  config_param :message, :string, default: nil
  config_param :out_keys, :string, default: ""
  config_param :privmsg_message, :string, default: nil
  config_param :privmsg_out_keys, :string, default: ""
  config_param :time_key, :string, default: nil
  config_param :time_format, :string, default: nil
  config_param :tag_key, :string, default: 'tag'
  config_param :post_per_line, :bool, default: true

  def configure(conf)
    super

    if @base_uri.nil?
      if @host.nil? or @port.nil?
        raise Fluent::ConfigError, 'If `base_uri is nil, both `host` and `port` must be specifed'
      end
      # if only specifed "ssl true", scheme is https
      scheme = @ssl == true ? "https" : "http"
      @base_uri = "#{scheme}://#{@host}:#{@port}/"
    end

    unless @base_uri =~ /\/$/
      raise Fluent::ConfigError, '`base_uri` must be end `/`'
    end

    # auto enable ssl option by base_uri scheme if ssl is not specifed
    if @ssl.nil?
      @ssl = @base_uri =~ /^https:/ ? true : false
    end

    if ( @base_uri =~ /^https:/ and @ssl == false ) || ( @base_uri =~ /^http:/ and @ssl == true )
      raise Fluent::ConfigError, 'conflict `base_uri` scheme and `ssl`'
    end

    @channel = '#' + @channel

    @join_uri = URI.join(@base_uri, "join")
    @notice_uri = URI.join(@base_uri, "notice")
    @privmsg_uri = URI.join(@base_uri, "privmsg")

    @out_keys = @out_keys.split(',')
    @privmsg_out_keys = @privmsg_out_keys.split(',')

    if @message.nil? and @privmsg_message.nil?
      raise Fluent::ConfigError, "Either 'message' or 'privmsg_message' must be specifed."
    end

    begin
      @message % (['1'] * @out_keys.length) if @message
    rescue ArgumentError
      raise Fluent::ConfigError, "string specifier '%s' and out_keys specification mismatch"
    end

    begin
      @privmsg_message % (['1'] * @privmsg_out_keys.length) if @privmsg_message
    rescue ArgumentError
      raise Fluent::ConfigError, "string specifier '%s' of privmsg_message and privmsg_out_keys specification mismatch"
    end

    if @time_key
      if @time_format
        f = @time_format
        tf = Fluent::TimeFormatter.new(f, true) # IRC notification is formmatted as localtime only...
        @time_format_proc = tf.method(:format)
        @time_parse_proc = Proc.new {|str| Time.strptime(str, f).to_i }
      else
        @time_format_proc = Proc.new {|time| time.to_s }
        @time_parse_proc = Proc.new {|str| str.to_i }
      end
    end
  end

  def start
    super
    res = http_post_request(@join_uri, {'channel' => @channel})
    if res.is_a?(Net::HTTPSuccess)
      # ok
    elsif res.is_a?(Net::HTTPForbidden) and res.body == "joinned channel: #{@channel}"
      # ok
    else
      raise Fluent::ConfigError, "failed to connect ikachan server #{@host}:#{@port}"
    end
  end

  def process(tag, es)
    posts = []

    es.each do |time,record|
      if @message
        posts << [:notice, evaluate_message(@message, @out_keys, tag, time, record)]
      end
      if @privmsg_message
        posts << [:privmsg, evaluate_message(@privmsg_message, @privmsg_out_keys, tag, time, record)]
      end
    end

    posts.each do |type, msg|
      uri = (type == :privmsg ? @privmsg_uri : @notice_uri)
      begin
        if @post_per_line
          msg.split("\n").each do |m|
            http_post_request(uri, {'channel' => @channel, 'message' => m})
          end
        else
          http_post_request(uri, {'channel' => @channel, 'message' => msg})
        end
      rescue => e
        log.warn "failed to send notice", host: @host, port: @port, channel: @channel, message: msg, error: e
      end
    end
  end

  private

  def evaluate_message(message, out_keys, tag, time, record)
    values = out_keys.map do |key|
      case key
      when @time_key
        @time_format_proc.call(time)
      when @tag_key
        tag
      else
        record[key].to_s
      end
    end

    (message % values).gsub(/\\n/, "\n")
  end

  def http_post_request(uri, params)
    http = Net::HTTP.new(uri.host, uri.port)
    if @ssl
      http.use_ssl = true
      unless @verify_ssl
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
    end
    req = Net::HTTP::Post.new(uri.path)
    req.set_form_data(params)
    http.request req
  end

end
