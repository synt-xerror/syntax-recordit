#!/bin/env bash

# By SyntaxError!
# github.com/synt-xerror

CONFIG_DIR="$HOME/.config/syntax-recorder"

BCKP_DIR="$CONFIG_DIR/backup"
REC_DIR="$CONFIG_DIR/recording"
TRANS_DIR="$CONFIG_DIR/trans"
LOG_FILE="$CONFIG_DIR/log.log"

STATUS_FILE="$CONFIG_DIR/stts"
MIC_LAST="$CONFIG_DIR/mic_last"
INT_LAST="$CONFIG_DIR/int_last"
NAME_LAST="$CONFIG_DIR/name_last"

mkdir -p "$CONFIG_DIR" "$REC_DIR" "$BCKP_DIR" "$TRANS_DIR"

function w_log() {
  local cmd="$1"
  echo "======== $(date) ========" >> "$LOG_FILE"
  echo "Command: $cmd" >> "$LOG_FILE"
  
  echo "Output:"
  echo "" >> "$LOG_FILE"

  eval "$cmd" &>> "$LOG_FILE"
    
  if [[ $? -eq 0 ]]; then
    echo "Status: SUCCESS" >> "$LOG_FILE"
  else
    echo "Status: ERROR" >> "$LOG_FILE"
  fi

  echo "" >> "$LOG_FILE"
  echo "==============================================" >> "$LOG_FILE"
  echo "" >> "$LOG_FILE"
}

# Inicializa status
[ -f "$STATUS_FILE" ] || echo 0 >"$STATUS_FILE"
STATUS=$(<"$STATUS_FILE")

function SET_STATUS() {
  echo "$1" >"$STATUS_FILE"
}

if [[ "$1" == "--reset" ]]; then
  SET_STATUS 0
  STATUS=$(cat "$STATUS_FILE")
  
  if [[ $STATUS == 0 ]]; then
    echo "Status reset successfully."
  else
    echo "Something got wrong while reseting status."
  fi

  exit 0
fi

function backup() {
  VIDEO_NAME=$(<"$NAME_LAST")
  INTERNAL_AUDIO="${VIDEO_NAME}-int.m4a"
  MIC_AUDIO="${VIDEO_NAME}-mic.m4a"

  TARGET_DIR=$(<"$CONFIG_DIR/last_dir")
  VIDEO_BCKP="$BCKP_DIR/${VIDEO_NAME}"

  mkdir -p "$VIDEO_BCKP"

  [ -f "$REC_DIR/$INTERNAL_AUDIO" ] && mv "$REC_DIR/$INTERNAL_AUDIO" "$VIDEO_BCKP" && cp "$VIDEO_BCKP/$INTERNAL_AUDIO" "$TRANS_DIR"/
  [ -f "$REC_DIR/$MIC_AUDIO" ] && mv "$REC_DIR/$MIC_AUDIO" "$VIDEO_BCKP" && cp "$VIDEO_BCKP/$MIC_AUDIO" "$TRANS_DIR"/

  mv "$REC_DIR/${VIDEO_NAME}.mp4" "$VIDEO_BCKP"/
}

if [[ "$STATUS" != "2" ]]; then
  trap '
  SET_STATUS 0
  exit 0
  ' SIGINT # libera interrupção
else
  trap 'notify-send -t 1000 "yo chill out bro" "You can stop recording by using the comand 'record'"' SIGINT # impede interrupção
fi

if [[ "$STATUS" == "0" ]]; then
  rm -rf $REC_DIR/*
  rm -rf $TRANS_DIR/*
fi

if [[ "$STATUS" == "2" ]]; then
  notify-send -t 3000 "Error: Wait!" "There is already a video in process!"
  exit 1
fi

# Finaliza gravação existente
if [[ "$STATUS" == "1" ]]; then
  SET_STATUS 2 # 2 = processando

  pgrep -x -f "gpu-screen-recorder" && pkill -INT -x -f gpu-screen-recorder
  pgrep -x "arecord" && pkill -INT -x arecord
  pgrep -x "ffmpeg" && pkill -INT -x ffmpeg
  pgrep -x "ffplay" && pkill -INT -x ffplay

  notify-send -t 3000 "Record stopped." "Processing your video...\nWait for a notification."

  # Backup
  backup

  cp "$VIDEO_BCKP/${VIDEO_NAME}.mp4" "$TRANS_DIR"/

  mkdir -p "$TARGET_DIR"

  OUTPUT="$TRANS_DIR/loading.mp4"
  COMPRESSED="$TRANS_DIR/compressed.mp4"

  mic_flag=$(<"$MIC_LAST")
  int_flag=$(<"$INT_LAST")

  AUDIO_TEMP="$TRANS_DIR/$VIDEO_NAME-AUDIO.m4a"

  if [[ "$mic_flag" == "1" && "$int_flag" == "1" ]]; then
      w_log "ffmpeg -y \
          -i '$TRANS_DIR/$VIDEO_NAME-int.m4a' \
          -i '$TRANS_DIR/$VIDEO_NAME-mic.m4a' \
          -filter_complex '[1:a]adelay=1000|1000,volume=2.0[mic]; [0:a][mic]amix=inputs=2:duration=longest[aout]' \
          -map '[aout]' -c:a aac '$AUDIO_TEMP'"

  elif [[ "$mic_flag" == "1" ]]; then
      w_log "ffmpeg -y \
          -i '$TRANS_DIR/$VIDEO_NAME-mic.wav' \
          -filter_complex '[0:a]adelay=1000|1000,volume=2.0[mic]' \
          -c:a aac '$AUDIO_TEMP'"

  elif [[ "$int_flag" == "1" ]]; then
      w_log "ffmpeg -y \
          -i '$TRANS_DIR/$VIDEO_NAME-int.wav' \
          -c:a aac '$AUDIO_TEMP'"

  else
      w_log "ffmpeg -i '$TRANS_DIR/$VIDEO_NAME.mp4' -c copy '$OUTPUT'"
  fi

  wait

  if [[ "$mic_flag" == "1" || "$int_flag" == "1" ]]; then
    ffmpeg -y -i "$TRANS_DIR/$VIDEO_NAME.mp4" -i "$AUDIO_TEMP" \
    -c:v copy -c:a copy "$OUTPUT"
  fi

  # Verifica se output foi gerado
  if [[ ! -f "$OUTPUT" ]]; then
      notify-send "Error!" "An error ocurred during video processing. Check log before trying again."

      yad --title="Error." \
          --text="Seems like ocurred an error with the video processing,\nwould you like to open the log file?" \
          --button="Yes:0" \
          --button="No:1"

      if [[ $? -eq 0 ]]; then
        xdg-open "$LOG_FILE"
      fi

      SET_STATUS 0
      exit 3
  fi

  # Corte
  ffmpeg -ss 4 -i "$OUTPUT" -c copy "$COMPRESSED"


  # Garante que não sobrescreve arquivos existentes
  FINAL="$TARGET_DIR/$VIDEO_NAME.mp4"
  COUNT=1
  while [[ -f "$FINAL" ]]; do
      FINAL="$TARGET_DIR/${VIDEO_NAME}_$COUNT.mp4"
      ((COUNT++))
  done

  mv "$COMPRESSED" "$FINAL"
  notify-send "Done!" "Saved $FINAL"

  SET_STATUS 0 # 0 = Aguardando nova gravação
  exit 0
fi

# -------------------------------
#         Nova gravação
# -------------------------------

if [[ "$STATUS" == "0" ]]; then
  rm -rf $REC_DIR/*
  rm -rf $TRANS_DIR/*
fi

# Seleção de diretório e nome

lastdir=$(<"$CONFIG_DIR/last_dir")
echo $lastdir

if [[ -n "$lastdir" && -r "$lastdir" ]]; then
    cd "$lastdir"
else
    echo "$HOME" > "$CONFIG_DIR/last_dir"
    cd "$HOME"
fi

DIR=$(yad --file --directory --text="Escolha um diretório") || {
  yad --info --text="Operação cancelada." --button=OK
  exit 0
}
echo "$DIR" > "$CONFIG_DIR/last_dir"

cd "$CONFIG_DIR"

function name() {
  NAME=$(yad --entry --text="Digite o nome do vídeo (sem extensão)") || {
    yad --info --text="Operação cancelada." --button=OK
    exit 0
  }
}

name

counter=0
newname="$NAME"

while [[ -d "$BCKP_DIR/$newname" ]]; do
    counter=$((counter + 1))
    newname="$NAME-($counter)"
done

NAME="$newname"

while echo "$NAME" | grep -q '[/:*?"<>|]' || [[ -z "${NAME// /}" ]]; do
    yad --info --text="Nome inválido! Tente novamente.\nNão use caracteres especiais ou nomes vazios." --button=OK
    name
done

echo "Nome válido: $NAME"

echo "$NAME" >"$NAME_LAST"

NAME_F="$NAME.mp4"

AUDIO_CHOICES=$(yad --form \
  --text="Ative os áudios desejados" \
  --field="Som interno":CHK TRUE \
  --field="Microfone":CHK TRUE \ ) || {
  yad --info --text="Operação cancelada." --button=OK
  exit 0
}

# Interpreta escolhas
INT=false
MIC=false

[[ $(echo "$AUDIO_CHOICES" | cut -d'|' -f1) == "TRUE" ]] && INT=true
[[ $(echo "$AUDIO_CHOICES" | cut -d'|' -f2) == "TRUE" ]] && MIC=true

if $INT && $MIC; then
  AUDIO_SOURCE="Audio interno e microfone"
elif $INT; then
  AUDIO_SOURCE="Apenas audio interno"
elif $MIC; then
  AUDIO_SOURCE="Apenas microfone"
else
  AUDIO_SOURCE="Nenhum (vídeo sem som)"
fi

WEBCAM_CHOICES=$(yad --list \
  --radiolist \
  --title="Webcam" \
  --text="Deseja usar a webcam?" \
  --column="Selecionar" --column="Resposta" \
  TRUE "Sim" \
  FALSE "Não" ) || {
    yad --info --text="Operação cancelada." --button=OK
    exit 0
}

WEBCAM=$(echo $WEBCAM_CHOICES | cut -d'|' -f2)

if [[ "$(echo $WEBCAM)" == "Ativada" ]]; then
  WC=true
elif [[ "$(echo $WEBCAM)" == "Desativada" ]]; then
  WC=false
fi

yad --info --text="
Revise antes de continuar: \n

Diretório:
$DIR \n

Nome do arquivo:
$NAME_F \n

Fonte de audio:
$AUDIO_SOURCE \n

Webcam:
$WEBCAM

Continuar?
"


if [[ $? -ne 0 ]]; then
  yad --info --text="Operação cancelada." --button=OK
  exit 0
fi

function RECORD_AUDIO() {
  if [[ "$INT" == true && "$MIC" == true ]]; then
    echo "1" > "$MIC_LAST"
    echo "1" > "$INT_LAST"

    w_log "arecord -D hw:0,1,0 -f S16_LE -c 1 -r 16000 | \
          ffmpeg -f s16le -ar 16000 -ac 1 -i - -c:a aac -b:a 128k -f mp4 "$REC_DIR/${NAME}-mic.m4a" &"

    w_log "ffmpeg -f pulse -i alsa_output.pci-0000_00_1b.0.analog-stereo.monitor \
          -ac 1 -ar 16000 -c:a aac -b:a 128k -f mp4 "$REC_DIR/${NAME}-int.m4a" &"

  elif [[ "$INT" == true ]]; then
    echo "0" > "$MIC_LAST"
    echo "1" > "$INT_LAST"

    w_log "ffmpeg -f pulse -i alsa_output.pci-0000_00_1b.0.analog-stereo.monitor \
          -ac 1 -ar 16000 -c:a aac -b:a 128k -f mp4 "$REC_DIR/${NAME}-int.m4a" &"

  elif [[ "$MIC" == true ]]; then
    echo "1" > "$MIC_LAST"
    echo "0" > "$INT_LAST"

    w_log "arecord -D hw:0,1,0 -f S16_LE -c 1 -r 16000 | \
          ffmpeg -f s16le -ar 16000 -ac 1 -i - -c:a aac -b:a 128k -f mp4 "$REC_DIR/${NAME}-mic.m4a" &"

  else
    echo "0" > "$MIC_LAST"
    echo "0" > "$INT_LAST"
    
  fi
}

function WEBCAM() {
  if [[ $WC == true ]]; then
    w_log "ffplay -x 332 -y 250 -left 8 -top 39 /dev/video2"
  fi
}

function START_VIDEO() {
    w_log "gpu-screen-recorder \
          -w screen \
          -f 60 \
          -a default \
          -c h264 \
          -o '$REC_DIR/$NAME.mp4'"
}

WEBCAM &
RECORD_AUDIO &
START_VIDEO &

for i in 3 2 1; do
  notify-send -t 1000 "Recording in:" "<span color='#90a4f4' font='26px'><i><b>$i</b></i></span>"
  sleep 1
done

SET_STATUS 1 # 1 = gravando

# aqui todos estão prontos
echo -e "\nAll devices ready, recording started\n"