#!/usr/bin/env bash
# Build script for Render (free plan has no pre-deploy command, so migrate and seed here).
set -o errexit

bundle install
bin/rails db:migrate
bin/rails db:seed
