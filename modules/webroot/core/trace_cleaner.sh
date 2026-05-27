# Import common function
MODDIR="${0%/*}"
. $MODDIR/../../common_func.sh

# LSPosed Trace
find /data/app/*/*/oat/* -type f -name "base.odex" -exec rm -f {} \;