#!/usr/bin/env python3
"""Write Finder layout metadata directly, without changing the user's Finder preferences."""
from pathlib import Path
import sys

from ds_store import DSStore
from mac_alias import Alias

volume = Path(sys.argv[1])
with DSStore.open(str(volume / ".DS_Store"), "w+") as store:
    store["."]["bwsp"] = {
        "ShowStatusBar": False,
        "ShowTabView": False,
        "ShowToolbar": False,
        "ShowPathbar": False,
        "ShowSidebar": False,
        "SidebarWidth": 0,
        "WindowBounds": "{{180, 160}, {640, 350}}",
        "ContainerShowSidebar": False,
    }
    store["."]["icvp"] = {
        "viewOptionsVersion": 1,
        # The artwork, over its own charcoal (Finder needs a color with the picture, and keeps both
        # fixed in light and dark mode).
        "backgroundType": 2,
        "backgroundColorRed": 0x12 / 255,
        "backgroundColorGreen": 0x14 / 255,
        "backgroundColorBlue": 0x16 / 255,
        "backgroundImageAlias": Alias.for_file(str(volume / ".background" / "installer.png")).to_bytes(),
        "iconSize": 96.0,
        "textSize": 13.0,
        "gridOffsetX": 0.0,
        "gridOffsetY": 0.0,
        "gridSpacing": 100.0,
        "scrollPositionX": 0.0,
        "scrollPositionY": 0.0,
        "labelOnBottom": True,
        "showIconPreview": False,
        "showItemInfo": False,
        "arrangeBy": "none",
    }
    store["."]["vSrn"] = ("long", 1)
    store["."]["icvl"] = ("type", b"icnv")
    store["Transflo.app"]["Iloc"] = (170, 175)
    store["Applications"]["Iloc"] = (470, 175)
