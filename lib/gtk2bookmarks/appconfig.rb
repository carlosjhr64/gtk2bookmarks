module Gtk2AppLib
module Configuration
  # where your bookmarks data will be saved
  DATA_DUMP_FILE = UserSpace::DIRECTORY+'/gtk2bookmarks.dat'

  # your imported bookmarks
  home = ENV['HOME'] 
  BOOKMARKS_FILES = [
	home+'/.gnome2/epiphany/bookmarks.rdf',				# Epiphany's bookmarks RDF file
 	home+'/Desktop/bookmarks.html',					# Maybe you have a few here
 	UserSpace::DIRECTORY+'/bookmarks.html',				# Maybe you copy your favorite bookmarks here
 	home+'/.bookmarks/MyBookmarks.xml',				# maemo has bookmarks here
 	home+'/.opera/bookmarks.adr',					# opera's
 	home+'/.config/google-chrome/Default/Bookmarks',		# google-chrome's
	]
  firefox = `ls #{home}/.mozilla/firefox/*.default/bookmarks.html`.strip.split(/\s+/).shift	# firefox's
  BOOKMARKS_FILES.push(firefox) if firefox

  # Gtk2Bookmarks will give the top tags, but
  # one can override with one's own initial tags.
  INITIAL_TAGS	= [] # ['weather','email'] # must be all lowercase and alphanumeric

  TOP_TAGS	= 8
  MAX_LIST	= 13
  MIN_LIST	= 3

  # Useless tags
  EXCLUDE_TAGS = [
	# Used in conjunctions
	"after", "also", "although", "and", "as",
	"because", "before", "both", "but", "by",
	"case",
	"either", "even",
	"for", "if", "in",
	"lest", "long",
	"much",
	"neither", "nor", "not",
	"once", "only", "or", # "order",
	"provided",
	"since", "so", "soon",
	"than", "that", "the", "though", "till", # "time",
	"unless", "until",
	"when", "whenever", "where", "wherever", "whether", "while",
	"yet",

	# possesives
	"i", "mine", "my",
	"you", "yours", "your",
	"he", "his",
	"she", "hers", "her",
	"it", "its",
	"we", "ours", "our",
	"they", "theirs", "their",

	# prepositions
	"aboard", "about", "above", "across", "after", "against", "along", "amid", "among", "anti", "around", "as", "at",
	"before", "behind", "below", "beneath", "beside", "besides", "between", "beyond", "but", "by",
	"concerning", "considering",
	"despite", "down", "during",
	"except", "excepting", "excluding",
	"following", "for", "from",
	"in", "inside", "into",
	"like",
	"minus",
	"near",
	"of", "off", "on", "onto", "opposite", "outside", "over",
	"past", "per", "plus",
	"regarding", "round",
	"save", "since",
	"than", "through", "to", "toward", "towards",
	"under", "underneath", "unlike", "until", "up", "upon",
	"versus", "via",
	"with", "within", "without",

	# demonstratives
	'this', 'that', 'these', 'those',

	# url terms
	'http','www', 'com', 'org', 'net', 'html', 'htm',

	# just generally useless and common
	'all', 'some', 'any', 'none',
	'best', 'worst',
	'less', 'least',
	'more', 'most',
	'many', 'much',
	].uniq

  # Time to wait for a get/head request
  HTTP_TIMEOUT = 15	# seconds

  # These are the color codes for search results
  LOW_THRESH_HOLD		= 2.0
  LOW_THRESH_HOLD_COLOR		= COLOR[:gray]
  HIGH_THRESH_HOLD		= 45.0
  HIGH_THRESH_HOLD_COLOR	= COLOR[:navy]
  DEFAULT_FG_COLOR		= COLOR[:black]

  WIDGET_OPTIONS[:button_focus_on_click] = false
  HILDON = (Gtk2AppLib::WRAPPER.to_s =~ /Hildon/)
  if HILDON then
    # Maemo Tweeks
    WIDGET_OPTIONS[:entry_font] = FONT[:large]
    WIDGET_OPTIONS[:label_font] = FONT[:large]
    WIDGET_OPTIONS[:padding] = 4
  end

  # Image for link button
  IMAGE[:reload]	= Gdk::Pixbuf.new(UserSpace::DIRECTORY+'/pngs/reload.png')
  IMAGE[:go2]		= Gdk::Pixbuf.new(UserSpace::DIRECTORY+'/pngs/go2.png')
  IMAGE[:search]	= Gdk::Pixbuf.new(UserSpace::DIRECTORY+'/pngs/search.png')
  IMAGE[:clear]		= Gdk::Pixbuf.new(UserSpace::DIRECTORY+'/pngs/clear.png')
  IMAGE[:down]		= Gdk::Pixbuf.new(UserSpace::DIRECTORY+'/pngs/down.png')

  # Dock to icon, don't use close.
  MENU[:dock] = '_Dock'

  # When the hits data is saved, it's attenuated by this factor (0 < ATTENUATION < 1).
  ATTENUATION = 0.8

  # The application needs a list of bookmark urls.
  # Configuration.bookmarks yields each url.
  # You can modify this list to exactly the bookmarks you want, but
  # must still do
  # 	seen = Configuration.bookmarks(seen={},mtime=Time.at(0))
  def self.bookmarks(seen={},mtime=Time.at(0))
    # Bookmark files
    # pattern of directories for which we'll spider
    url_match = Regexp.new('http://[^"<>\s\']+')
    BOOKMARKS_FILES.each{|fn|
      next if !File.exist?(fn) || !File.file?(fn) || (File.mtime(fn)<mtime)
      File.open(fn,'r'){|fh|
        fh.each{|line|
          # Giving up on parsing all these types of files...
          # Just want the url's
          begin
            while md = line.match(url_match) do
              url = md[0]
              # note that it's up to the iterator to update seen
              yield(url,seen) if !seen.has_key?(url)
              line = md.post_match
            end
          rescue Exception
            $stderr.puts line if $verbose
            Gtk2AppLib.puts_bang!(fn)
            sleep(1) if $trace
          end
        }
      }
    }
    return seen
  end

  # Here one can customize how the rankings is done.
  def self.hits_valuation(bookmarks, query, n)
    results = []
    # Split the search string, query, into individual words of at least two letters.
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
    bookmarks.each {|url,values|
      next if !values
      title = values[:title]
      result = [url,title,rand]
      # Initially seed with a random number 1>rand>0.
      # This will present the user with an initial random list
      # that may be appreciated by presenting links that might otherwise remain buried.
      if tokens then
        # The variable bookmarks contains the page title, the link, and the tags.
        # Currently, tags are only available from epiphany, but
        # firefox's folders should become available as tags eventually.
        link = url
        tags = values[:tags].join(' ')
        # Note how these value tags hits the most,
        # followed by the title hits, then
        # least by url link hits.
        rgxs.each{|rgx|
          result[2] += 8.0 if tags=~rgx
          result[2] += 4.0 if title=~rgx
          result[2] += 2.0 if link=~rgx
        }
        # ...here is why the order got reversed, above.
        # An increasing kicker, i, is a added making the first words in the query more relevant.
        i = 0
        rgxis.each{|rgxi|
          result[2] += 8.0+i if tags=~rgxi
          result[2] += 4.0+i if title=~rgxi
          result[2] += 2.0+i if link=~rgxi
          i += 1
        }
        rgxbs.each{|rgxb|
          result[2] += 8.0 if tags=~rgxb
          result[2] += 4.0 if title=~rgxb
          result[2] += 2.0 if link=~rgxb
        }
      end
      result[2] *= 2.0 / (1.0 + Math.exp(-values[:hits]))
      results.push(result)
    }
    # Now results can be sorted by its :sort value...
    return results.sort{|a,b| b[2]<=>a[2]}[0..(n-1)]
  end
end
end
