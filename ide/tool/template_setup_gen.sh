ls -R -1 | perl -lane 'if (/^$/) {} elsif (/(.*):/) { print "]\n},\n\"$1\": {\n  \"files\": ["} else { print "{ \"source\": \"${_}_\", \"dest\": \"$_\" }," }' > setup_raw.json
