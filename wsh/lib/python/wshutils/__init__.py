# Header will go here when ready to publish
import os
import sys
import logging
from wshutils.logger import LOG_CONTEXT

_log = logging.getLogger(LOG_CONTEXT)

__version__ = '0.1'

CONST_DIR_TMP = "/tmp"
CONST_WSH_ROOT = os.getenv('WSH_ROOT', '')

###############################################################################
# Classes
###############################################################################


###############################################################################
# Functions
###############################################################################

def clean_up(returnValue=0):
  """Skeleton function for handling default exit behaviours consistently"""
  sys.exit(returnValue)
