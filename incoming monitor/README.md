<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/b6dbc117-1745-4328-ba0c-9529e282571a" />

### You can generate the traffic yourself on the same machine. Start the monitor, click Start, and try these.

## 1. Basic connection test

In one terminal, open a listener:

bash
nc -l 8080

In another, connect to it:

bash
nc 127.0.0.1 8080

A row should appear with source 127.0.0.1 and local port 8080. It will be white, because loopback counts as LAN.

You’ll also see attempts to ports where nothing is listening, since the SYN packet shows up either way:

bash
nc -zv 127.0.0.1 9999
2. Port scan detection

This hits 20 different ports from one source, which should turn rows red and flag them “PORT SCAN?” after the 10th distinct port:

bash
for p in $(seq 9000 9019); do nc -z -w1 127.0.0.1 $p; done

Or, if you have nmap installed:

bash
nmap -p 1-30 127.0.0.1

The scan counter is per source IP and stays until you press Clear. That’s why repeat tests from the same IP will be red right away.

3. Test from another device (more realistic)

Find your desktop’s LAN address with ip -4 addr (something like 192.168.1.x). Then from a phone or another computer on your network, run nmap -p 1-100 <that-ip>, or just open http://<that-ip>:8080 in a browser while nc -l 8080 is running. You’ll see a different source IP, which is closer to what a real probe looks like.
