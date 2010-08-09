Ruby-Gnome Bookmarks

A smarter search through all your bookmarks...
See the most relevant links to your query.
Automatically creates a tag path to your links.

The interface is very simple.
Simply add keywords, and the most relevant bookmarks appear.
And regardless of matches, gkt2bookmarks will always show at least some random choices.

To dock/iconyfy the app, select
"Dock" from the main menu (right-click most anywhere on the window on Linux).
Right-click on the icon (click on Maemo) to get the popup menu for a
top tags path to your links.

Note that gkt2bookmarks expects to find bookmarks in

	# Epiphany's bookmarks RDF file
	~/.gnome2/epiphany/bookmarks.rdf
	# Maybe you have a few here
	~/Desktop/bookmarks.html',
	# Maybe you copy your favorite bookmarks here
        ~/.gtk2bookmarks-2/bookmarks.html',
	# maemo has bookmarks here
	~/.bookmarks/MyBookmarks.xml
	# opera's
	~/.opera/bookmarks.adr
	# google-chrome's
	~/.config/google-chrome/Default/Bookmarks

You can edit these in

	~/.gtk2bookmarks-2/appconfig-1.0.rb

