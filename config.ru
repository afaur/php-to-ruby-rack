require 'rack'
require 'rack/server'
require 'rack/request'

# We re-open the request class to add the subdomains method
module Rack
  class Request
    def subdomains(tld_len=1) # we set tld_len to 1, use 2 for co.uk or similar
      # cache the result so we only compute it once.
      @env['rack.env.subdomains'] ||= lambda {
        # check if the current host is an IP address, if so return an empty array
        return [] if (host.nil? || /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.match(host))
        host.split('.')[0...(1 - tld_len - 2)] # pull everything except the TLD
      }.call
    end
  end
end

class RequestHandler

  attr_accessor :sd, :host, :uri, :qs, :ptags, :zone, :site

  def initialize(request, env)

    @sd     = request.subdomains.join("<br/>") || nil
    @host   = env['HTTP_HOST']
    @uri    = env['REQUEST_URI']
    @qs     = Rack::Utils.parse_nested_query(env['QUERY_STRING'])

    get_zone_and_ptags()
    get_subdomain()

  end

  def get_zone_and_ptags

    if @qs['zone']
      @zone = @qs['zone']
    else
      @zone = 'rect'
    end

    if @qs['ptags']
      @ptags = @qs['ptags']
    else
      @ptags = nil
    end

  end

  def get_subdomain

    if @sd
      @sd = @sd
      puts "Current subdomain is #{@sd}"
    else
      @sd = 'vitals'
      puts "No subdomain, setting to 'vitals'"
    end

    if @qs['site']
      @site = @qs['site']
    else
      @site = @sd
    end

  end

end

class EnvInspector
  def self.call(env)
    request = Rack::Request.new env
    handle = RequestHandler.new(request, env)

    html_content = %Q~
    <!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
    <html lang="en">
      <head>
        <meta http-equiv="content-type" content="text/html; charset=utf-8">
        <meta name="ROBOTS" content="NOINDEX, NOFOLLOW">
        <title>Advertisement</title>

        <script type='text/javascript'>
          var googletag = googletag || {};
          googletag.cmd = googletag.cmd || [];
          (function() {
          var gads = document.createElement('script');
          gads.async = true;
          gads.type = 'text/javascript';
          var useSSL = 'https:' == document.location.protocol;
          gads.src = (useSSL ? 'https:' : 'http:') +
          '//www.googletagservices.com/tag/js/gpt.js';
          var node = document.getElementsByTagName('script')[0];
          node.parentNode.insertBefore(gads, node);
          })();
        </script>

        <script type='text/javascript'>
          googletag.cmd.push(function() {
            var mapLeaderAd = googletag.sizeMapping().
                  addSize([760, 600], [728, 90]). //tablet
                  addSize([1050, 200], [728, 90]). // Desktop
                  addSize([0, 0], [[300, 50],[320, 50]]). // Fits browsers of any size smaller than 760 x 600
                  build();

            var mapRectangleAd = googletag.sizeMapping().
              addSize([960, 600], [[300, 250],[300, 600]]). //tablet
              addSize([1050, 200], [[300, 250],[300, 600],[300, 1050]]). // Desktop
              addSize([0, 0], [300, 250]). // Fits browsers of any size smaller than 900 x 600
              build();
    ~

    extra_content = ''

    if handle.zone == 'rect'
      extra_content = extra_content + "window.rectangle_unit = googletag.defineSlot('/8905/" + handle.site + "/profile', [[300, 250],[300, 600],[300, 1050]], 'rectangle').addService(googletag.pubads()).setCollapseEmptyDiv(true).setTargeting('pos', '1').defineSizeMapping(mapRectangleAd);"
    elsif handle.zone == 'leader'
      extra_content = extra_content + "window.leaderboard_unit = googletag.defineSlot('/8905/" + handle.site + "/profile', [728, 90], 'leaderboard').addService(googletag.pubads()).setCollapseEmptyDiv(true).setTargeting('pos', '1').defineSizeMapping(mapLeaderAd);"
    end

    if handle.ptags
      extra_content = extra_content + "googletag.pubads().setTargeting(\"ptag\", \"" + handle.ptags + "\");"
    end

    extra_content = extra_content + "googletag.pubads().enableSingleRequest(); googletag.enableServices(); }); </script> </head> <body>"

    if handle.zone == 'leader'
      extra_content = extra_content + "<div class=\"col-md-10\" id=\"leaderboard\"> <script type='text/javascript'> <!-- googletag.cmd.push(function() { googletag.display('leaderboard'); }); // --> </script> </div>"
    elsif handle.zone == 'rect'
      extra_content = extra_content + "<div class=\"ad-unit-body1-ph\" id=\"rectangle\"> <script type='text/javascript'><!-- googletag.cmd.push(function() { googletag.display('rectangle'); }); // --></script> </div>"
    end

    extra_content = extra_content + "</body> </html>"

    body = html_content + extra_content

    [200, {'Content-Type' => 'text/html'}, [body]]
  end
end

run EnvInspector

