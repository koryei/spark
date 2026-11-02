# Spark setup guide

About 15 minutes, once. Follow the steps in order and don't skip the **Check** lines. Each one tells you the step worked before you move on.

**You need**

- A Mac running macOS 13 or newer, with the Xcode command line tools (`xcode-select --install`).
- A home server running Linux with systemd (Ubuntu, Debian and similar), connected by an **Ethernet cable** to the same network as your Mac.
- A way to type commands on the server: Termius, or `ssh` in Terminal. Every "on the server" step below means this.

> Spark only ever runs two things on your server: `sudo systemctl suspend` to sleep it, and nothing else. It never stores your server password.

## 1. Build and open Spark (on your Mac)

```sh
git clone https://github.com/koryei/spark.git
cd spark/app
./build.sh
open build/Spark.app
```

**Check:** a bolt icon appears in the menu bar and the **Spark Settings** window opens. Leave it open.

Optional: drag `build/Spark.app` into your Applications folder, then add it in System Settings → General → Login Items so it starts with your Mac.

## 2. Find your server's details (on the server)

Run:

```sh
ip -br addr
ip link
```

- In the first output, find the line that is `UP` and has an address like `10.0.0.232/24`. The name at the start of that line (for example `enp0s31f6`) is your **network card name**. The address without the `/24` is the **Server address**.
- In the second output, find the block with that same card name. The value after `link/ether` (for example `c0:47:0e:fa:44:17`) is the **MAC address**.

Type those into Spark Settings:

| Field | What to enter |
| --- | --- |
| Name | Anything you like, for example `homeserver` |
| MAC address | The `link/ether` value |
| Server address | The address with no `/24` |
| SSH port | `22`, unless you changed it |
| Broadcast | Fills in by itself, e.g. `10.0.0.255`. It is the server address with the last number replaced by `255` |
| Username | The name you log in to the server with |

Don't press Save yet.

## 3. Let Spark log in without a password

Spark logs in with a key, because it can't type a password for you.

1. In Spark Settings, press **Copy public key**. If the key doesn't exist yet, Spark creates `~/.ssh/spark` first.
2. On the server, run the command below. Replace `PASTE_KEY_HERE` with the key you copied (⌘V), keeping the quotes:

```sh
mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo "PASTE_KEY_HERE" >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && echo DONE
```

**Check:** the server prints `DONE`.

## 4. Allow sleeping without a password

`systemctl suspend` needs administrator rights. This rule lets your user run that one command without a password, and nothing else. On the server, replace `YOUR_USERNAME` and run:

```sh
echo "YOUR_USERNAME ALL=(ALL) NOPASSWD: /usr/bin/systemctl suspend" | sudo tee /etc/sudoers.d/spark
sudo chmod 440 /etc/sudoers.d/spark
sudo visudo -cf /etc/sudoers.d/spark
```

**Check:** the last command prints `parsed OK`. If it prints anything else, remove the file with `sudo rm /etc/sudoers.d/spark` and try again. A broken sudoers file can stop `sudo` from working, so don't skip this check.

## 5. Turn on Wake-on-LAN (on the server)

This is the step that most often goes wrong. Two switches need to be on.

**a) In the BIOS.** Restart the server, open the BIOS (usually F2, F12 or Delete at boot) and enable the option called *Wake on LAN*, *Power On by PCI-E* or *Wake on PCI-E*. Names vary by maker. Also turn off any "deep sleep" or "ErP" power-saving option if you find one.

**b) In the operating system.** Replace `enp0s31f6` with your network card name from step 2:

```sh
sudo ethtool enp0s31f6 | grep Wake-on
```

- If it shows `Wake-on: g`, you're done.
- If it shows `Wake-on: d`, run `sudo ethtool -s enp0s31f6 wol g` and check again.

That setting is lost when the server restarts. To make it permanent on Ubuntu, open your network file (usually the only `.yaml` file in `/etc/netplan/`):

```sh
sudo cp /etc/netplan/*.yaml ~/netplan-backup.yaml
sudo nano /etc/netplan/*.yaml
```

Under your network card's name, add the line `wakeonlan: true`, lined up with the other settings beneath it (netplan cares about spaces, not tabs). Then apply it safely:

```sh
sudo netplan try
```

If you can still reach the server after pressing Enter to accept, you're done. If something breaks, it reverts by itself after 2 minutes.

## 6. Test and save (in Spark Settings)

Press **Test connection**. You should see three ticks:

```
✓  Reach 10.0.0.232 on port 22
✓  Log in with the key, no password
✓  Allowed to sleep without a password
```

If one fails, the line under it says what to fix. Then press **Save**.

## 7. Try it

1. Click the bolt icon. It should say **homeserver · Awake**.
2. Choose **Sleep server**. After a few seconds, open the menu again: it should say **Asleep**.
3. Wait about 30 seconds, then choose **Wake server**. The server should be back within a minute.

> Sleeping pauses everything on the server, including Docker containers and any service you run, until you wake it.

## Troubleshooting

| What you see | What to do |
| --- | --- |
| Test says **No answer** | Check the server is on, the address is right, and your Mac is on the same network. Corporate and guest Wi-Fi often block devices from seeing each other. |
| **The server doesn't accept this key yet** | Repeat step 3. Make sure you pasted the whole key on one line, and that the username matches. |
| **The server still asks for a password to sleep** | Repeat step 4. The username in the rule must be the one in Settings. |
| Sleep works but **Wake does nothing** | Step 5. Check both the BIOS setting and `Wake-on: g`. Use Ethernet on the server, not Wi-Fi. Waking from a full shutdown is less reliable than waking from sleep. |
| Server's address changed after a reboot | Your router hands out addresses that can change. In your router settings, look for *DHCP reservation* or *static lease* and pin the server to one address. |
| Spark says **Not set up yet** | Open **Settings…** from the bolt menu and press Save. |
| Spark doesn't appear in the menu bar | Look for the bolt icon on the right. Crowded menu bars (or a notch) can hide it; quit another menu bar app to make room. |

## Where things are stored

- Settings: `~/.config/spark/config.json`, which the Settings window edits for you.
- Key: `~/.ssh/spark` and `~/.ssh/spark.pub`.

To remove Spark completely, quit it, delete `Spark.app` and those files, and on the server delete `/etc/sudoers.d/spark` and the line ending in `spark` from `~/.ssh/authorized_keys`.
