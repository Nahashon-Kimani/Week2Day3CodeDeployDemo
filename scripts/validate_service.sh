#!/bin/bash
# Fail the deployment if the home page is not served
sleep 5
curl -sf http://localhost/index.html > /dev/null