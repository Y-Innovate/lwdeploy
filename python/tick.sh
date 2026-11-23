#!/bin/sh
# One tick of the LWD scheduler, run by JCL/LWDTICK under BPXBATCH.
# PYZ (Python home) and VENV (a venv with requests) come from STDENV.
# Exit status: that of tick.py, 0 when every tick went well.

export PATH=$PYZ/bin:$PATH
export LIBPATH=$PYZ/lib:$LIBPATH

export _BPXK_AUTOCVT='ON'
export _CEE_RUNOPTS='FILETAG(AUTOCVT,AUTOTAG) POSIX(ON)'
export _TAG_REDIR_ERR=txt
export _TAG_REDIR_IN=txt
export _TAG_REDIR_OUT=txt

# The tick directory is read-only for the scheduler's userid: no __pycache__
export PYTHONDONTWRITEBYTECODE=1

cd "$(dirname "$0")" || exit 8

. "$VENV/bin/activate" || exit 8

python tick.py "$1"
exit $?
