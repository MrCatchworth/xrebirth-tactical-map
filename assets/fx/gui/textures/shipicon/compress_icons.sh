for pic in *.dds
do
    name=${pic%.*}
    echo Compressing $name
    7z a $name.gz $pic
done
read
