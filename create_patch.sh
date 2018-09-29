# command to create patch files to the MIBs

 diff -ruN -I '^MIB:*' processed/abb/ABB-NSD570-MIB.conf patch/source/ABB-NSD570-MIB.conf > patch/ABB-NSD570-MIB.conf.patch
 diff -ruN -I '^MIB:*' processed/SWT3000/SIEMENS-SWT3000R35.conf patch/source/SIEMENS-SWT3000R35.conf > patch/SIEMENS-SWT3000R35.conf.patch

