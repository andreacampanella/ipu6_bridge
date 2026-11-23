# Intel IPU6 Camera Manager

This repository has setup steps for CachyOS (Arch) and Ubuntu 26.04. Steps 1–5 are for CachyOS. For Ubuntu, see [Ubuntu 26.04 Setup](#ubuntu-2604-setup).

## CachyOS Setup

## 1. Install driver, HAL, plugin, loopback (AUR)

```bash
yay -S intel-ipu6-dkms-git intel-ipu6ep-camera-hal-git gst-plugin-icamerasrc-git v4l2loopback-dkms
```

## 2. Auto-load v4l2loopback at boot

```bash
echo v4l2loopback | sudo tee /etc/modules-load.d/v4l2loopback.conf
echo 'options v4l2loopback devices=1 video_nr=50 card_label="Intel IPU6 Camera" exclusive_caps=1' | sudo tee /etc/modprobe.d/v4l2loopback.conf
```

## 3. Fix PSYS permissions (udev)

```bash
echo 'SUBSYSTEM=="video4linux", KERNEL=="ipu-psys0", MODE="0660", GROUP="video"' | sudo tee /etc/udev/rules.d/99-ipu-psys.rules
sudo usermod -aG video $USER   # log out/in after
```

## 4. Create the systemd user service

`~/.config/systemd/user/ipu6-camera.service`:

```ini
[Unit]
Description=Intel IPU6 Camera Streaming
After=graphical-session.target

[Service]
ExecStart=/usr/bin/gst-launch-1.0 icamerasrc ! videoconvert ! video/x-raw,format=YUY2,width=1280,height=720 ! v4l2sink device=/dev/video50
Restart=on-failure

[Install]
WantedBy=default.target
```

Reload:

```bash
systemctl --user daemon-reload
```

## 5. Use the manager script

```bash
chmod +x ipu6-camera.sh

./ipu6-camera.sh start      # start streaming (loads modules if needed)
./ipu6-camera.sh status     # verify everything is up
./ipu6-camera.sh enable     # auto-start on boot
./ipu6-camera.sh test       # live preview window
./ipu6-camera.sh logs       # troubleshoot
./ipu6-camera.sh stop       # stop streaming
```

After `start`, select **`/dev/video50`** (Intel IPU6 Camera) in Slack, Cheese, OBS, Zoom, etc.

## Ubuntu 26.04 Setup

On Ubuntu, the IPU6 kernel modules come from the Ubuntu archive. The camera HAL and the `icamerasrc` plugin come from the Intel IPU6 OEM PPA.

1. Add the PPA and install the packages:

   ```bash
   sudo add-apt-repository -y ppa:oem-solutions-group/intel-ipu6
   sudo apt update
   sudo apt install -y linux-modules-ipu6-generic-hwe-26.04 \
     gstreamer1.0-icamera libcamhal-ipu6ep libcamhal-ipu6epmtl \
     v4l2loopback-dkms v4l2loopback-utils gstreamer1.0-tools
   ```

2. Install the config files, the service, and the manager script:

   ```bash
   ./install.sh
   ```

3. Stop `v4l2-relayd` if it is installed. It uses the same camera and loopback device as this service.

   ```bash
   sudo systemctl disable --now v4l2-relayd
   ```

4. Reboot. This loads the IPU6 modules and applies the `video` group change.

5. Start the camera and check it:

   ```bash
   ipu6-camera start
   ipu6-camera status
   ```

Notes:

- `libcamhal-ipu6ep` is for Alder Lake and Raptor Lake. `libcamhal-ipu6epmtl` is for Meteor Lake. The command installs both.
- If you upgraded from Ubuntu 24.04, you can have `linux-modules-ipu6-generic-hwe-24.04` instead. That package also works.
- If `add-apt-repository` or `apt update` gives `503 Service Unavailable`, Launchpad is down. Wait and run the command again.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `icamerasrc plugin NOT installed` | Reinstall `gst-plugin-icamerasrc-git`; check `gst-inspect-1.0 icamerasrc` |
| Virtual device missing | `sudo modprobe -r v4l2loopback && sudo modprobe v4l2loopback` |
| PSYS permission warning | Confirm udev rule + you're in `video` group (`groups`) |
| No sensor detected | Sensor driver/ACPI missing — see Surface note below |
| Service fails | `journalctl --user -u ipu6-camera.service -n 50` |

---

## Will this work on a Microsoft Surface?

**Depends on the model — and most Surfaces need extra work.**

**Potentially works (x86 IPU6):** Surface Pro 8/9, Laptop 4 (Intel)/5, Laptop Studio — Tiger Lake / Alder Lake / Meteor Lake.

**Will NOT work:** Any ARM Surface — Pro X (SQ1/2/3), Pro 11 / Laptop 7 (Snapdragon X). IPU6 is x86-only.

### Key caveat

Surface cameras pair IPU6 with specific sensors (`ov5693`, `ov8865`, etc.) whose drivers/ACPI bindings aren't in the stock CachyOS kernel — the sensor won't even enumerate. You'll likely need:

- The **[linux-surface](https://github.com/linux-surface/linux-surface)** kernel + their IPU6/sensor patches, **instead of** the vanilla AUR packages in step 1.
- Their documented `libcamera` / IPU6 camera stack for your exact model.

Check your model's status on the linux-surface wiki before starting — that determines whether this is viable at all.