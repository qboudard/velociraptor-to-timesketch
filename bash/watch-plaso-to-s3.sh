# Watch this directory for new Plaso files (ie: vr_kapetriage_$system.plaso)

PARENT_DATA_DIR="/opt/Plaso_data"
BUCKET_NAME = ""

inotifywait -m -r -e close_write "$PARENT_DATA_DIR" --format "%f" | while read PLASO
do
  extension="${PLASO##*.}"
  if [[ $extension == "plaso" ]]; then
    # Get name of directory
    echo $PLASO
    # upload to S3
    aws s3 cp $PARENT_DATA_DIR/$PLASO s3://$BUCKET_NAME/$PLASO
  fi
done
