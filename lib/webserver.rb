require "webserver/version"
require "socket"

class NotFoundError < StandardError
end

class ServerError < StandardError
end

class Response
  attr_reader :buffer

  def initialize
    @buffer = ""
  end

  def write(string)
    buffer << string
  end

  def to_s
    buffer
  end
end

class HTTPServer
  STATIC_ROOT = "public/"

  attr_reader :socket, :routes

  def initialize(host, port)
    @host = host
    @port = port
    @routes = {}
  end

  def add_route(route, &block)
    return false if route.nil?
    route_regex_string = route.gsub(/:[\w_-]+/, "([\\w_-]+)")
    route_regex_pattern = Regexp.new(route_regex_string)
    routes[route_regex_pattern] = block
    true
  end

  def start
    ::Socket.tcp_server_loop(@host, @port) do |session, client_addr|
      ::Thread.new do
        begin
          request = session.gets
          response = ::Response.new
          logging(request)
          route_handler_block, params = block_for_route(request)
          puts params
          raise NotFoundError if route_handler_block.nil?
          route_handler_block.call(request, response, *params)
          # Write success
          session.write("HTTP/1.1 200/OK\r\nContent-type:text/html\r\n\r\n")
          session.write(response.to_s)
        rescue NotFoundError
          session.write("HTTP/1.1 404/NOT FOUND\r\nContent-type:text/html\r\n\r\n")
          session.write("404 - Not Found")
        rescue Exception => e
          session.write("HTTP/1.1 500/SERVER ERROR\r\nContent-type:text/html\r\n\r\n")
          session.write("500 - Server Error")
          puts e.backtrace
        ensure
          session.close
        end
      end
    end
  end

private

  def block_for_route(request)
    route = route_from_request(request)
    routes.each do |regex_route, block|
      if matches = regex_route.match(route)
        return block, matches[1..-1]
      end
    end
    nil
  end

  def logging(request)
    puts "#{::Time.now} [] /#{route_from_request(request)}"
  end

  def route_from_request(request)
    trimmedrequest = request.gsub(/GET\ \//, '').gsub(/\ HTTP.*/, '')
    filename = trimmedrequest.chomp
  end

  def send_file(request, response)
    filename = route_from_request(request)
    filename += "index.html" if filename == ''
    content = ::File.read(STATIC_ROOT + filename)
    response.write(content)
  rescue ::Errno::ENOENT
    response.write("File not found")
  end

end

################################################################################
# Let's Play Around
################################################################################


server = ::HTTPServer.new('localhost', 3000)

# # /action_man
# server.add_route("action_man") do |request, response|
#   response.write("<h1>WOO!</h1>")
# end
#
# # /oh_no
# server.add_route("oh_no") do |request, response|
#   response.poop()
# end

# /users
server.add_route("users/:username/books/:book-id") do |request, response, username, book_id|
  response.write("<p style='color:red;'>#{username} wrote #{book_id}</p>")
end

server.start
