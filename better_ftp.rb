require 'net/ftp'

class BetterFTP < Net::FTP

  attr_accessor :port
  attr_accessor :public_ip
  alias_method  :cd, :chdir
  attr_reader :home
  
  def initialize(host = nil, user = nil, passwd = nil, acct = nil)
    super
    @host = host
    @user = user
    @passwd = passwd
    @acct = acct
    @home = self.pwd
    @created_paths_cache = []
  end
  
  def connect(host, port = nil)
    port ||= @port || FTP_PORT
    if @debug_mode
      print "connect: ", host, ", ", port, "\n"
    end
    synchronize do
      @created_paths_cache = []      
      @sock = open_socket(host, port)
      voidresp
    end
  end

  def reconnect!
    if @host
      connect(@host)
      if @user
        login(@user, @passwd, @acct)
      end
    end
  end
  
  def directory?(path)
    chdir(path)
    
    return true
  rescue Net::FTPPermError
    return false
  end
  
  def file?(path)
    chdir(File.dirname(path))

    begin
      size(path)
      return true
    rescue Net::FTPPermError
      return false
    end
  end
  
  def mkdir_p(dir)
    parts = dir.split("/")
    if parts.first == "~"
      growing_path = ""
    else
      growing_path = "/"
    end
    for part in parts
      next if part == ""
      if growing_path == ""
        growing_path = part
      else
        growing_path = File.join(growing_path, part)
      end
      unless @created_paths_cache.include?(growing_path)
        # puts "Creating #{growing_path.inspect}" if @debug_mode
        begin
          mkdir(growing_path)
          chdir(growing_path)
        rescue Net::FTPPermError => e
          # puts "Received #{e.class}: #{e.message}" if @debug_mode
        end
        @created_paths_cache << growing_path        
      else
        # puts "Cache says we already created #{growing_path.inspect}" if @debug_mode
      end
    end
  end
  
  def rm_r(path)
    if directory?(path) 
      chdir path

      files = nlst
      files.each {|file| rm_r "#{path}/#{file}"}

      rmdir path
    else
      rm(path)
    end
  end
  
  def rm(path)
    chdir File.dirname(path)
    delete File.basename(path)
  end

private

  def makeport
    sock = TCPServer.open(@sock.addr[3], 0)
    port = sock.addr[1]
    host = @public_ip || sock.addr[3]
    resp = sendport(host, port)
    return sock
  end

end