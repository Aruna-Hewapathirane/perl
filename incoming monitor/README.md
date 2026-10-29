<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/b6dbc117-1745-4328-ba0c-9529e282571a" />

You can generate the traffic yourself on the same machine. Start the monitor, click **Start**, and try these steps:

### 1. Basic Connection Test

In one terminal, open a listener:
```bash
nc -l 8080
```

In another terminal, connect to it:
```bash
nc 127.0.0.1 8080
```

> [!NOTE]
> A row should appear with source `127.0.0.1` and local port `8080`. It will be colored **white** because loopback traffic counts as LAN.

You will also see attempts to ports where nothing is listening, since the `SYN` packet shows up either way:
```bash
nc -zv 127.0.0.1 9999
```

---

### 2. Port Scan Detection

This hits 20 different ports from one source, which should turn the rows **red** and flag them as `PORT SCAN?` after the 10th distinct port:
```bash
for p in \((seq 9000 9019); do nc -z -w1 127.0.0.1 \)p; done
```

Alternatively, if you have `nmap` installed, you can run:
```bash
nmap -p 1-30 127.0.0.1
```

> [!IMPORTANT]
> The scan counter is tracked per source IP and persists until you click **Clear**. Because of this, repeat tests from the same IP will trigger the red flag immediately.

---

### 3. Test From Another Device (More Realistic)

1. Find your desktop's LAN address by running:
   ```bash
   ip -4 addr
   ```
   *(Look for an address like `192.168.1.x`)*

2. From a phone or another computer on your network, trigger traffic using one of these methods:
   * **Option A (Port Scan):** 
     ```bash
     nmap -p 1-100 <your-desktop-ip>
     ```
   * **Option B (Web Browser):** Open `http://<your-desktop-ip>:8080` in a browser while `nc -l 8080` is running on your desktop.

> [!NOTE]
> You will see a different source IP on the monitor, providing a much closer representation of what a real network probe looks like.



