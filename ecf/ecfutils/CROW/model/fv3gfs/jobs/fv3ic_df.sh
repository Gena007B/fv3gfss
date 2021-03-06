#! /bin/bash
###############################################################
# < next few lines under version control, D O  N O T  E D I T >
# $Date: 2017-10-30 18:48:54 +0000 (Mon, 30 Oct 2017) $
# $Revision: 98721 $
# $Author: fanglin.yang@noaa.gov $
# $Id: fv3ic.sh 98721 2017-10-30 18:48:54Z fanglin.yang@noaa.gov $
###############################################################

###############################################################
## Author: Rahul Mahajan  Org: NCEP/EMC  Date: August 2017

## Abstract:
## Create FV3 initial conditions from GFS intitial conditions
## EXPDIR : /full/path/to/config/files
## CDATE  : current date (YYYYMMDDHH)
## CDUMP  : cycle name (gdas / gfs)
export EXPDIR=${1:-$EXPDIR}
export CDATE=${2:-$CDATE}
export CDUMP=${3:-$CDUMP}
###############################################################

set -ex
eval $( $HOMEcrow/to_sh.py $CONFIG_YAML export:y scope:platform.general_env import:".*" )
eval $( $HOMEcrow/to_sh.py $CONFIG_YAML export:y scope:workflow.$TASK_PATH from:shell_vars )

# Temporary runtime directory
export DATA="$RUNDIR/$CDATE/$CDUMP/fv3ic$$"
[[ -d $DATA ]] && rm -rf $DATA

# Input GFS initial condition files
export INIDIR="$ICSDIR/$CDATE/$CDUMP"
export ATMANL="$ICSDIR/$CDATE/$CDUMP/siganl.${CDUMP}.$CDATE"
export SFCANL="$ICSDIR/$CDATE/$CDUMP/sfcanl.${CDUMP}.$CDATE"
if [ -f $ICSDIR/$CDATE/$CDUMP/nstanl.${CDUMP}.$CDATE ]; then
    export NSTANL="$ICSDIR/$CDATE/$CDUMP/nstanl.${CDUMP}.$CDATE"
fi

# Output FV3 initial condition files
#export OUTDIR="$ICSDIR/$CDATE/$CDUMP/$CASE/INPUT"
export OUTDIR="$DATA/outdir"
mkdir -p "$OUTDIR"

$HOMEcrow/crow_dataflow_cycle_sh.py "$CROW_DATAFLOW_DB" add "$CDATE"
$HOMEcrow/crow_dataflow_cycle_sh.py "$CROW_DATAFLOW_DB" add "$CDATE"

export OMP_NUM_THREADS_CH=$NTHREADS_CHGRES
export APRUNC=$APRUN_CHGRES

# Call global_chgres_driver.sh
$BASE_GSM/ush/global_chgres_driver.sh
status=$?
if [ $status -ne 0 ]; then
    echo "global_chgres_driver.sh returned with a non-zero exit code, ABORT!"
    exit $status
fi

set -xue

ACTOR=$( echo "$TASK_PATH" | sed 's,\.[^.]*$,,g' )

$HOMEcrow/crow_dataflow_deliver_sh.py -i "$OUTDIR/gfs_ctrl.nc" \
    "$CROW_DATAFLOW_DB" "$CDATE" "$ACTOR" slot=gfs_ctrl_nc

$HOMEcrow/crow_dataflow_deliver_sh.py -m -i "$OUTDIR/{kind}.tile{tile}.nc" \
    "$CROW_DATAFLOW_DB" "$CDATE" "$ACTOR" slot=output_data_tiles

# $HOMEcrow/crow_dataflow_deliver_sh.py \
#     -i "$OUTDIR/RESTART/{cycle:%Y%m%d.%H%M%S}0000.{kind}.tile{tile:%d}.nc" \
#     "$crow_db" "$CDATE" "$ACTOR" "slot=end_time_tiles"

# $HOMEcrow/crow_dataflow_deliver_sh.py \
#     -i "$OUTDIR/RESTART/{kind}.tile{tile:%d}.nc" \
#     "$crow_db" "$CDATE" "$ACTOR" "slot=end_time_tiles"

# $HOMEcrow/crow_dataflow_deliver_sh.py \
#     -i "$OUTDIR/RESTART/{cycle:%Y%m%d" \

###############################################################
# Exit cleanly
exit 0
