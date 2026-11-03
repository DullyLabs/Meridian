# Meridian

A macOS app and desktop widget that compare up to five time zones hour by hour, like World Time Buddy. It needs no permissions or admin rights, only Xcode or its Command Line Tools to build.

```sh
make          # swift build, assemble and sign build/Meridian.app
make install  # copy to ~/Applications and open it
make test
make icon     # redraw Icon/AppIcon.icns
```

`make` signs with the first code-signing identity in your keychain, or ad hoc if you have none; `make SIGN_ID=-` forces ad hoc.

The app window's grid runs from midnight to midnight in the home zone, its first row. Defaults: My Location, London, New York, Tokyo, UTC. Click or drag across hours to select them, then right-click to copy the start time, or the start and end times, in every city, one city per line.

The desktop widget is a panel at desktop-icon level, not a WidgetKit widget, because macOS won't load WidgetKit extensions from ad hoc signed apps. Drag it anywhere; it shows the same cities and clock style as the window. Right-click it to open the window, hide it or quit. Meridian › Desktop Widget (⌘D) shows or hides it, and Meridian › Open at Login keeps it up after a restart; an ad hoc signed copy may need allowing once in System Settings › General › Login Items, which opens for you. Closing the window keeps the widget running and hides Meridian from the Dock until the window opens again.
