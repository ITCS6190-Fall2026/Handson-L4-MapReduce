#!/bin/bash
# Run once in a clone of the course repo, then push.
set -e
git rm -r --cached target          # stop tracking committed build output
git rm --cached hadoop.env         # replaced by ./config
rm -f hadoop.env
git add .gitignore config docker-compose.yml pom.xml README.md REPORT.md
git commit -m "Migrate cluster to apache/hadoop:3; fix build config; stop tracking target/"
git push
