# Spark

A macOS menu bar app that wakes a home server with Wake-on-LAN and puts it back to sleep over SSH, so it only draws power when you use it. Plus a one-screen landing page for it.

## Screenshots

![The Spark menu in the macOS menu bar](docs/images/menu.png)

<p>
<img src="docs/images/settings.png" alt="The Spark Settings window" width="49%">
<img src="docs/images/test-connection.png" alt="Test connection showing three passing checks" width="49%">
</p>

The menu is a mockup. The Settings window is a real render of the app with sample values. Regenerate them with `tools/screenshots/make.sh`.

## Installation

New here? Follow the **[setup guide](docs/setup.md)**. It walks through every step and says how to check each one worked.

**Download:** get `Spark.zip` from the [latest release](https://github.com/koryei/spark/releases/latest), unzip it, and drag `Spark.app` into Applications. The app isn't signed with an Apple developer ID, so the first time, right-click it and choose **Open**.

Or build it yourself (needs the Xcode command line tools):

```sh
cd app && ./build.sh && open build/Spark.app
```

The bolt icon in the menu bar shows whether the server is awake or asleep, with **Wake server** and **Sleep server**. Choose **Settings…** to enter the server's details, copy the public key, and test the connection. Settings are saved to `~/.config/spark/config.json`.

- **Wake** sends a Wake-on-LAN magic packet (UDP port 9) to the broadcast address.
- **Sleep** runs `ssh user@host "sudo -n systemctl suspend"` with a key, so no password is needed.
