#!/bin/bash
#
#
export NB_ORA_SERV=p0bkp-nbu001c.region.vtb.ru
export NB_ORA_CLIENT=edkdb102l.region.vtb.ru
export NB_ORA_POLICY=1353_wss_db_4_3_0_all_1m_lan_00024
export NB_ORA_PC_SCHED=WSSLEGA_AL_full
#export NB_ORA_PC_SCHED=WSSLEGA_full

./ora_hot.sh
#./ora_hotsp.sh

