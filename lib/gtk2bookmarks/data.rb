require 'net/http'
require 'uri'
require 'cgi'
require 'hpricot'
require 'timeout'

module Gtk2Bookmarks
class Data < Hash
  attr_accessor :exclude_tags, :timeout, :max_list, :min_list, :attenuation, :initial_tags

  SPLIT_BY = Regexp.new('[\W_]+')
  SMALL = 0.01

  def self.load(file,create=false)
    if File.exist?(file) then
       obj = nil
       File.open(file,'r'){|fh| obj = Marshal.load(fh) }
       return obj
    elsif create then
      return Data.new
    end
    raise "#{file} does not exist."
  end

  def get_tags(url,title,description,keywords)
    _tags = keywords.downcase.split(SPLIT_BY).uniq
    _tags += title.downcase.split(SPLIT_BY).uniq
    _tags += description.downcase.split(SPLIT_BY).uniq.delete_if{|w| @exclude_tags.include?(w)}
    _tags += url.downcase.split(SPLIT_BY).uniq
    _tags = _tags.uniq.delete_if{|a| a.length < 3}
    return _tags
  end

  def initialize
    super
    @exclude_tags = []
    @timeout = 15
    @max_list = 13
    @min_list = 3
    @attenuation = 0.8
    @initial_tags = []
  end

  def dump(file)
    File.rename(file,file+'.bak')	if File.exist?(file)
    self.each{|url,values|
      if values then
        hits = values[:hits]
        values[:hits] = @attenuation*hits if hits > SMALL # don't attenuate to zero
      end
    }
    File.open(file, 'w'){|fh| Marshal.dump(self, fh)}
  end

  def http_get(url,body=true)
    response = nil
    uri = URI.parse(url)
    Net::HTTP.start(uri.host,uri.port) do |http|
      path = uri.path || '/'; path = '/' if path == ''
      path_query = path + ((query = uri.query)? ('?'+query): '')
      Timeout.timeout(@timeout){
        $stderr.puts path_query if $trace
        response = (body)? http.get(path_query): http.head(path_query)
      }
    end
    if location = response.header['location'] then
      response.header['location'] = ('http://' + uri.host + location) if location=~/^\//
    end
    return response
  end

  def self.meta(doc,name)
    begin
      return CGI.unescapeHTML( doc.at("meta[@name='#{name}']")['content'].strip )
    rescue Exception
      return  ''
    end
  end

  def self.title(doc)
    begin
      CGI.unescapeHTML( (doc/'title').inner_html.strip )
    rescue Exception
      return ''
    end
  end

  def _store(url,body)
    doc		= Hpricot(body)/'head'
    title	= Data.title(doc)
    description	= Data.meta(doc,'description')
    keywords	= Data.meta(doc,'keywords')
    tags	= get_tags(url,title,description,keywords)
    if values = self[url] then
      values[:title]	= title
      values[:tags]	= tags
      # values[:hits]	+= 1.0 # it's just a reload... don't hit it
    else
      self[url] = {:title=>title, :tags=>tags, :hits=>1.0}
    end
  end

  def store(url)
    begin
      response = http_get(url)
      if (response.code=~/^2/) && (response.content_type=='text/html') then
        if (body = response.body) && (body.length > 0) then
          # store new information
          _store(url,body)
        else
          # don't overwrite
          self[url] = nil if !self.has_key?(url)
        end
      else
        # no longer a valid html url
        self[url] = nil
      end
      $stderr.puts "Store: #{url}\t=> #{self[url]}"	if $trace
      _chase(response.header['location']) # chasing moves...
    rescue Exception
      # don't overwrite, probably some network error
      self[url] = nil if !self.has_key?(url)
      Gtk2AppLib.puts_bang!(url)
      sleep(1) if $trace
    end
    self[url]
  end

  def _chase(location)
    store(location) if location && !self.has_key?(location)
  end

  def hit(url)
    begin
      if self.has_key?(url) then
        # have seen the url, just do a head check
        response = http_get(url,false)
        if response.code =~ /^2/ then
          if self[url] then
            # increment the hits
            self[url][:hits] += 1.0
          else
            # url is back? get the data
            store(url)
          end
        else
          # url no longer there, nil it!
          self[url] = nil
        end
        $stderr.puts "Hit: #{url}\t=> #{self[url]}"	if $trace
        _chase(response.header['location']) # chasing moves...
      else
        # have not seen this url, so get the full data
        store(url)
      end
    rescue Exception
      Gtk2AppLib.puts_bang!(url)
      sleep(1) if $trace
    end
  end

  def hits(url)
    self[url][:hits]
  end

  def top_tags(match1=nil)
    top = Hash.new

    count = 0
    self.keys.each{|url|
      next if !(values = self[url])
      count += 1
      _tags = values[:tags]
      if (!match1 || _tags.include?(match1)) then
        _tags.each{|tag|
          top[tag] = [0,0] if !top[tag]
          top[tag][0] += 1
          top[tag][1] += values[:hits]
        }
      end

    }

    # Sort by top used tags and...
    top = top.sort{|a,b| b[1][0]<=>a[1][0]}
    max = @max_list + (count/2)
    i = top.find_index{|a| a[1][0] < max}
    # ...chop off useless common ones
    top = top[i..-1]

    # Sort by top hits tags and...
    top = top.sort{|a,b| b[1][1]<=>a[1][1]}
    top = top.map{|a| a.first}
    # ...delete tags we don't want as per configuration.
    top.delete_if{|a| @exclude_tags.include?(a)}

    # Return top tag prepended with configuration choices.
    return @initial_tags + top
  end

  def path_links(tag1,tag2,maxout=@max_list)
    count = 0
    urls = []
    self.each{|url,values|
      next if !values || (values[:hits] <= 0.0)
      _tags = values[:tags]
      if _tags.include?(tag1) && _tags.include?(tag2) then
        count += 1 
        return nil if count > maxout
        urls.push([values[:title],url])
      end
    }
    return nil if count < @min_list
    return urls
  end

  def top_paths(maxout=@max_list)
    seen_path = {}
    count1 = 0
    self.top_tags.each{|tag1|
      count2 = 0
      self.top_tags(tag1).each{|tag2|
        key = [tag1,tag2].sort.join('-')
        next if seen_path[key] || (tag1 == tag2)
        seen_path[key] = true
        if links = path_links(tag1,tag2) then
          yield(tag1,tag2,links)
          count2 += 1
          break if count2 >= maxout
        end
      }
      count1 += 1
      break if count1 >= maxout
    }
  end
end
end
