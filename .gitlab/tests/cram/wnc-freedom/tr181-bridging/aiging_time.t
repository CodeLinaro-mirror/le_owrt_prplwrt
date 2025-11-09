Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check Aiging time type:

  $ R "ba-cli 'dump -p Bridging.Bridge.1.'" | grep 'AgingTime'
  P....... <public>         uint32 Bridging.Bridge.1.AgingTime=300
