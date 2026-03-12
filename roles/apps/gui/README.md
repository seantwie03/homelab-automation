# GUI

Install graphical software packages

## vid-play Chrome Bookmarklet

After running the playbook, add the bookmarklet to Chrome to enable one-click video
downloading and playback via mpv.

1. Right-click the Chrome bookmarks bar and select **Add page...**
2. Set **Name** to anything (e.g. `▶ vid-play`)
3. Set **URL** to the following (the entire thing — it is JavaScript, not a web address):
   ```
   javascript:(function(){var a=document.createElement('a');a.href='vid-play://'+encodeURIComponent(location.href);document.body.appendChild(a);a.click();document.body.removeChild(a);})()
   ```
4. Click **Save**

**Usage:** Navigate to any YouTube (or other video) page and click the bookmarklet.
The first time, Chrome will ask *"Open vid-play?"* — click **Open** and check
**Always allow** so it never prompts again. The video will download in the background
and open in mpv when ready.

