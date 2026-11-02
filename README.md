# Spark

Wake your home server and put it back to sleep from your Mac's menu bar, so it only uses power when you need it.

**[spark.koryei.tech](https://spark.koryei.tech)**

![The Spark menu in the macOS menu bar](docs/images/menu.png)

<p>
<img src="docs/images/settings.png" alt="The Spark Settings window" width="49%">
<img src="docs/images/test-connection.png" alt="Test connection showing three passing checks" width="49%">
</p>

## Install

1. Paste this into Terminal. It installs Spark and opens it:

   ```sh
   curl -L https://github.com/koryei/spark/releases/latest/download/Spark.zip -o /tmp/Spark.zip && unzip -oq /tmp/Spark.zip -d /Applications && open /Applications/Spark.app
   ```

2. Follow the **[setup guide](docs/setup.md)** to connect it to your server. It takes about 15 minutes and checks each step as you go.

Requires macOS 13 or newer and a Linux server on the same network.

**Downloaded the zip in your browser instead?** macOS will say it "could not verify" Spark, because the app isn't signed with a paid Apple developer account. It's safe to open, and the code is all here. To open it: try opening Spark once, then go to **System Settings → Privacy & Security**, scroll down to the message about Spark, and click **Open Anyway**.

## How it works

- **Wake server** sends a Wake-on-LAN signal to your server.
- **Sleep server** tells your server to sleep over SSH, using a key, so there's no password to type.
- The menu shows whether the server is awake or asleep.

## Build it yourself

```sh
cd app && ./build.sh && open build/Spark.app
```

Needs the Xcode command line tools (`xcode-select --install`).
