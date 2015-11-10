set -e

BASE_DIR=`cd ../; pwd`
OPENSOURCE_DIR=$1

if [ -z "$OPENSOURCE_DIR" -o -f "$OPENSOURCE_DIR" ]; then
    echo "Usage : $0 <open_source_directory>" 1>&2
    exit 1
fi

mkdir -p $OPENSOURCE_DIR

# Make sure we are clean so we don't copy useless stuff
make clean

cp $BASE_DIR/LICENSE.txt $OPENSOURCE_DIR/LICENSE.txt

cp -r $BASE_DIR/build $OPENSOURCE_DIR
rm -f $OPENSOURCE_DIR/build/.tpattributes

cp -r $BASE_DIR/installer $OPENSOURCE_DIR
rm -rf $OPENSOURCE_DIR/installer/oss-kits

mkdir -p $OPENSOURCE_DIR/source/
cp -r $BASE_DIR/source/code $OPENSOURCE_DIR/source/

cp -r $BASE_DIR/test $OPENSOURCE_DIR

# Remove sensitive keys
sed s/=.*/=\"\"/g $BASE_DIR/test/test_keys.sh > $OPENSOURCE_DIR/test/test_keys.sh

# Make files writable because they are not under tfs
chmod -R +w $OPENSOURCE_DIR

echo "Successfully open sourced in \"$OPENSOURCE_DIR\""
