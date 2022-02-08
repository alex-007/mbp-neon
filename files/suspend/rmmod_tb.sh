#!/bin/sh
if [ "${1}" = "pre" ]; then
  modprobe -r apple_ib_tb
  modprobe -r hid_apple
  modprobe -r brcmfmac
elif [ "${1}" = "post" ]; then
  modprobe hid_apple
  modprobe apple_ib_tb
  modprobe brcmfmac
fi
