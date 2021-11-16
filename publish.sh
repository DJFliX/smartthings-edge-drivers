#!/usr/bin/env bash

TIWTIE_CHANNEL=8172db2d-3ca7-408a-b1d6-21e6dc688906
HUB_ID=<YOUR_HUB_ID_HERE>
LUMI_DRIVER_ID=7f51fc81-0327-4090-a7c8-28241179b2a9
IKEA_BUTTON_DRIVER_ID=0b0a6d00-ad0d-4294-b2e2-d94ffa13b62b

smartthings edge:drivers:package lumi-tvoc
smartthings edge:drivers:publish -C $TIWTIE_CHANNEL $LUMI_DRIVER_ID
smartthings edge:drivers:install -H $HUB_ID -C $TIWTIE_CHANNEL $LUMI_DRIVER_ID
smartthings edge:drivers:package ikea-shortcut-button
smartthings edge:drivers:publish -C $TIWTIE_CHANNEL $IKEA_BUTTON_DRIVER_ID
smartthings edge:drivers:install -H $HUB_ID -C $TIWTIE_CHANNEL $IKEA_BUTTON_DRIVER_ID