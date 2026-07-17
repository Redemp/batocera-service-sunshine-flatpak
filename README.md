<p align="center">
  <img src="images/batocera-logo.png" alt="Batocera" width="180">
  &nbsp;&nbsp;&nbsp;
  <img src="images/sunshine-logo.png" alt="Sunshine" width="180">
</p>

<h1 align="center">Sunshine Flatpak Service for Batocera</h1>

Setup is a single SSH install script: run it from another device into Batocera. Use that same device for the Sunshine Web UI and Moonlight pairing.


## Before You Start

1. Install [Moonlight](https://moonlight-stream.org/) on the device you will stream to (PC, phone, tablet, TV, etc.).
2. Put that device on the **same network** as your Batocera machine.

## Install

3. On your Moonlight device open terminal, SSH into Batocera, then run:

```bash
curl -fsSL \
  https://raw.githubusercontent.com/Redemp/batocera-service-sunshine-flatpak/main/install.sh \
  | bash
```

`install.sh` will:

- Confirm Batocera and Flatpak are available
- Install the system-wide Sunshine Flatpak from Flathub if it is missing (adds the system Flathub remote when needed)
- Install the service scripts under `/userdata/system/sunshine-service/`
- Install the Batocera service at `/userdata/system/services/sunshine`
- Enable and start the service

### What success looks like in the terminal

After `[ OK ] Sunshine started`, you should see output like the example below. Your terminal will print your Batocera machine's real IP (or `https://BATOCERA-IP:47990` if detection failed).

```text
----------------------------------------------------
 Installation complete
----------------------------------------------------

Open the Sunshine Web UI:
  https://YOUR-BATOCERA-IP:47990
```

### What failure looks like in the terminal

> [!CAUTION]
> If Sunshine does not start, the terminal shows a warning first, then still prints `Installation complete`, then exits with `[FAIL]`. This means you cannot move forward. Run diagnose, fix issues, then try starting the sunshine service again.

```text
[WARN] Sunshine did not start successfully.
Run: /userdata/system/sunshine-service/sunshine-diagnose

----------------------------------------------------
 Installation complete
----------------------------------------------------

Sunshine was installed, but it failed to start.
It is not ready to use yet.

Check why with:
  /userdata/system/sunshine-service/sunshine-diagnose

Then try starting it again with:
  /userdata/system/services/sunshine start

[FAIL] Sunshine service start failed.
```

4. Once Sunshine service has successfully started, open the URL from the terminal (click it, or copy it into a browser on your Moonlight device).

> [!WARNING]
> Your browser may not recognize the address and will warn that the site is unsafe. That is expected. Example in Chrome: click **Advanced**, then proceed to the site. Other browsers have a similar "advanced" / "continue" / "accept risk" step.

You should now see the Sunshine Web UI Create Login Page.

5. Create your username and password and click Submit. **A CSRF Protection Error on the page is expected. If you do not see an error skip to step 9**

6. Only if the browser shows a CSRF Protection Error, run via SSH: 
    - `/userdata/system/sunshine-service/sunshine-csrf-setup`
7. Answer `y` when asked.

A successful run looks like this in the terminal:

```text
Sunshine CSRF Setup for Batocera

Detected blocked origin:
  https://YOUR-BATOCERA-IP:47990

Add this trusted origin to Sunshine? [y/N]
Added trusted origin: https://YOUR-BATOCERA-IP:47990
Restarting Sunshine...
Done. Reload the Sunshine Web UI.
```

8. Go back to the browser, **refresh the Sunshine Web UI Create Login Page** and enter a username and password again.
9. The page will refresh and ask you to Login using your newly created username and password.

A successful login will land on the Sunshine Web UI Main Page.

10. In the top menu click on `PIN`. This is where you will insert a pairing PIN number provided by Moonlight.
11. Open the Moonlight application and click on the icon to `Add PC Manually`
12. You will add your Batocera IP without `https://` & `:47990`. For example: https://103.24.6.234:47990 would just be `103.24.6.234`. This should then provide a PIN.
13. Finally in Sunshine enter the PIN, make up a Name and click Send.

You should now successfully have paired your Batocera machine to your Moonlight device. In Moonlight start Batocera.

## Troubleshooting

```bash
/userdata/system/sunshine-service/sunshine-diagnose
```

That checks Flatpak/Sunshine install, the service files, whether Sunshine is running, whether the Web UI answers on `47990`, logs, encoders, and recent CSRF blocks.

Useful follow-ups:

```bash
/userdata/system/services/sunshine status
/userdata/system/services/sunshine start
tail -f /userdata/system/logs/sunshine.log
```

### Install or start fails before the Web UI opens (encoder probe)

On some systems (for example the **ASRock BC-250**), Sunshine can exit during encoder probing before the Web UI binds on port `47990`. Logs may show something like `Encoding of h264 is not supported` / `h264_vulkan`. This can also affect other GPUs, APUs, or dGPUs when hardware encode is missing or broken for Sunshine's probe path.

It is **not** applied by the installer on purpose. Forcing software encode on machines with working NVENC/VAAPI/AMF would push encoding onto the CPU for everyone causing performance issues.

If install/start fails and diagnose or the Sunshine log points at encoder failure, run this once over SSH. It creates `sunshine.conf` when missing, or adds `encoder = software` if the file already exists (without wiping other settings like CSRF origins):

```bash
CONF=/userdata/saves/flatpak/data/.var/app/dev.lizardbyte.app.Sunshine/config/sunshine/sunshine.conf
mkdir -p "$(dirname "$CONF")"
if [ ! -f "$CONF" ]; then
  echo 'encoder = software' > "$CONF"
elif ! grep -q '^[[:space:]]*encoder[[:space:]]*=' "$CONF"; then
  echo 'encoder = software' >> "$CONF"
fi
```

Then restart and confirm:

```bash
/userdata/system/services/sunshine restart
/userdata/system/services/sunshine status
```

Open the Web UI again at `https://BATOCERA-IP:47990` (use your real Batocera IP).

### Enable the service if needed

If the installer could not enable the service automatically, it tells you to enable it here:

```text
MAIN MENU > SYSTEM SETTINGS > SERVICES > SUNSHINE
```

<p align="center">
  <img src="images/services-menu-sunshine.png" alt="Sunshine enabled in Batocera Services" width="700">
</p>

## Recommended Streaming Resolutions

> [!TIP]
> Configure the streaming resolution in the **Moonlight** client. Sunshine will stream at the resolution requested by the client.

For the best experience, configure Moonlight to match the display you are actually using.

For modern widescreen displays, simply select your display's native resolution.

For CRT televisions and CRT monitors, many retro games were originally displayed in a **4:3 aspect ratio**. Choosing a 4:3 streaming resolution avoids stretching and generally provides a more authentic presentation.

### Recommended 4:3 streaming resolutions

| Widescreen Resolution | Recommended 4:3 Resolution |
|----------------------:|---------------------------:|
| 1280×720 | **1280×960** |
| 1920×1080 | **1440×1080** |
| 2560×1440 | **1920×1440** |
| 3840×2160 (4K) | **2880×2160** |

These resolutions preserve the full vertical resolution while converting the image to a true 4:3 aspect ratio.

## Uninstall

Stops the service, disables it, and removes `/userdata/system/services/sunshine` plus `/userdata/system/sunshine-service/`. Leaves the Sunshine Flatpak and its config alone:

```bash
/userdata/system/sunshine-service/uninstall.sh
```

Remove Sunshine itself:

```bash
flatpak uninstall --system dev.lizardbyte.app.Sunshine
```

## More info

- Sunshine docs: https://docs.lizardbyte.dev/projects/sunshine/latest/index.html
- Batocera Flatpak: https://wiki.batocera.org/systems:flatpak

## Credits

Inspired by `n2qz/batocera-service-sunshine` (AppImage) by maximumentropy. This version uses the official Sunshine Flatpak via Batocera's Flatpak support.

License: [CC0 1.0](LICENSE)
