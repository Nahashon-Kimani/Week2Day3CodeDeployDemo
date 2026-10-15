#!/bin/bash
set -e
# Install Apache if it is not already installed (Amazon Linux 2023 uses dnf)
if ! rpm -q httpd > /dev/null 2>&1; then
  dnf install -y httpd
fi