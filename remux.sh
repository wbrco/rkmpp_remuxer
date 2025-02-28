#!/bin/bash
# Hardware decoders : encoders available
# -------------------------------------
#   av1 - av1_rkmpp : None
#   h263 -  h263_rkmpp : None
#   h264 -  h264_rkmpp : h264_rkmpp
#   h265/hevc - hevc_rkmpp : hevc_rkmpp
#   mjpeg - None : mjpeg_rkmpp
#   mpeg1video -  mpeg1_rkmpp : None
#   mpeg2video - mpeg2_rkmpp : None
#   mpeg4 -`mpeg4_rkmpp : None
#   vp8 - vp8_rkmpp : None
#   vp9 - vp9_rkmpp : None

# for logging
now() {
  echo "[$(date +'%m/%d/%y %I:%M:%S %p %Z')]"
}

log() {
	message="${1}"
	echo "$(now) $message"|tee -a $BASEDIR/remux.log
}

CONVERT_DIR=$1
CONVERT_DIR="${CONVERT_DIR%/}"
BASEDIR="$(pwd)"

# Array of hardware decoders available
# Note - problems with the mpeg4_rkmpp decoder - use software instead!
HW_DECODERS=("av1" "h263" "h264" "hevc" "mpeg1video" "mpeg2video" "vp8" "vp9")
SKIP_FILES=("db" "txt" "jpg" "png")

if ( [ ! $CONVERT_DIR ] || [ $CONVERT_DIR = "-h" ] ); then
	echo "remux.sh DIR"
	echo "Where DIR is either a relative path (no /) or absolute path (starts with /)"
	exit 0
fi

# Set up ffprobe/ffmpeg report settings via env to catch errors to the log file
# without having to do a bunch or fancy redirection.
export FFREPORT=file=$BASEDIR/remux.log:level=16

# If my log file doesn't exist, create it
if [ ! -f remux.log ]; then
  touch remux.log
	chmod 766 remux.log
else
  log "Log file exists. Restart? "
fi

COUNT=0
log "Starting conversion task."

while read FILENAME; do

  # Skip obvious non-video files so no useless ffprobe/ffmpeg errors.
  EXT=${FILENAME##*.}
  if [ "$EXT" = "" ]; then
    log "Skipping $FILENAME - not a video file"
    continue
  fi
  if [[ " ${SKIP_FILES[*]} " =~ [[:space:]]${EXT}[[:space:]] ]]; then
    log "Skipping $FILENAME - not a video file"
    continue
  fi

 # FILENAME="videos/26406-1080p.mp4"
  FILEDIR="$(dirname "${FILENAME}")"

 # Let's get my filenames set up.
 # first trim the extension.
  OLDFILE="$(basename "${FILENAME}")"

 # Remove any XXXXp text from the filename since it may not be accurate.
  NEWBASE=$(echo "$OLDFILE" | sed -e "s/[0-9]\{3,\}p//g")

  FILEPATH="${BASEDIR}/${FILEDIR}"

 # Init some vars I'll need later.
  OLD_VIDEO_CODEC=""
  ORIG_WIDTH=""
  ORIG_HEIGHT=""
  ORIG_ASPECT=""
  SCALER=""
  DECODER=""
  SUFFIX=""
  OLD_AUDIO_CODEC=""
  AUDIO_CODEC=""
	ORIG_SIZE=$(ls -sh "${FILENAME}"|cut -d ' ' -f1)

 # Move to where the video is located
  cd "${FILEPATH}"

 # Get the video info for the original file
 # Get my streams.
  PROBE_RES=$(ffprobe -v error -hide_banner -show_entries \
  stream=codec_type,codec_name,width,height,display_aspect_ratio,pix_fmt,level -of compact \
	-probesize 10000000 -analyzeduration 10000000 -i "${OLDFILE}")
	if [ $? -ne 0 ]; then
		log "$OLDFILE - ffprobe threw error."
		log "Continuing to the next file."
		cd $BASEDIR
		continue
	fi

 # Separate them and get them into arrays
  mapfile -t -d '|' AUDIO_ARR <<< $(oldifs=IFS;IFS=' ';STREAMS=($PROBE_RES);echo "${STREAMS}" | grep audio)
  mapfile -t -d '|' VIDEO_ARR <<< $(oldifs=IFS;IFS=' ';STREAMS=($PROBE_RES);echo "${STREAMS}" | grep video)

 # Parse out the video info and set vars
  for val in "${VIDEO_ARR[@]}"; do
    key=$(echo "$val" | cut -d '=' -f1)
    val=$(echo "$val" | cut -d '=' -f2)
    case $key in
      codec_name) OLD_VIDEO_CODEC="${val}" ;;
      width) ORIG_WIDTH="${val}" ;;
      height) ORIG_HEIGHT="${val}" ;;
      display_aspect_ratio) ORIG_ASPECT="${val}" ;;
    esac
  done

 # Repeat for the audio - but we only need to set the output codec if it's not already aac.
 for aval in "${AUDIO_ARR[@]}"; do
   akey=$(echo "$aval" | cut -d '=' -f1)
   aval=$(echo "$aval" | cut -d '=' -f2)
   if [[ "$akey" = "codec_name" ]]; then
     OLD_AUDIO_CODEC="${aval}"
     if [[ "$aval" =~ ^(aac).+ ]]; then
      # If it's aac, just copy!
       AUDIO_CODEC="-c:a copy"
     else
      # Transcode the audio even if it's a format compatible with mp4!
       AUDIO_CODEC="-c:a aac"
    fi
  fi
 done

 # If file is 720p and hevc, move on to next file.
  if  [[ "$ORIG_HEIGHT" -le 721 ]] && [[ $OLD_VIDEO_CODEC = "hevc" ]]; then
    log "$OLDFILE already transcoded."
		cd $BASEDIR
    continue
  fi

 # determine how my scaler will work to maintain aspect ratio
  if [[ "$ORIG_WIDTH" -ge 1280 ]] || [[ "$ORIG_HEIGHT" -ge 720 ]]; then

	# Calculate my aspect ratio
    ratio=$(echo "scale=4; $ORIG_WIDTH / $ORIG_HEIGHT" | bc -l )
    newwidth=$(echo "$ratio * 720" | bc | awk -F '.' '{print $1}')

    if [ $newwidth -le 1280 ]; then
      SCALER='-vf scale=-1:720'
      SUFFIX="-hevc_720P.mp4"
      else
        SCALER='-vf scale=1280:-1'
        SUFFIX="-hevc_720P.mp4"
    fi
  else
    SCALER="-vf scale=$ORIG_WIDTH:$ORIG_HEIGHT"
    SUFFIX="-hevc.mp4"
  fi

  NEWFILE="${NEWBASE%.*}${SUFFIX}"
  log "Starting conversion of $OLDFILE  ==>  $NEWFILE"
  log "$OLDFILE: width = $ORIG_WIDTH, height = $ORIG_HEIGHT, video codec = $OLD_VIDEO_CODEC, audio codec = $OLD_AUDIO_CODEC, size = $ORIG_SIZE"

 # If no hardware decoder available, set ffmpeg to use software.
  if [[ " ${HW_DECODERS[*]} " =~ [[:space:]]${OLD_VIDEO_CODEC}[[:space:]] ]]; then
   DECODER="-hwaccel rkmpp"
   log "Using hardware decoder for codec $OLD_VIDEO_CODEC"
  else
   log "Using software decoder for codec $OLD_VIDEO_CODEC"
  fi

 # Let's do this!
	log "$NEWFILE: decoder = $DECODER, scaler = $SCALER, audio codec = $AUDIO_CODEC"

 # hevc_rkmpp does not support CRF
 # CQP stuff: https://www.oupree.com/knowledge/Whats-Quantization-Parameter-QP-in-Video-Encoder.html
 # More: https://slhck.info/video/2017/03/01/rate-control.html
  ffmpeg -v error -nostdin -hide_banner -y $DECODER -i "${OLDFILE}" $AUDIO_CODEC -strict -2 $SCALER -c:v hevc_rkmpp -tier high -rc_mode CQP -qp_init 26 -qp_max 35 -qp_min 18 "${NEWFILE}"

 # If ffmpeg threw an error, trap it and move on.
 	if [ $? -ne 0 ]; then
 		log "ffmpeg threw an error. Moving on to the next file"
 		cd $BASEDIR
 		continue
	fi
	NEW_SIZE=$(ls -sh "${NEWFILE}"|cut -d ' ' -f1)
	log "Conversion of $OLDFILE ==> $NEWFILE complete. New size = $NEW_SIZE."

 # Does my new file exist and is at least 50M in size?
	if ( [ ! -f "${NEWFILE}" ] || [ $(stat -c%s "${NEWFILE}") -le 50000000 ] ); then
		log "$NEWFILE doesn't exist or is very small. Moving on to the next file"
		cd $BASEDIR
		continue
	fi

 # Delete the old file
	rm "${OLDFILE}"

 # Increment my counter and get back to my base dir for the next file
	((COUNT++))
	cd $BASEDIR
done < <(find $CONVERT_DIR/ -type f)

log "Process completed. $COUNT files converted."
