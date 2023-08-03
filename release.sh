for f in $(find . -name "*.lua"); do
    if [ $(cat $f | grep logger | grep -v "^ *--" | wc -l) -gt 0 ]; then
        echo -e "Attention! There are loggers in the source code\n"
        read
    fi
done
VERSION="$(cat Chalutier.txt  | grep "## Version:" | cut -d":" -f2 | xargs)"
rm Chalutier*.zip
mkdir Chalutier
cp Chalutier.txt Chalutier.lua Chalutier
7z a -r Chalutier-$VERSION.zip Chalutier
rm -rf Chalutier