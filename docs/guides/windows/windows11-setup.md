# Windows 11

This document contains setup information for setting up Windows workstations. Follow the guide below. Part of the guide will be to clone the `windows-settings` repository and run `Set-SettingsSymlinks.ps1`.

## Install Windows 11

I do not want my stuff to be saved to OneDrive because I often use Linux which does not have a OneDrive client. This means I do not want my Desktop, Documents etc. to be inside OneDrive. Windows 11 has made this significantly more difficult to accomplish but one sure-fire way is to do an offline install. The steps below explain how to trick the Windows 11 installer to do an offline install.

- When you get to the 'Sign in with a Microsoft account' screen click `Sign In`.
- Use the email: `no@thankyou.com`
- Enter anything in the password field
- This should bring you to the 'Oops something went wrong' screen. When you click Next you will be allowed to create an offline account.
- Enter `sean` as the username.
- When choosing privacy settings, turn everything off
- Install Windows Updates.
- Reboot
- Manually uninstall as much bloat as possible
- Sign In to Windows Account
    - Open the Windows Store and Sign In.
        - When asked to sign in to all apps choose the tiny Microsoft Only link
    - Click the Library icon on the bottom left.
    - Update all apps.
- OneDrive (Optional) Until I have phased out OneDrive, it is quick to setup.
    - Click the OneDrive icon in the taskbar.
    - Click 'Sign In' to OneDrive.
    - Follow the prompts.
    - When asked which folders to sync **deselect them all!**


## Settings

- System
    - Display
        - Scale = 125%
        - Night light
            - Schedule night light = On
            - Set Hours
                - Turn on = 7:30 PM
                - Turn off = 4:30 AM
    - Notifications
        - Notifications = On
        - Do Not Disturb = On
            - Set Priority Notifications
                - Remove all except Snipping Tool and Clock
                  This is annoying because, only applications that have recently sent a notification are displayed.
                  This means, after I get an unwanted notification, I'll have to come in here and uncheck the application.
        - Notifications from apps and other senders
            - Uncheck All Except Snipping Tool
              This is the same as Priority Notifications above. Apps are only listed here after they have sent a notification.
            - Snipping Tool
                - If snipping tool is not in the list, take a snip with `Win+Shift+s` then it will appear in the list.
                - Show Notification in Notification Center = Uncheck
                - Play a sound when notification arrives = Off
        - Additional Settings
            - Uncheck everything
    - Multitasking
        - Snap windows
             - Show snap layout when I drag a window to the top of my screen = Unchecked
        - Show Microsoft Edge tabs when pressing Alt + Tab = Don't show tabs
    - Power (and Battery)
        - Screen and Sleep = Set everything to 15 minutes
    - Troubleshoot
        - Recommend Troubleshooter Preferences = Don't run any
    - Clipboard
        - Clipboard History = On
        - Sync across devices = Off
        - Suggested Actions = Off
    - For Developers
        - Developer Mode = On
            - This enables the ability for non-administrators to symbolically link files. These SymbolicLinks are used when setting up my dotfiles.
        - File Explorer
            - Show file extensions = On
            - Show hidden and system files = On
        - PowerShell
            - Change execution policy.... = On
- Bluetooth And Devices
    - Bluetooth = Off
    - Touchpad
        - Scrolling and Zoom
            - Scrolling Direction
                - Down motion scrolls down
        - Advanced Gestures
            - TODO: Change this to copy Niri?
            - Three-finger gestures
                - Tap = Middle mouse button
                - Swipe Up = Forward navigation
                - Swipe Down = Backward navigation
                - Swipe Left = Custom shortcut (Ctrl + Shift + Tab)
                - Swipe Right = Custom shortcut (Ctrl + Tab)
            - Four-finger gestures
                - Taps = Custom Shortcut (Win + Tab)
                - Swipe Up = Maximize a window
                - Swipe Down = Minimize a window
                - Swipe Left = Switch apps
                - Swipe Right = Switch apps
    - AutoPlay
        - Use AutoPlay for all media and devices = Off
- Network & Internet
    - Wi-Fi (or Ethernet if connected via Ethernet)
        - Private network = checked
- Personalization
    - Background
        - Set desktop background to a picture
    - Themes
        - Mouse Cursor
            - Pointers Tab
                - Scheme
                    - Windows Black (system scheme)
        - Desktop icon settings
            - Uncheck Recycle Bin
    - Lock screen
        - Personalize your lock screen = Picture (choose a picture)
        - Uncheck Get fun facts, tips, tricks, and more on your lock screen
        - Lock screen status = None
    - Start
        - Show recently added apps = Off
        - Show most used apps = On
        - Show recommendations for tips, shortcut,s news apps, and more = Off
        - Folders
            - Settings
            - File Explorer
            - Personal Folder
    - Taskbar
        - Taskbar items = All off except 'Task view'
        - Other system tray icons = All off except 'Windows Update Status'
        - Taskbar behaviors
            - Taskbar alignment = Left
            - Show badges on taskbar apps = Unchecked
            - Show flashing on taskbar apps = Unchecked
            - Share any window from my taskbar = Unchecked
- Apps
    - Startup = All off except DisplayLink, Microsoft OneDrive, Terminal, and Windows Security
- Accounts
    - Sign-in options
        - PIN = Setup PIN
        - Fingerprint = Setup fingerprint
    - Family
        - Allow Beth to sign in
- Time and language
    - Date and time
        - Time zone = Central Time
- Accessibility
    - Narrator
        - Keyboard shortcut for Narrator = Off
- Privacy and security
    - Windows Security
        - Open Windows Security
            - Settings (At the bottom)
                - Click Manage Notifications
                    - Get informational notifications = Off (Requires Admin)
    - General
        - Show me suggested content in the Settings app = Off
    - Inking and typing personalization
        - Custom inking and typing dictionary = Off
    - Diagnostics & feedback
        - Everything off
        - Feedback
            - Feedback Frequency = Never
    - Search permissions
        - More Settings
            - See content suggestion in the search box and in search home = Off

### Keyboard Settings

- Control Panel
    - Keyboard
        - Repeat delay: Shortest
        - Repeat rate: Fastest
        - Cursor blink rate: None

### Power Settings (Laptop Only)

- Hardware and Sound
    - Power Options
        - System Settings
            - When I close the lid: Do Nothing when Plugged In
            - Disable fast startup
        - Edit Plan Settings (Change when the computer sleeps)
            - Change Advanced Power Settings
                - Sleep
                 - Hibernate after
                    - On Battery = 300 (5 Hours)
                    - Plugged In = Never (0)


## Installing Applications

I am scaling back my use of winget because it is awkward for updates. Here is an example, I installed VSCode via winget. Then when I updated VSCode via winget, it uninstalled the old version, using the MSI, then reinstalled the new version. Compared to VSCode's built-in update mechanism, this took a long time and I was worred that my settings would get deleted during the uninstall. For now I am going to try this:

Any software that auto-updates (VSCode, PowerToys, browsers, etc.) will be installed manually. Yes, installing things manually is annoying, but since these apps auto-update it is a one-and-done situation. Also, it is better to let these apps use their own update mechanisms rather than having a package manager uninstall and reinstall them.

Any software that does NOT auto-update will be installed via scoop.

Any other software that does NOT auto-update and is not available in scoop (Display Link driver) will be installed via winget or manually.

### Display Link Drivers (Optional)

Install (Requires Admin)

```powershell
winget install "DisplayLink.GraphicsDriver" -s winget --accept-package-agreements --accept-source-agreements
```

### Firefox

Install

```powershell
winget install "Mozilla Firefox" -s msstore --accept-package-agreements --accept-source-agreements
```

[Configure](areas/homelab/firefox/setup.md)

### Scoop

Install scoop

```powershell
irm get.scoop.sh | iex
scoop install git sudo
```

### WSL2 (Requires Admin)

Install

```powershell
wsl --install
```

Reboot

Follow prompts to set `sean` as username

Ensure systemd is active

```powershell
systemctl list-units --type=service
```

Password-less Sudo

```sh
sudo EDITOR=vi visudo -f /etc/sudoers.d/$USER
```

Enter the following:

```conf
%sudo   ALL=(ALL:ALL)   NOPASSWD:ALL
```

Update packages

```sh
sudo apt update && sudo apt upgrade -y
```

Configure git

- [ ] Add .gitconfig to yadm

```sh
git config --global user.name = 'Sean Twie03'
git config --global user.email = 'email'
```

(If Nvidia GPU) Install CUDA Toolkit in WSL2

Install Nvidia GPU Drivers in Windows 11.

Check if the [Nvidia CUDA Toolkit Docs](https://docs.nvidia.com/cuda/wsl-user-guide/index.html#cuda-support-for-wsl-2)

```sh
sudo apt-key del 7fa2af80
wget https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-wsl-ubuntu.pinsudo mv cuda-wsl-ubuntu.pin /etc/apt/preferences.d/cuda-repository-pin-600
wget https://developer.download.nvidia.com/compute/cuda/12.3.2/local_installers/cuda-repo-wsl-ubuntu-12-3-local_12.3.2-1_amd64.deb
sudo dpkg -i cuda-repo-wsl-ubuntu-12-3-local_12.3.2-1_amd64.deb
sudo cp /var/cuda-repo-wsl-ubuntu-12-3-local/cuda-*-keyring.gpg /usr/share/keyrings/
sudo apt-get update
sudo apt-get -y install cuda-toolkit-12-3
```

Install Ollama

Review [Installation Script](https://github.com/ollama/ollama/blob/main/scripts/install.sh)

```sh
curl https://ollama.ai/install.sh | sh
```

### SSH

Create SSH keys in WSL2

```sh
ssh-keygen -t ed25519
[Enter]
# Create a password
# Repeat the password
```

Copy SSH Keys to Windows

```sh
# This only works if your username in WSL2 is the same as your username on Windows
cp -r ~/.ssh /mnt/c/Users/$USER/.ssh
```

Enable ssh-agent on Windows

```powershell
sudo Set-Service ssh-agent -StartupType Automatic
ssh-agent # Manually start the ssh-agent this time
ssh-add $env:USERPROFILE\.ssh\id_ed25519
# Enter password
```

### GitHub

Display public key:

```sh
cat ~/.ssh/id_ed25519.pub
```

Sign in to GitHub.com

On GitHub.com:

- Click profile picture -> Settings
    - SSH and GPG keys
        - New SSH Key (Button)
            - Title: {USERNAME}@{HOSTNAME}
            - Key: {Paste in public key contents here}

### PowerShell

Install PowerShell Core via the MSI so that it will be updated via Windows Update.

[GitHub Releases](https://github.com/PowerShell/PowerShell/releases)

Update Help

```powershell
sudo powershell -C Update-Help
pwsh -C Update-Help
# These command will likely fail, I guess keeping links updated is too hard.
```

### Fonts (Optional Admin)

Current preference is for `Iosevka Curly Medium` then `Iosevka SS12 Medium` (Ubuntu Mono Variant). However, neither of these are packaged for NerdFonts so I often end up using regular Iosevka Medium from NerdFont.

#### Nerd Font

Add NerdFont bucket to scoop

```powershell
scoop bucket add nerd-fonts
```

Install Iosevka from NerdFonts

```powershell
sudo scoop install -g IosevkaTerm-NF-Mono
sudo scoop install -g Iosevka-NF-Mono
```

#### Regular Font

[Download](https://github.com/be5invis/Iosevka/releases)

Install

- Extract the .ttf file
- Right click -> Show more options -> Install for all users


### Windows Settings

Clone the windows-settings repo to `~/AppData/Local`. Most repos will go in `S:\` but since this one is used to symlink config files it is MUCH easier to have it on `C:\` and AppData seems as good a place as any.

```powershell
cd ~/AppData/Local
git clone git@github.com:seantwie03/windows-settings.git
cd windows-settings
./Set-SettingsSymlinks.ps1
```

### ODroidH3Plus Samba Shares

#### File Explorer

Add odroidh3plus shares by:

- Click 'This Computer'
- Click the three dot menu
- Map network drive
    - U: - \\odroidh3plus\docs
    - S: - \\odroidh3plus\source

Quick Access should contain

- sean
- Donwloads
- docs (~/u - U:)
- source (~/s - S:)
- Ubuntu

Create Symlinks to network drives

```powershell
New-Item -ItemType SymbolicLink -Path ~/s -Target S:\
New-Item -ItemType SymbolicLink -Path ~/u -Target U:\
```

Mount network drives in WSL2

```sh
wsl
sudo mkdir /mnt/s /mnt/u
```

`/etc/fstab`

```
S: /mnt/s drvfs defaults,uid=1000,gid=1000,dmask=027,fmask=137 0 0
U: /mnt/u drvfs defaults,uid=1000,gid=1000,dmask=027,fmask=137 0 0
```

Test the fstab

```sh
sudo mount -a
# Shouldn't see any errors
```

### Dev Toolchains

Install JDK and NodeJS

```powershell
scoop bucket add java
scoop install corretto-lts-jdk
scoop install nvm
# Exit and relaunch PowerShell
nvm install lts
nvm use lts
npm install -g typescript
```

### Neovim (Requires Admin)

Install

```powershell
scoop bucket add extras
# gcc and make are for tree-sitter
# unzip gzip and wget are for Mason
scoop install vcredist2022 neovim gcc make unzip gzip wget jq
sudo npm install -g neovim
```

Open `nvim` a couple times so it can bootstrap itself.

Open `:Mason` and install the following linters

- jq
- eslint_d
- stylua

Run `:checkhealth` to see if anything is missing.

#### WSL Dotfiles

Install yadm

```sh
wsl
sudo apt install yadm
mv ~/.bashrc ~/.bashrc.orig
yadm clone git@github.com:seantwie03/dotfiles.git
```

When asked to bootstrap, say yes.

Update neovim

Open `nvim` a couple times so it can bootstrap itself.

Run `:checkhealth` to see if anything is missing.

### CLI Tools

Install CLI Tools

Install starship

```powershell
scoop install starship
```

Install bat

```powershell
scoop install bat less
```

Install fd-find

```powershell
scoop install fd
```

Install ripgrep

```powershell
scoop install ripgrep
```

### Podman

Install podman and docker-compose

```powershell
scoop install podman podman-desktop docker-compose
```

Configure podman

```powershell
podman machine init
podman machine set --rootful # This is needed for TestContainers
podman machine start
```

Open Podman Desktop

Settings
    - Resources
        - Podman Machine
            - Click Gear Icon
                - Autostart = Enabled
    - Preferences
        - Minimize on login = Enabled

### Jetbrains Tools

Install

```powershell
winget install Jetbrains.Toolbox --accept-package-agreements --accept-source-agreements
```

### VSCode & VSCode Insiders

Install VSCode manually because WinGet doesn't set any of the context menus or file associations. Turn on Settings Sync.

Install VSCode Insiders with WinGet because we do not want any file associations (except .md files). When turning on settings sync, choose Insiders.

```powershell
winget install vscode-insiders --accept-package-agreements --accept-source-agreements
```

### Caps to Ctrl

Create CapsToCtrl.reg with the contents below

```reg
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Keyboard Layout]
"Scancode Map"=hex:00,00,00,00,00,00,00,00,02,00,00,00,1d,00,3a,00,00,00,00,00
```

Double click the file, click yes, reboot

### PowerToys

Open PowerToys Settings

- Launch layout editor
    - Create new layout
        - NotesOnLeft
        - Create small-ish zone on left of primary monitor
        - Space around zones = Off
- Windows
    - Move newly created windows to their last known zone = Checked
    - Restore the original size of windows when unsnapping = Checked

### Tailscale

Install and Login

### Dropbox

Install (Requires Admin)

```powershell
winget install "Dropbox" -s winget --accept-package-agreements --accept-source-agreements
# May take a long time
```

