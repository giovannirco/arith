require "test_helper"
require "net/http"
require "open3"
require "socket"
require "tempfile"
require "timeout"

# The real process: Puma with config/puma.rb, over a socket. It serves, it
# stops on SIGTERM within the grace period, and it refuses bad settings.
class ServerTest < ActiveSupport::TestCase
  ROOT = Rails.root.to_s

  def free_port
    server = TCPServer.new("127.0.0.1", 0)
    server.addr[1]
  ensure
    server&.close
  end

  def start(env = {})
    @port = free_port
    env = { "RAILS_ENV" => "test", "ARITH_ADDR" => "127.0.0.1:#{@port}", "COVERAGE" => nil }.merge(env)
    @output = Tempfile.new("puma")
    @pid = Process.spawn(env, "bin/puma", "-C", "config/puma.rb",
                         chdir: ROOT, out: @output.path, err: [ :child, :out ])
    Timeout.timeout(30) do
      sleep 0.1 until get("/healthz")&.code == "200"
    end
  end

  def get(path)
    Net::HTTP.get_response(URI("http://127.0.0.1:#{@port}#{path}"))
  rescue Errno::ECONNREFUSED, Errno::ECONNRESET, EOFError
    nil
  end

  # Seconds from SIGTERM to exit, and the exit status.
  def stop
    Process.kill("TERM", @pid)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    _, status = Timeout.timeout(20) { Process.wait2(@pid) }
    @pid = nil
    [ Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, status ]
  end

  teardown do
    if @pid
      Process.kill("KILL", @pid)
      Process.wait(@pid)
    end
    @output&.close!
  end

  test "serves, then stops when asked" do
    start
    response = get("/api/sum?term_one=4&term_two=1")
    assert_equal "200", response.code
    assert_equal '{"result":5}', response.body

    seconds, status = stop
    assert status.success?, File.read(@output.path)
    assert_operator seconds, :<, 5
  end

  test "gives up on a connection that never finishes" do
    start("ARITH_SHUTDOWN_TIMEOUT" => "1")
    # Half a request keeps a connection open.
    stuck = TCPSocket.new("127.0.0.1", @port)
    stuck.write("GET /healthz HTTP/1.1\r\nHost: x")
    sleep 0.2

    seconds, = stop
    assert_operator seconds, :<, 10
  ensure
    stuck&.close
  end

  test "a bad setting stops it before it listens" do
    output, status = Open3.capture2e({ "RAILS_ENV" => "test", "ARITH_LOG_FORMAT" => "yaml", "COVERAGE" => nil },
                                     "bin/puma", "-C", "config/puma.rb", chdir: ROOT)
    assert_not status.success?
    assert_includes output, 'arith: ARITH_LOG_FORMAT="yaml" is not valid: expected json or text'
  end
end
