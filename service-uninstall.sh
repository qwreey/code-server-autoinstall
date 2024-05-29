#!/bin/bash

systemctl disable --user --now code-server.service
rm "$HOME/.config/systemd/user/code-server.service"

