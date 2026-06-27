# Firefox - Setup

Firefox is a program that I will use on many operating systems. Many of the settings are cross compatible and automatically synched using [Firefox Sync](https://www.mozilla.org/en-US/firefox/sync/).

## Sync

Sign into Firefox Sync.

Open `about:preferences` and configure the following:

- Sync
    - Change device name
    - Manage Sync
        - Remove the following items
            - Passwords
            - Addresses
            - Credit cards
- Home
    - Firefox Home content
        - Uncheck everything except the following:
            - Shortcuts - 2 rows
            - Weather
            - Recent Activity - 4 rows
                - Checkmark all sub-items
            - Snippets
- Privacy & Security
    - Autofill
        - Save and fill addresses = Unchecked
        - Save and fill payment methods = Unchecked
    - Address Bar - Firefox Suggest
        - Uncheck Suggestions from sponsors
    - Website Advertising Preferences
        - Uncheck
- DNS over HTTPS
    - Off
        - I configure DoH at the OS-Level

## Show 1password Extension

Click the Extension Icon in the top left -> Right click 1password -> Pin to toolbar

## Customize toolbars

This section uses Firefox's builtin toolbar customization to configure the layout and appearance.

Hamberger Menu -> More Tools -> Customize Toolbar...

- Add Sidebars on the left-side of the URL bar, next to the Refresh button
- Move 1password to the left of the profile icon
- In the bottom left corner, checkmark 'Title Bar' OR Toolbars -> 'Menu Bar'
    - I have been enjoying Sideberry which displays the Tabs in a vertical list in the Sidebar. A later section of this document will add custom css to hide the 'Tab Toolbar' in favor of Sideberry. Showing the 'Title Bar' or 'Menu Bar' provides a location for the window controls (Minimize, Maximize, and Exit).
- Hide all extensions except 1password and Pocket.

## Custom styles

This section uses custom css to modify the appearance of Firefox. I know very little about this, but these are some good resources:

- firefox-csshacks [Github repository](https://github.com/MrOtherGuy/firefox-csshacks)
- /r/FirefoxCSS [Subreddit](https://www.reddit.com/r/FirefoxCSS/)

### Enable custom css

Go to `about:config` URL.

Set `toolkit.legacyUserProfileCustomizations.stylesheets` to `true`

### Locate Firefox profile

Go to `about:support` URL.

Find the `Profile Folder`.

### Add custom css

[Instructions](https://github.com/MrOtherGuy/firefox-csshacks#set-up-files-manually)

- Create folder named `chrome` inside 'Profile Folder'
- Create `userChrome.css` file in 'chrome' folder.
- Add the following css into that file

- [ ] Consider adding this to windows-settings and/or dotfile management

```css
/* Ensure either the Title Bar or Menu Bar is on before applying this css. */

/* Enable Title Bar or Menu Bar: */
/* Hamburger Menu -> More Tools -> Customize Toolbar... */
/* Checkmark 'Title Bar' Or Toolbars -> Menu Bar */
#TabsToolbar {
    visibility: collapse !important;
}
```

