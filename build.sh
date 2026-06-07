#!/bin/bash

echo "Creating Module Zip"
[ -f test/TSupport-Advance.zip ] && cat test/TSupport-Advance.zip > test/TSupport-Advance.zip.bak
rm test/TSupport-Advance.zip
cd modules/ && zip -r ../test/TSupport-Advance.zip * && echo "Zip Success" || echo "Zip Failed"