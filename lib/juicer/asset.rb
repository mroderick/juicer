#
# Assets are files used by CSS and JavaScript files. The Asset class provides
# tools for manipulating asset paths, such as rebasing, adding cache busters,
# and cycling asset hosts.
#
# Asset objects are most commonly created by <tt>Juicer::Asset::PathResolver#resolve</tt>
# which resolves include paths to file names. It is possible, however, to use
# the asset class directly:
#
#   Dir.pwd                                                        #=> "/home/christian/projects/mysite/design/css"
#   asset = Juicer::Asset.new "../images/logo.png"
#   asset.path                                                     #=> "../images/logo.png"
#   asset.rebase("~/projects/mysite/design").path                  #=> "images/logo.png"
#   asset.filename                                                 #=> "/home/christian/projects/mysite/design/images/logo.png"
#   asset.path(:cache_buster_type => :soft)                        #=> "../images/logo.png?jcb=1234567890"
#   asset.path(:cache_buster_type => :soft, :cache_buster => nil)  #=> "../images/logo.png?1234567890"
#   asset.path(:cache_buster => "bustIT")                          #=> "../images/logo.png?bustIT=1234567890"
#
#   asset = Juicer::Asset.new "../images/logo.png", :document_root #=> "/home/christian/projects/mysite"
#   asset.absolute_path(:cache_buster_type => :hard)               #=> "/images/logo-jcb1234567890.png"
#   asset.absolute_path(:host => "http://localhost")               #=> "http://localhost/images/logo.png"
#   asset.absolute_path(:host => "http://localhost",
#                       :cache_buster_type => :hard)               #=> "http://localhost/images/logo-jcb1234567890.png"
#
# Author::    Christian Johansen (christian@cjohansen.no)
# Copyright:: Copyright (c) 2009 Christian Johansen
# License::   BSD
#
class Juicer::Asset
  attr_reader :base, :hosts, :document_root

  @@scheme_pattern = %r{^[a-zA-Z]{3,5}://}

  #
  # Initialize asset at <tt>path</tt>. Accepts an optional hash of options:
  #
  # [<tt>:base</tt>]
  #     Base context from which asset is required. Given a <tt>path</tt> of
  #     <tt>../images/logo.png</tt> and a <tt>:base</tt> of <tt>/project/design/css</tt>,
  #     the asset file will be assumed to live in <tt>/project/design/images/logo.png</tt>
  #     Defaults to the current directory.
  # [<tt>:hosts</tt>]
  #     Array of host names that are served from <tt>:document_root</tt>. May also
  #     include scheme/protocol. If not, http is assumed.
  # [<tt>:document_root</tt>]
  #     The root directory for absolute URLs (ie, the server's document root). This
  #     option is needed when resolving absolute URLs that include a hostname as well
  #     as when generating absolute paths.
  #
  def initialize(path, options = {})
    @path = path
    @filename = nil
    @absolute_path = nil
    @relative_path = nil
    @path_has_host = @path =~ @@scheme_pattern
    @path_is_absolute = @path_has_host || @path =~ /^\//

    # Options
    @base = options[:base] || Dir.pwd
    @document_root = options[:document_root]

    hosts = options[:hosts]
    @hosts = hosts.nil? ? [] : [hosts].flatten.collect { |host| host_with_scheme(host) }
  end

  #
  # Returns absolute path calculated using the <tt>#document_root</tt>.
  # Optionally accepts a hash of options:
  #
  # [<tt>:host</tt>] Return fully qualified URL with this host name. May include
  #                  scheme/protocol. Default scheme is http.
  #
  # Raises an ArgumentException if no <tt>document_root</tt> has been set.
  #
  def absolute_path(options = {})
    return @absolute_path if @absolute_path

    # Pre-conditions
    raise ArgumentError.new("No document root set") if @document_root.nil?

    @absolute_path = filename.sub(%r{^#@document_root}, '').sub(/^\/?/, '/')
    @absolute_path = "#{host_with_scheme(options[:host])}#@absolute_path"
  end

  #
  # Return path relative to <tt>#base</tt>
  #
  def relative_path
    @relative_path ||= Pathname.new(filename).relative_path_from(Pathname.new(base)).to_s
  end

  alias path relative_path

  #
  # Return filename on disk. Requires the <tt>#document_root</tt> to be set if
  # original path was an absolute one.
  #
  # If asset path includes scheme/protocol and host, it can only be resolved if
  # a match is found in <tt>#hosts</tt>. Otherwise, an exeception is raised.
  #
  def filename
    return @filename if @filename

    # Pre-conditions
    raise ArgumentError.new("No document root set") if @path_is_absolute && @document_root.nil?
    raise ArgumentError.new("No hosts served from document root") if @path_has_hosts && @hosts.empty?

    path = strip_host(@path)
    raise ArgumentError.new("No matching host found for #{@path}") if path =~ @@scheme_pattern

    dir = @path_is_absolute ? document_root : base
    @filename = File.expand_path(File.join(dir, path))
  end

  #
  # Rebase path and return a new Asset object.
  #
  #   asset = Juicer::Asset.new "../images/logo.png", :base => "/var/www/public/stylesheets"
  #   asset2 = asset.rebase("/var/www/public")
  #   asset2.relative_path #=> "images/logo.png"
  #
  def rebase(base_path)
    path = Pathname.new(filename).relative_path_from(Pathname.new(base_path)).to_s

    Juicer::Asset.new(path,
                      :base => base_path,
                      :hosts => hosts,
                      :document_root => document_root)
  end

  #
  # Returns basename of filename on disk
  #
  def basename
    File.basename(filename)
  end

  #
  # Returns basename of filename on disk
  #
  def dirname
    File.dirname(filename)
  end

  #
  # Returns <tt>true</tt> if file exists on disk
  #
  def exists?
    File.exists?(filename)
  end

 private
  #
  # Strip known hosts from path
  #
  def strip_host(path)
    hosts.each do |host|
      return path if path !~ @@scheme_pattern

      path.sub!(%r{^#{host}}, '')
    end

    return path
  end

  #
  # Assures that a host has scheme/protocol and no trailing slash
  #
  def host_with_scheme(host)
    return host if host.nil?
    (host !~ @@scheme_pattern ? "http://#{host}" : host).sub(/\/$/, '')
  end
end
