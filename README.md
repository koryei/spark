# Spark

A macOS menu bar app that wakes a home server with Wake-on-LAN and puts it back to sleep over SSH, so it only draws power when you use it. Plus a one-screen landing page for it.
## Installation

Build and run (needs the Xcode command line tools):

```sh
cd app && ./build.sh && open build/Spark.app
```

On first launch choose **Open config…** from the bolt icon. That creates `~/.config/spark/config.json`:

```json
{
  "name": "homeserver",
  "mac": "AA:BB:CC:DD:EE:FF",
  "broadcast": "192.168.1.255",
  "host": "192.168.1.50",
  "user": "you",
  "port": 22,
  "identityFile": null
}
```

- **Wake server** sends a Wake-on-LAN magic packet (UDP port 9) to `broadcast`.
- **Sleep server** runs `ssh user@host "sudo -n systemctl suspend"`.
- The status line checks whether the SSH port answers each time you open the menu.

### One-time server setup

1. Enable Wake-on-LAN in the server's BIOS and on its network card (`sudo ethtool -s <iface> wol g`).
2. Add your Mac's public key to the server (`ssh-copy-id user@host`); Spark never prompts for a password.
3. Allow suspend without a password, using `sudo visudo -f /etc/sudoers.d/spark`:
   ```
   you ALL=(ALL) NOPASSWD: /usr/bin/systemctl suspend
   ```

Wake-on-LAN works best over Ethernet and from the same network.
