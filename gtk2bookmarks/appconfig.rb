# $Date: 2009/03/09 15:24:08 $
require 'find'

module Configuration
  # Number of bookmarks to show
  LIST_SIZE	= 12

  # Time to wait for a head request
  HTTP_TIMEOUT = 15

  ENTRY_OPTIONS = {:width=>500}.freeze

  # Bookmark files
  BOOKMARK_FILES = []

  # Epiphany's bookmarks RDF file
  epiphany_rdf = ENV['HOME']+'/.gnome2/epiphany/bookmarks.rdf'
  BOOKMARK_FILES.push( epiphany_rdf ) if File.exist?(epiphany_rdf)
  # RDF file in user space?
  # This gives the option to copy one's linux epiphany bookmarks on maemo.
  epiphany_rdf = UserSpace::DIRECTORY+'/bookmarks.rdf'
  BOOKMARK_FILES.push( epiphany_rdf ) if File.exist?(epiphany_rdf)

  # One can add to BOOKMARK_FILES <exports>.html files
  # see the code below for examples.

  home = ENV['HOME']
  # (older) Firefox's bookmarks HTML files
  mozilla = home+'/.mozilla'
  if File.exists?(mozilla) then
    Find.find(mozilla) do |file|
      if file =~ /\/bookmarks.html$/ then
        BOOKMARK_FILES.push(file)
      end
    end
  end
  # Exported bookmarks HTML files (in Desktop?)
  desktop = home+'/Desktop'
  if File.exist?(desktop) then
    Find.find(desktop) do |file|
      Find.prune if File.directory?(file) && !(file == desktop)
      if file =~ /\w*bookmarks\w*.html$/i then
        BOOKMARK_FILES.push(file)
      end
    end
  end
  # maemo/mocrob .boomarks files
  maemo_bookmarks = home+'/.bookmarks'
  if File.exist?(maemo_bookmarks) then
    Find.find(maemo_bookmarks) do |file|
      if file =~ /\w*bookmarks\w*.xml$/i then
        BOOKMARK_FILES.push(file)
      end
    end
  end

  $stderr.puts BOOKMARK_FILES if $trace

  # Image for link button
  IMAGE[:go]	= Gdk::Pixbuf.new(UserSpace::DIRECTORY+'/pngs/go.png')
  IMAGE[:click]	= Gdk::Pixbuf.new(UserSpace::DIRECTORY+'/pngs/click.png')
  # Close to icon
  MENU[:dock] = '_Dock'

  # Here one can customize how the rankings is done.
  def self.hits_valuation(bookmarks, query)
    # Split the search string, query, into individual words of at least three letters.
    # Note how the order is reversed, this is explained later, below...
    query_split = query.split(/\W+/).delete_if{|x| x.length<2}.reverse
    tokens = (query_split.length > 0)
    # These patterns will determine hits.
    # Case sensitive, any part of the string.
    rgxs = (tokens)? query_split.map{|x| Regexp.new(x)} : nil
    # Case insensitive, any part of the string.
    rgxis = (tokens)? query_split.map{|x| Regexp.new(x,Regexp::IGNORECASE)} : nil
    # Case insensitive, whole word match.
    rgxbs = (tokens)? query_split.map{|x| Regexp.new("\b#{x}\b",Regexp::IGNORECASE)} : nil
    bookmarks.each {|entry|
      # Initially seed with a random number 1>rand>0.
      # This will present the user with an initial random list
      # that may be appreciated by presenting links that might otherwise remain buried.
      entry[Bookmarks::SORT] = rand
      if tokens then
        # The variable bookmarks contains the page title, the link, and the tags.
        # Currently, tags are only available from epiphany, but
        # firefox's folders should become available as tags eventually.
        title = entry[Bookmarks::TITLE]
        link = entry[Bookmarks::LINK]
        tags = entry[Bookmarks::SUBJECT].join(' ')
        keywords = entry[Bookmarks::KEYWORDS].join(' ')
        # Note how these value tags hits the most,
        # followed by the title hits, then
        # least by url link hits.
        rgxs.each{|rgx|
          entry[Bookmarks::SORT] += 8 if tags=~rgx
          entry[Bookmarks::SORT] += 4 if title=~rgx
          entry[Bookmarks::SORT] += 2 if link=~rgx
          entry[Bookmarks::SORT] += 1 if keywords=~rgx
        }
        # ...here is why the order got reversed, above.
        # An increasing kicker, i, is a added making the first words in the query more relevant.
        i = 0
        rgxis.each{|rgxi|
          entry[Bookmarks::SORT] += 8+i if tags=~rgxi
          entry[Bookmarks::SORT] += 4+i if title=~rgxi
          entry[Bookmarks::SORT] += 2+i if link=~rgxi
          entry[Bookmarks::SORT] += 1+i if keywords=~rgxi
          i += 1
        }
        rgxbs.each{|rgxb|
          entry[Bookmarks::SORT] += 8 if tags=~rgxb
          entry[Bookmarks::SORT] += 4 if title=~rgxb
          entry[Bookmarks::SORT] += 2 if link=~rgxb
          entry[Bookmarks::SORT] += 1 if keywords=~rgxb
        }
        # Promotion/demotion base on head
        entry[Bookmarks::SORT] *= 1.1	if entry[Bookmarks::RESPONSE] && entry[Bookmarks::RESPONSE] =~ /^OK$/i
        entry[Bookmarks::SORT] *= 1.1	if entry[Bookmarks::RESPONSE] && entry[Bookmarks::RESPONSE] =~ /^Found$/i
      end
      entry[Bookmarks::SORT] *= 0.9	if entry[Bookmarks::RESPONSE].nil?
    }
    # Now boorkmarks can be sorted by its SORT value...
  end
end
