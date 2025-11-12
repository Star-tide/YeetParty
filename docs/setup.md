# Setup Guide

## Overview
This document explains how to install, open, and run **Yeet Party** in Godot 4.5.

---

## Requirements
- **Godot Engine 4.5 or newer**  
- **Git** (to clone the repository)  
- *(Optional)* Visual Studio Code with the Godot Tools extension  

---
## Networking Modes
- Steam must be running for online play (With Steam). When available, the game initializes the Steam backend automatically (see `autoload/NetworkManager.gd:37–45`).
- If Steam is closed or initialization fails, the game automatically falls back to the existing ENet placeholder so you can still boot and test locally.

TODO - Actually write the full enet code

## Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/YourUsername/YeetParty.git
   cd YeetParty
2. Open the project in Godot:

	Launch Godot 4.5

	Click Import

3. Select project.godot in the root folder

	Press F5 to run the game!

## Folder Overview

Key directories you'll interact with:

    assets/
    scenes/
    scripts/
    data/
    tools/

## Exporting Builds

1. Go to Project -> Export
2. Choose target platform
3. Set export options and output path
4. Click Export Project
 
⚠️ Android builds require the Android SDK, JDK 17+, and configured export templates.
