#!/bin/bash
# Entrypoint for SAS OQ
/opt/sas/viya/home/bin/sas-analytics-pro-entrypoint.sh --batch /addons/sasoq/sasoq.sas
sed -i 's/defined @/ @/g' /opt/sas/viya/home/SASFoundation/sastest/sasoq_startup.pm
/opt/sas/viya/home/SASFoundation/sastest/sasoq.sh ${@}