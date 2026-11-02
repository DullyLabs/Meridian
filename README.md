# Meridian

A macOS app and desktop widget that compare up to five time zones hour by hour, like World Time Buddy. It needs no permissions or admin rights, only the Xcode command line tools to build.

```sh
make          # swift build, assemble and sign build/Meridian.app
make install  # copy to ~/Applications and open it
make test
make icon     # redraw Icon/AppIcon.icns
```

`make` signs with the first code-signing identity in your keychain, or ad hoc if you have none; `make SIGN_ID=-` forces ad hoc.

The app window has the full 24-hour grid; its first row is the home zone. Defaults: My Location, London, New York, Tokyo, Sydney.

The desktop widget is a panel at desktop-icon level, not a WidgetKit widget, because macOS won't load WidgetKit extensions from ad hoc signed apps. Drag it anywhere; it shows the same cities as the window. Meridian › Desktop Widget (⌘D) hides it, and Meridian › Open at Login keeps it up after a restart. Closing the window keeps the widget running.
