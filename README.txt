Ruby-Gnome Bookmarks

A smarter search through your bookmarks...
See the most relevant links to your query.
Rediscover your burried bookmarks with random listings.

The interface is very simple.
Simply add keywords, and the most relevant bookmarks appear.
And regardless of matches, gkt2bookmarks will always show at least some random choices.

Primarily, gkt2bookmarks expects to find Epiphany's bookmarks in

	~/.gnome2/epiphany/bookmarks.rdf

But it can also read html files and obtain the links within to create bookmarks.
One is encouraged to edit one's configuration file in

	~/.gtk2bookmars-0.1.0/appconfig-?.?.rb

to populate BOOKMARK_FILES with the RDF, XML, and HTML files one wishes.
By default, gkt2bookmarks searches for and reads the (like) following files:

	~/.gnome2/epiphany/bookmarks.rdf
	~/.mozilla/firefox/*/bookmarks.html
	~/Desktop/*bookmarks*.html
	~/.bookmarks/*bookmarks*.xml

One can modify how the bookmarks are ranked according to the query.

The next available configurable option in configuration.rb is which web browser to remote control.
The first browser found is the one used, and one can alter the search order.
This is set in:

	~/.gtk2bookmars-0.1.0/configuration-?.?.rb

The application menu gives two options to dock the appliction, "Dock" and "Close".
"Close" actually destroys the window application, but leaves the ruby stub process running.
On reanimation, the bookmark files will be re-read.
"Dock" simply hides the window and maintain it's current state.
gtk2bookmarks does a "HEAD" request in the background to eliminate broken links from it's listing,
so this initiation overhead is eliminated if "Dock" is used.
