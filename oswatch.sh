#!/bin/bash
ipaddress=`ip a|grep "global"|awk '{print $2}' |awk -F/ '{print $1}'`
file_output=${ipaddress}'os_linux_summary.html'
td_str=''
th_str=''
#yum -y install bc sysstat net-tools
create_html_css(){
  echo -e "<html>
<head>
<style type="text/css">
    body        {font:12px Courier New,Helvetica,sansserif; color:black; background:White;}
    table,tr,td {font:12px Courier New,Helvetica,sansserif; color:Black; background:#FFFFCC; padding:0px 0px 0px 0px; margin:0px 0px 0px 0px;} 
    th          {font:bold 12px Courier New,Helvetica,sansserif; color:White; background:#0033FF; padding:0px 0px 0px 0px;} 
    h1          {font:bold 12pt Courier New,Helvetica,sansserif; color:Black; padding:0px 0px 0px 0px;} 
</style>
</head>
<body>"
}
create_html_head(){
echo -e "<h1>$1</h1>"
}
create_table_head1(){
  echo -e "<table width="68%" border="1" bordercolor="#000000" cellspacing="0px" style="border-collapse:collapse">"
}
create_table_head2(){
  echo -e "<table width="100%" border="1" bordercolor="#000000" cellspacing="0px" style="border-collapse:collapse">"
}
create_td(){
    td_str=`echo $1 | awk 'BEGIN{FS="|"}''{i=1; while(i<=NF) {print "<td>"$i"</td>";i++}}'`
}
create_th(){
    th_str=`echo $1|awk 'BEGIN{FS="|"}''{i=1; while(i<=NF) {print "<th>"$i"</th>";i++}}'`
}
create_tr1(){
  create_td "$1"
  echo -e "<tr>
    $td_str
  </tr>" >> $file_output
}
create_tr2(){
  create_th "$1"
  echo -e "<tr>
    $th_str
  </tr>" >> $file_output
}
create_tr3(){
  echo -e "<tr><td>
  <pre style=\"font-family:Courier New; word-wrap: break-word; white-space: pre-wrap; white-space: -moz-pre-wrap\" >
  `cat $1`
  </pre></td></tr>" >> $file_output
}
create_table_end(){
  echo -e "</table>"
}
create_html_end(){
  echo -e "</body></html>"
}
NAME_VAL_LEN=12
name_val () {
   printf "%+*s | %s\n" "${NAME_VAL_LEN}" "$1" "$2"
}
get_physics(){
    name_val "巡检时间" "`date`"
    name_val "主机名" "`uname -n`"
    name_val "系统版本" "`cat /etc/{oracle,redhat,SuSE,centos}-release 2>/dev/null|sort -ru|head -n1`"
    name_val "内核版本" "`uname -r`"
    name_val "架构" "CPU=`lscpu|grep Architecture|awk -F: '{print $2}'|sed 's/^[[:space:]]*//g'`;OS=`getconf LONG_BIT`-bit"
}
get_cpuinfo () {
   file="/proc/cpuinfo"
   virtual=`grep -c ^processor "${file}"`
   physical=`grep 'physical id' "${file}" | sort -u | wc -l`
   cores=`grep 'cpu cores' "${file}" | head -n 1 | cut -d: -f2`
   model=`grep "model name" "${file}"|sort -u|awk -F: '{print $2}'`
   speed=`grep -i "cpu MHz" "${file}"|sort -u|awk -F: '{print $2}'`
   cache=`grep -i "cache size" "${file}"|sort -u|awk -F: '{print $2}'`
   SysCPUIdle=`vmstat | sed -n '$ p' | awk '{print $15}'`
   [ "${physical}" = "0" ] && physical="${virtual}"
   [ -z "${cores}" ] && cores=0
   cores=$((${cores} * ${physical}));
   htt=""
   if [ ${cores} -gt 0 -a $cores -lt $virtual ]; then htt=yes; else htt=no; fi
   name_val "线程" "physical = ${physical}, cores = ${cores}, virtual = ${virtual}, hyperthreading = ${htt}"
   name_val "cpu型号" "${physical}*${model}"
   name_val "速度" "${virtual}*${speed}"
   name_val "缓存" "${virtual}*${cache}"
   name_val "CPU空闲率(%)" "${SysCPUIdle}%"
}
get_netinfo(){
   echo "interface | status | ipadds     |      mtu    |  Speed     |     Duplex" >>/tmp/tmpnet_h1_`date +%y%m%d`.txt
   for ipstr in `ifconfig -a|grep ": flags"|awk  '{print $1}'|sed 's/.$//'`
   do
      ipadds=`ifconfig ${ipstr}|grep -w inet|awk '{print $2}'`
      mtu=`ifconfig ${ipstr}|grep mtu|awk '{print $NF}'`
      speed=`ethtool ${ipstr}|grep Speed|awk -F: '{print $2}'`
      duplex=`ethtool ${ipstr}|grep Duplex|awk -F: '{print $2}'`
      echo "${ipstr}"  "up" "${ipadds}" "${mtu}" "${speed}" "${duplex}"\
      |awk '{print $1,"|", $2,"|", $3,"|", $4,"|", $5,"|", $6}'  >>/tmp/tmpnet1_`date +%y%m%d`.txt
   done
}
get_cpuuse(){
   echo "#######################################  cpu使用率  #######################################" >>/tmp/tmp_cpuuse_`date +%y%m%d`.txt
   mpstat -P ALL 10 6 >>/tmp/tmp_cpuuse_`date +%y%m%d`.txt
}
get_connections (){
  filemax=`cat /proc/sys/fs/file-max`
  name_val "Number of concurrent connections" "${filemax}"
}
get_ulimitinfo(){
   echo "#######################################  系统限制最大进程数  #######################################" >>/tmp/tmp_ulimitinfo_`date +%y%m%d`.txt
   ulimit -a >>/tmp/tmp_ulimitinfo_`date +%y%m%d`.txt
}
get_meminfo(){
   echo "Locator   |Size     |Speed       |Form Factor  | Type      |    Type Detail" >>/tmp/tmpmem3_h1_`date +%y%m%d`.txt
   dmidecode| grep -v "Memory Device Mapped Address"|grep -A12 -w "Memory Device" \
   |egrep "Locator:|Size:|Speed:|Form Factor:|Type:|Type Detail:" \
   |awk -F: '/Size|Type|Form.Factor|Type.Detail|^[\t ]+Locator/{printf("|%s", $2)}/^[\t ]+Speed/{print "|" $2}' \
   |grep -v "No Module Installed" \
   |awk -F"|" '{print $4,"|", $2,"|", $7,"|", $3,"|", $5,"|", $6}' >>/tmp/tmpmem3_t1_`date +%y%m%d`.txt
   free -glht >>/tmp/tmpmem2_`date +%y%m%d`.txt
   memtotal=`vmstat -s | head -1 | awk '{print $1}'`
   avm=`vmstat -s| sed -n '3p' | awk '{print $1}'`
   name_val "Mem_used_rate(%)" "`echo "100*${avm}/${memtotal}" | bc`%" >>/tmp/tmpmem1_`date +%y%m%d`.txt
  
}
get_diskinfo(){
   echo "Filesystem        |Type   |Size |  Used  | Avail | Use%  | Mounted on | Opts" >>/tmp/tmpdisk_h1_`date +%y%m%d`.txt
   df -ThP|grep -v tmpfs|sed '1d'|sort >/tmp/tmpdf1_`date +%y%m%d`.txt
   mount -l|awk '{print $1,$6}'|grep ^/|sort >/tmp/tmpdf2_`date +%y%m%d`.txt
   join /tmp/tmpdf1_`date +%y%m%d`.txt /tmp/tmpdf2_`date +%y%m%d`.txt\
   |awk '{print $1,"|", $2,"|", $3,"|", $4,"|", $5,"|", $6,"|", $7,"|", $8}' >>/tmp/tmpdisk_t1_`date +%y%m%d`.txt 
   lsblk >>/tmp/tmpdisk1_`date +%y%m%d`.txt 
   for disk in `ls -l /sys/block|awk '{print $9}'|sed '/^$/d'|grep -v fd`
   do
      echo "${disk}" `cat /sys/block/${disk}/queue/scheduler`  >>/tmp/tmpdisk2_`date +%y%m%d`.txt 
   done
   pvs >>/tmp/tmpdisk3_`date +%y%m%d`.txt
   echo "======================  =====  =====  =====  =====  =====  ==========  =======" >>/tmp/tmpdisk3_`date +%y%m%d`.txt
   vgs >>/tmp/tmpdisk3_`date +%y%m%d`.txt
   echo "======================  =====  =====  =====  =====  =====  ==========  =======" >>/tmp/tmpdisk3_`date +%y%m%d`.txt
   lvs >>/tmp/tmpdisk3_`date +%y%m%d`.txt
}
get_topproc(){
   #os load
   echo "#######################################  网络流量情况  #######################################" >>/tmp/tmpload_`date +%y%m%d`.txt
   sar -n DEV 10 6 >>/tmp/tmpload_`date +%y%m%d`.txt
   echo "#######################################  系统资源变化  #######################################" >>/tmp/tmpload_`date +%y%m%d`.txt
   vmstat -S M 10 6  >>/tmp/tmpload_`date +%y%m%d`.txt
   #top cpu
   mpstat 1 5 >>/tmp/tmptopcpu_`date +%y%m%d`.txt
   echo "#######################################  消耗CPU前十排行  #######################################" >>/tmp/tmptopcpu_`date +%y%m%d`.txt
   ps aux|head -1 >>/tmp/tmptopcpu_`date +%y%m%d`.txt
   ps aux|grep -v PID|sort -rn -k +3|head  >>/tmp/tmptopcpu_`date +%y%m%d`.txt
   #top mem
   echo "#######################################  消耗内存前十排行  #######################################" >>/tmp/tmptopmem_`date +%y%m%d`.txt
   ps aux|head -1 >>/tmp/tmptopmem_`date +%y%m%d`.txt
   ps aux|grep -v PID|sort -rn -k +4|head  >>/tmp/tmptopmem_`date +%y%m%d`.txt
   echo "TOP10 CPU Resource Process" >>/tmp/tmptopmem_`date +%y%m%d`.txt
   top -bn1 -o "%CPU"|sed  -n '1,17p' 
   #top i/o
   echo "#######################################  磁盘io情况  #######################################" >>/tmp/tmptopio_`date +%y%m%d`.txt
   iostat -k -d 10 5  >>/tmp/tmptopio_`date +%y%m%d`.txt
}
get_crontablist(){
   crontab -l >>/tmp/tmp_crontab_`date +%y%m%d`.txt
  if [ -s /tmp/tmp_crontab_`date +%y%m%d`.txt ] ; then 
    echo 'ths file is not empyt and file info'
  else
    echo '#### 无定时任务 ####' >>/tmp/tmp_crontab_`date +%y%m%d`.txt
  fi
}
get_crontab_content(){
   crontab_content_log=/tmp/tmp_crontab_content_`date +%y%m%d`.txt
   crontab -l|awk -F ' ' '{ print $NF}' >>$crontab_content_log

   contrab_num=`crontab -l|awk -F ' ' '{ print $NF}'|wc -l`
   if [ $contrab_num -ne 0 ];then
   count=1
   while [ $count -le $contrab_num ]
     do
       echo "#######################################  获取系统定时任务脚本 $count 内容开始  #######################################" >>/tmp/tmp_crontab_shellcontent_`date +%y%m%d`.txt
       cat `sed -n -e "${count}p" $crontab_content_log` >>/tmp/tmp_crontab_shellcontent_`date +%y%m%d`.txt
       echo -e "\n#######################################  获取系统定时任务脚本 $count 内容结束  #######################################\n" >>/tmp/tmp_crontab_shellcontent_`date +%y%m%d`.txt
	   count=$[${count}+1]
     done
   else
     echo '#### 无定时执行脚本 ####' >>/tmp/tmp_crontab_shellcontent_`date +%y%m%d`.txt
   fi
}
create_html(){
  rm -rf $file_output
  touch $file_output
  create_html_css >> $file_output
  
  create_html_head "系统基本信息" >> $file_output
  create_table_head1 >> $file_output
  get_physics >>/tmp/tmpos_summ_`date +%y%m%d`.txt
  while read line
  do
    create_tr1 "$line" 
  done < /tmp/tmpos_summ_`date +%y%m%d`.txt
  create_table_end >> $file_output
  
  create_html_head "cpu信息" >> $file_output
  create_table_head1 >> $file_output
  get_cpuinfo >>/tmp/tmp_cpuinfo_`date +%y%m%d`.txt
  while read line
  do
    create_tr1 "$line" 
  done < /tmp/tmp_cpuinfo_`date +%y%m%d`.txt  
  create_table_end >> $file_output

  create_html_head "ip网络信息" >> $file_output
  create_table_head1 >> $file_output
  get_netinfo
  while read line
  do
    create_tr2 "$line" 
  done < /tmp/tmpnet_h1_`date +%y%m%d`.txt
  while read line
  do
    create_tr1 "$line" 
  done < /tmp/tmpnet1_`date +%y%m%d`.txt
  create_table_end >> $file_output

  create_html_head "cpu使用率" >> $file_output
  create_table_head1 >> $file_output
  get_cpuuse
  create_tr3 "/tmp/tmp_cpuuse_`date +%y%m%d`.txt"
  create_table_end >> $file_output

  create_html_head "连接数信息" >> $file_output
  create_table_head1 >> $file_output
  get_connections >>/tmp/tmp_connections_`date +%y%m%d`.txt
  while read line
  do
    create_tr1 "$line" 
  done < /tmp/tmp_connections_`date +%y%m%d`.txt  
  create_table_end >> $file_output

  create_html_head "系统限制信息" >> $file_output
  create_table_head1 >> $file_output
  get_ulimitinfo
  create_tr3 "/tmp/tmp_ulimitinfo_`date +%y%m%d`.txt"
  create_table_end >> $file_output  

  create_html_head "内存使用信息" >> $file_output
  create_table_head1 >> $file_output
  get_meminfo
  while read line
  do
    create_tr1 "$line" 
  done < /tmp/tmpmem1_`date +%y%m%d`.txt
  create_table_end >> $file_output
  
  create_table_head1 >> $file_output
  create_tr3 "/tmp/tmpmem2_`date +%y%m%d`.txt"
  create_table_end >> $file_output
  
  create_table_head1 >> $file_output
  while read line
  do
    create_tr2 "$line" 
  done < /tmp/tmpmem3_h1_`date +%y%m%d`.txt
  
  while read line
  do
    create_tr1 "$line" 
  done < /tmp/tmpmem3_t1_`date +%y%m%d`.txt
  create_table_end >> $file_output
  
  create_html_head "磁盘使用信息" >> $file_output
  create_table_head1 >> $file_output
  get_diskinfo
  while read line
  do
    create_tr2 "$line" 
  done < /tmp/tmpdisk_h1_`date +%y%m%d`.txt
  while read line
  do
    create_tr1 "$line" 
  done < /tmp/tmpdisk_t1_`date +%y%m%d`.txt
  create_table_end >> $file_output
  
  create_table_head1 >> $file_output
  create_tr3 "/tmp/tmpdisk1_`date +%y%m%d`.txt"
  create_table_end >> $file_output
  
  create_table_head1 >> $file_output
  create_tr3 "/tmp/tmpdisk2_`date +%y%m%d`.txt"
  create_table_end >> $file_output
  
  create_table_head1 >> $file_output
  create_tr3 "/tmp/tmpdisk3_`date +%y%m%d`.txt"
  create_table_end >> $file_output

  create_html_head "网络流量情况" >> $file_output
  create_table_head1 >> $file_output
  get_topproc
  create_tr3 "/tmp/tmpload_`date +%y%m%d`.txt"
  create_table_end >> $file_output
  
  create_html_head "消耗CPU前十排行" >> $file_output
  create_table_head1 >> $file_output
  create_tr3 "/tmp/tmptopcpu_`date +%y%m%d`.txt"
  create_table_end >> $file_output
          
  create_html_head "消耗内存前十排行" >> $file_output
  create_table_head1 >> $file_output
  create_tr3 "/tmp/tmptopmem_`date +%y%m%d`.txt"
  create_table_end >> $file_output
  
  create_html_head "磁盘io情况" >> $file_output
  create_table_head1 >> $file_output
  create_tr3 "/tmp/tmptopio_`date +%y%m%d`.txt"
  create_table_end >> $file_output

  create_html_head "定时任务信息" >> $file_output
  create_table_head1 >> $file_output
  get_crontablist
  create_tr3 "/tmp/tmp_crontab_`date +%y%m%d`.txt"
  create_table_end >> $file_output

  create_html_head "定时任务脚本内容" >> $file_output
  create_table_head1 >> $file_output
  get_crontab_content
  create_tr3 "/tmp/tmp_crontab_shellcontent_`date +%y%m%d`.txt"
  create_table_end >> $file_output

  create_html_end >> $file_output
  sed -i 's/BORDER=1/width="68%" border="1" bordercolor="#000000" cellspacing="0px" style="border-collapse:collapse"/g' $file_output
  rm -rf /tmp/tmp*_`date +%y%m%d`.txt
}
# This script must be executed as root
RUID=`id|awk -F\( '{print $1}'|awk -F\= '{print $2}'`
if [ ${RUID} != "0" ];then
    echo"This script must be executed as root"
    exit 1
fi
PLATFORM=`uname`
if [ ${PLATFORM} = "HP-UX" ] ; then
    echo "This script does not support HP-UX platform for the time being"
exit 1
elif [ ${PLATFORM} = "SunOS" ] ; then
    echo "This script does not support SunOS platform for the time being"
exit 1
elif [ ${PLATFORM} = "AIX" ] ; then
    echo "This script does not support AIX platform for the time being"
exit 1
elif [ ${PLATFORM} = "Linux" ] ; then
  create_html
fi