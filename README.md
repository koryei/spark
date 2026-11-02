# Spark

A macOS menu bar app that wakes a home server with Wake-on-LAN and puts it back to sleep over SSH, so it only draws power when you use it. Plus a one-screen landing page for it.

## Installation

New here? Follow the **[setup guide](docs/setup.md)**. It walks through every step and says how to check each one worked.

Quick build and run (needs the Xcode command line tools):

```sh
cd app && ./build.sh && open build/Spark.app
```

The bolt icon in the menu bar shows whether the server is awake or asleep, with **Wake server** and **Sleep server**. Choose **Settings…** to enter the server's details, copy the public key, and test the connection. Settings are saved to `~/.config/spark/config.json`.

- **Wake** sends a Wake-on-LAN magic packet (UDP port 9) to the broadcast address.
- **Sleep** runs `ssh user@host "sudo -n systemctl suspend"` with a key, so no password is needed.
