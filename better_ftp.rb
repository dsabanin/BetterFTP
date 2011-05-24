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
    initialize_caches
  end

  def initialize_caches
    @created_paths_cache = []
    @deleted_paths_cache = []
  end
  
  def connect(host, port = nil)
    port ||= @port || FTP_PORT
    if @debug_mode
      print "connect: ", host, ", ", port, "\n"
    end
    synchronize do
      initialize_caches
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
        rescue Net::FTPPermError, Net::FTPTempError => e
          # puts "Received #{e.class}: #{e.message}" if @debug_mode
        end
        @created_paths_cache << growing_path        
      else
        # puts "Cache says we already created #{growing_path.inspect}" if @debug_mode
      end
    end
  end
  
  def rm_r(path)
    return if @deleted_paths_cache.include?(path)
    @deleted_paths_cache << path
    if directory?(path) 
      chdir path

      begin
        files = nlst
        files.each {|file| rm_r "#{path}/#{file}"}
      rescue Net::FTPTempError
        # maybe all files were deleted already
      end
      
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