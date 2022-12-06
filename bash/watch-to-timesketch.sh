# Watch this directory for new files (ie: vr_kapetriage_$system.zip added to /opt/timesketch/upload)
PARENT_DATA_DIR="/opt/timesketch/upload"

process_files () {
    ZIP=$1
    # Get system name
    SYSTEM=${ZIP%.*}

    # Velociraptor artifact inserts `_$label` to the zip so we can use the label as the sketch name, remove this and references to $LABEL if you do not wish to use it
    #LABEL=$(echo $SYSTEM|cut -d"_" -f 4)
    LABEL=$(echo $SYSTEM)

    # Unzip
    echo A | unzip $PARENT_DATA_DIR/$ZIP -d $PARENT_DATA_DIR/$SYSTEM

    # Remove from subdir
    mv $PARENT_DATA_DIR/$SYSTEM/fs/clients/*/collections/*/uploads/* $PARENT_DATA_DIR/$SYSTEM/

    # Delete unnecessary collection data
    rm -r $PARENT_DATA_DIR/$SYSTEM/fs $PARENT_DATA_DIR/$SYSTEM/UploadFlow.json $PARENT_DATA_DIR/$SYSTEM/UploadFlow

    # Run log2timeline and generate Plaso file
    timesketch_worker=$(awk '/timesketch-worker/{print $NF}' <(docker ps -a))
    docker exec -i $timesketch_worker /bin/bash -c "log2timeline.py --status_view window --storage_file /usr/share/timesketch/upload/plaso/$SYSTEM.plaso /usr/share/timesketch/upload/$SYSTEM" 2>&1 >> /tmp/scripts.log
    # Wait for file to become available
    while [ ! -f /opt/timesketch/upload/plaso/$SYSTEM.plaso ]; do sleep 1;echo "1" >> /tmp/count; done

    # Run timesketch_importer to send Plaso data to Timesketch
    username=TO_CHANGE
    password=TO_CHANGE
    docker exec -i timesketch-worker /bin/bash -c "timesketch_importer -u $username -p "$password" --host http://timesketch-web:5000 --timeline_name $SYSTEM --sketch_name $LABEL /usr/share/timesketch/upload/plaso/$SYSTEM.plaso" 2>&1 >> /tmp/scripts2.log

    # Copy Plaso files to dir being watched to upload to S3
    cp -ar /opt/timesketch/upload/plaso/$SYSTEM.plaso /opt/timesketch/upload/plaso_complete/
}

inotifywait -m -r -e move "$PARENT_DATA_DIR" --format "%f" | while read ZIP
do
  extension="${ZIP##*.}"
  if [[ $extension == "zip" ]]; then
	process_files $ZIP &
  fi
done
