# Hosting a p2pchat community

One person **hosts**: their PC runs the community, and everyone else **joins** it with a connect key. Pick the
section that matches where your friends are.

| Where your friends are | What you need | Status |
|---|---|---|
| [Same house or same network](#1-same-house-or-same-network) | Nothing | Works now |
| [Everyone on Radmin (or another VPN)](#2-everyone-on-radmin-or-another-vpn) | Everyone in the same Radmin network | Works now |
| [Anywhere, with port forwarding](#3-anywhere-with-port-forwarding) | Three ports forwarded on the host's router | Works now |
| [Anywhere, no port forwarding](#4-anywhere-no-port-forwarding-coming-soon) | Nothing | Coming in an update |

## Before you start (everyone)
1. Download `p2pchat-…-setup.exe` from the [latest release](https://github.com/riaanclaw/p2pchat-releases/releases/latest).
2. Run it. Windows may say **"Windows protected your PC"**, because this test build is not signed yet.
   Click **More info → Run anyway**.
3. The first time someone joins a community's LAN, Windows asks once for administrator permission
   to set up the network adapter.

## 1. Same house or same network
1. **Host:** open p2pchat and choose **Host a community**. Create your account with the owner key it shows you.
2. The app shows a **connect key** for your network address. Send it to your friends.
3. **Friends:** open p2pchat, choose **Join**, and paste the connect key.

## 2. Everyone on Radmin (or another VPN)
Same as section 1. The host gets a connect key for each network the PC is on, so send the one marked **Radmin VPN**.

## 3. Anywhere, with port forwarding
1. On the host's router, forward these to the host PC:
   - **TCP 8787**: chat, files and sign-in
   - **UDP 8787**: voice and video
   - **UDP 4242**: the community's LAN (4243, 4244 … for any extra communities)
2. Host as in section 1, then send friends a connect key that uses your **public IP address**.
   ([whatismyip.com](https://whatismyip.com) shows it.)

If your internet provider uses carrier-grade NAT (common on fibre), port forwarding can't work. Use section 2 for
now, or wait for section 4.

## 4. Anywhere, no port forwarding (coming soon)
This is how Radmin and Tailscale feel: the host invites a friend with a link, and it just works.

- The host's PC and every friend dial **out** to a small public **meeting point**, so no router needs opening.
- The meeting point introduces them, and they connect **directly** to each other.
- If two routers are too strict for a direct line, the meeting point **relays** their encrypted traffic, with a cap.
  It can never read anything.

It arrives in an app update. The app will offer to install it when you start it.

## Questions
- **Is my chat private?** Direct messages are end-to-end encrypted. The community's LAN traffic is encrypted
  between machines.
- **Does the meeting point see my files?** No. Files go directly between members. Only when a direct line is
  impossible does traffic pass through it, encrypted and capped.
