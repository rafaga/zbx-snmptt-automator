#!/bin/sh

rm -fr processed/
rm -f zabbix/*
rm zfiles.txt
rm convertmibs.txt
rm error.log
rm -f mibs/*
rm -f etc/snmp/*
rm -f etc/snmp/snmptt.conf.d/*
cp conf/* etc/snmp/
