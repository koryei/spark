# Set up Spark

This takes about 5 minutes, once. Do the steps in order. Each ends with a **Check** so you know it worked before moving on.

**You need**

- A Mac (macOS 13 or newer).
- A home server running Linux (such as Ubuntu), plugged into your router with an **Ethernet cable**.
- A way to type commands on the server: Termius, or Terminal on your Mac using `ssh`. Every "on the server" step means this.

## 1. Install Spark

Paste this into Terminal on your Mac. It installs Spark and opens it:

```sh
curl -L https://github.com/koryei/spark/releases/latest/download/Spark.zip -o /tmp/Spark.zip && unzip -oq /tmp/Spark.zip -d /Applications && open /Applications/Spark.app
```

**Check:** a bolt icon appears in the menu bar and the **Spark Settings** window opens. Leave it open.

**Downloaded the zip in your browser instead?** macOS will say it "could not verify" Spark, because the app isn't signed with a paid Apple developer account. It's safe to open, and the code is public. Try opening Spark once, then go to **System Settings → Privacy & Security**, scroll down to the message about Spark, and click **Open Anyway**.

## 2. Find your server's details (on the server)

Run these two commands:

```sh
ip -br addr
ip link
```

- In the first result, find the line marked `UP` with an address like `192.168.1.50/24`. Your **server address** is that address without the `/24`. The word at the start of the line (for example `enp3s0`) is your **network card name**. Write it down.
- In the second result, find the same card name. The value after `link/ether` (for example `aa:bb:cc:dd:ee:ff`) is your **MAC address**.

Enter these in Spark Settings:

| Field | What to enter |
| --- | --- |
| Name | Anything, for example `homeserver` |
| MAC address | The `link/ether` value |
| Server address | The address without `/24` |
| SSH port | `22`, unless you changed it |
| Broadcast | Fills in by itself. It's the server address with the last number replaced by `255` |
| Username | The name you log in to the server with |

Don't press Save yet.

## 3. Let Spark log in without a password

1. In Spark Settings, press **Copy public key**.
2. On the server, run this. Replace `PASTE_KEY_HERE` with the key you just copied (⌘V) and keep the quotes:

```sh
mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo "PASTE_KEY_HERE" >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && echo DONE
```

**Check:** the server prints `DONE`.

## 4. Allow sleeping without a password

This lets your user put the server to sleep without typing a password, and nothing else. On the server, replace `YOUR_USERNAME` and run:

```sh
echo "YOUR_USERNAME ALL=(ALL) NOPASSWD: /usr/bin/systemctl suspend" | sudo tee /etc/sudoers.d/spark
sudo chmod 440 /etc/sudoers.d/spark
sudo visudo -cf /etc/sudoers.d/spark
```

**Check:** the last command prints `parsed OK`. If it prints anything else, run `sudo rm /etc/sudoers.d/spark` and try again. Don't skip this check: a mistake here can stop `sudo` from working.

## 5. Turn on Wake-on-LAN

This is the step that most often goes wrong. Two things need to be switched on.

**a) In the BIOS.** Restart the server and open its BIOS (usually by pressing F2, F12 or Delete as it starts). Turn on the option called *Wake on LAN*, *Power On by PCI-E* or similar. The name varies by manufacturer.

**b) In Linux.** Replace `enp3s0` with your network card name from step 2:

```sh
sudo ethtool enp3s0 | grep Wake-on
```

- `Wake-on: g` means it's on. You're done.
- `Wake-on: d` means it's off. Run `sudo ethtool -s enp3s0 wol g`, then check again.

This setting is lost when the server restarts. To keep it, on Ubuntu open your network file and add one line:

```sh
sudo cp /etc/netplan/*.yaml ~/netplan-backup.yaml
sudo nano /etc/netplan/*.yaml
```

Under your network card's name, add `wakeonlan: true`, lined up with the other settings under it (use spaces, not tabs). Then apply it safely:

```sh
sudo netplan try
```

If you can still reach the server, press Enter to keep the change. If something breaks, it undoes itself after two minutes.

## 6. Test and save

In Spark Settings, press **Test connection**. You should see three ticks:

```
✓  Reach 192.168.1.50 on port 22
✓  Log in with the key, no password
✓  Allowed to sleep without a password
```

If one fails, the line under it tells you what to fix. Then press **Save**.

## 7. Try it

1. Click the bolt icon. It should say **homeserver · Awake**.
2. Choose **Sleep server**. After a few seconds, open the menu again: it should say **Asleep**.
3. Wait about 30 seconds, then choose **Wake server**. The server should be back within a minute.

Sleeping pauses everything on the server, including Docker containers, until you wake it.

## If something goes wrong

| What you see | What to do |
| --- | --- |
| **No answer** | Check the server is on, the address is right, and your Mac is on the same network as the server. Guest and office Wi-Fi often block this. |
| **The server doesn't accept this key yet** | Repeat step 3. Paste the whole key on one line, and check the username matches. |
| **The server still asks for a password to sleep** | Repeat step 4. The username in the rule must match the one in Settings. |
| Sleep works but **Wake does nothing** | Repeat step 5. Check the BIOS setting and `Wake-on: g`, and use Ethernet, not Wi-Fi. |
| The server's address changed after a restart | In your router settings, look for *DHCP reservation* or *static lease* and give the server a fixed address. |
| Spark says **Not set up yet** | Choose **Settings…** from the bolt menu and press Save. |
| No bolt icon | A crowded menu bar can hide it. Quit another menu bar app to make room. |

## Uninstall

Quit Spark and delete Spark.app. To remove its files, delete `~/.config/spark` and `~/.ssh/spark*` on your Mac. On the server, delete `/etc/sudoers.d/spark` and the last line of `~/.ssh/authorized_keys` (the one ending in `spark`).
