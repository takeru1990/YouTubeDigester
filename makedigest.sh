#!/bin/bash
# 引数は [YouTube動画のURL] と [出力ファイル名]
# youtube-dl と ffmpeg と curl が前提
# カレントディレクトリに bgm.mp3 を置くこと
 
##################################################
# prefix and suffix of the thumbnail URL
prefix="http://img.youtube.com/vi/"
suffix="/maxresdefault.jpg"
 
# Parameters setting
id=`echo ${1} | rev | cut -c 1-11 | rev`
url=$prefix$id$suffix # thumbnail url
vid_sec=60 # output video duration in sec
fadetime="3" # fade out duration in sec
 
# file names ... used in command line
bgm="bgm.mp3" # bgm file path
thumb="${2}.jpg"
video="${2}.mp4"
mute="${2}_mute.mp4"
short="${2}_short.mp4"
sound="${2}_sound.mp4"
thumb_scaled="${2}_scaled.jpg"
outname="./digests/${2}.mp4" #output video path and filename
 
# make directory if not exist
mkdir -p digests
 
##################################################
# download the thumnail image
curl -o ${thumb} ${url}
 
# download video
youtube-dl -o ${video} -f mp4 ${1}
 
##################################################
# get video duration
duration=`ffmpeg -i ${video} 2>&1 | grep "Duration"| cut -d ' ' -f 4 | sed s/,// | sed 's@\..*@@g' | awk '{ split($1, A, ":"); split(A[3], B, "."); print 3600*A[1] + 60*A[2] + B[1] }'`
 
# remove audio
ffmpeg -y -i ${video} -c copy -an ${mute}
 
# change duration into ${vid_sec}
# ${mute} -> ${short}
ffmpeg -y -i ${mute} -filter:v "setpts=${vid_sec}*PTS/${duration}" ${short}
 
# change thumbnail size as same as video resolution
# get x size of "${short}"
width=`ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=nw=1:nk=1 ${short}`
ffmpeg -y -i ${thumb} -vf scale=${width}:-1 ${thumb_scaled}
 
# add thumbnail at beginning and bgm
# ${short} -> ${sound}
ffmpeg -y -i ${short} -i ${thumb_scaled} -filter_complex "[0:v][1:v]overlay=0:0:enable=between(t\,0\,3)" -i ${bgm} -shortest ${sound}
 
##################################################
# get frame rate
fr=`ffmpeg -i ${sound} 2>&1 | sed -n "s/.*, \(.*\) fp.*/\1/p"`
 
fadestarttime=`expr ${vid_sec} - ${fadetime}`
fadingtime=${fadetime}
 
fadestartframe=`echo "scale=5; ${fadestarttime} * ${fr}" | bc`
fadingframe=`echo "scale=5; ${fadetime} * ${fr}" | bc`
 
# fade out at end
# And encode for Twitter
ffmpeg -y -i ${sound} -vf "fade=out:${fadestartframe}:${fadingframe}" -af "afade=out:st=${fadestarttime}:d=${fadingtime}" -vcodec libx264 -pix_fmt yuv420p -strict -2 -acodec aac ${outname}
 
##################################################
# remove all intermediate files
rm ${mute} ${short} ${thumb_scaled} ${sound} ${thumb} ${video}
 
exit 0
