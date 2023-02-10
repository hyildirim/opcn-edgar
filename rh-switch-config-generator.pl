my %devices;
my %switches;
my %vlans;
my $outDir = "./out";
if ( ! -d $outDir ) { mkdir($outDir); }
cleanOutDir($outDir);
our %files;

#------------------------------------------------------------------------------
# IMPORTANT
#------------------------------------------------------------------------------
# Make sure $poCtr is high enough so we don't overwrite an existing 
# port-channel configuration, 300 is usually safe, but look at switches
$poCtr = 300;

#------------------------------------------------------------------------------
# VLANs - this is where you define the VLANs
#------------------------------------------------------------------------------
$vlans{1050} = "5769161-ENV87042-OLE_MGMT_PRIV";
$vlans{1051} = "5769161-ENV87042-OLE_RHOSP_PRIV";
$vlans{1052} = "5769161-ENV87042-OLE_EXT_EGRESS";
$vlans{1053} = "5769161-ENV87042-OLE_PRIV_PRVDR";
$vlans{1054} = "5769161-ENV87042-OLE_RESERVED";
$vlans{1055} = "5769161-ENV87042-OLE_MGMT_PUB";
$vlans{1056} = "5769161-ENV87042-OLE_RHOSP_PUB_0";
$vlans{1057} = "5769161-ENV87042-OLE_RHOSP_PUB_1";
$vlans{1058} = "5769161-ENV87042-OLE-MGT";

#------------------------------------------------------------------------------
# HOST GROUP #1 - If hostname starts with rhv and name contains 
# rhosp (e.g rhv**-rhosp) (Typically 3 servers)
#------------------------------------------------------------------------------
$hg1{'servers'} = "1246528,1246529,1246530";
$hg1{'bond0'}{'native'} = 1051;
$hg1{'bond0'}{'trunk'} = "1050-1053";
$hg1{'bond1'}{'native'} = 1056;
$hg1{'bond1'}{'trunk'} = "1055-1058";

#------------------------------------------------------------------------------
# HOST GROUP #2 - If hostname starts with rhv and name DOES NOT 
# contain rhosp (Typically 2 servers)
#------------------------------------------------------------------------------
$hg2{'servers'} = "1246522,1246523";
$hg2{'bond0'}{'native'} = 1050;
$hg2{'bond0'}{'trunk'} = "1050-1053";
$hg2{'bond1'}{'native'} = 1055;
$hg2{'bond1'}{'trunk'} = "1055-1058";

#------------------------------------------------------------------------------
# HOST GROUP #3 - If hostname starts with compute
#------------------------------------------------------------------------------
$hg3{'servers'} = "1248551,1248528,1248531,1138086";
$hg3{'bond0'}{'native'} = 1051;
$hg3{'bond0'}{'trunk'} = "1050-1053";
$hg3{'bond1'}{'native'} = 1056;
$hg3{'bond1'}{'trunk'} = "1055-1058";

#------------------------------------------------------------------------------
# HOST GROUP #4 - If hostname starts with CEPH
#------------------------------------------------------------------------------
$hg4{'servers'} = "1247220,1247221,1247222,1247223,1247224,1247225";
$hg4{'bond0'}{'native'} = 1051;
$hg4{'bond0'}{'trunk'} = "1051";

#------------------------------------------------------------------------------
# DONE DEFINING THINGS, from here, it's all automatic.
#------------------------------------------------------------------------------
my %servers;
# First show all server list into an hash so that we can do quick lookups
my @srvs = split(",", $hg1{'servers'}); foreach my $server ( @srvs ) { $servers{$server} = 1; }
my @srvs = split(",", $hg2{'servers'}); foreach my $server ( @srvs ) { $servers{$server} = 2; }
my @srvs = split(",", $hg3{'servers'}); foreach my $server ( @srvs ) { $servers{$server} = 3; }
my @srvs = split(",", $hg4{'servers'}); foreach my $server ( @srvs ) { $servers{$server} = 4; }

while (<>)
{
   chomp;
   if ( /^Device Number:/ || /^Device :/ )
   {
      my (@a) = split(/:/);
      $deviceNo = trim(pop(@a));
      $devices[$deviceNo]['name'] = $deviceNo;
      $ctr = 1;
      $poBond0 = $poCtr;
      $poBond1 = $poCtr + 1;
      $poCtr = $poCtr + 2;
      $groupID = getServerGroup($deviceNo, \%servers);
      print "[$deviceNo] Group ID is $groupID\n";
   }
   if ( $groupID == 1 )
   {
      $bond0Native = $hg1{'bond0'}{'native'};
      $bond0Tagged = $hg1{'bond0'}{'trunk'};
       
      $bond1Native = $hg1{'bond1'}{'native'};
      $bond1Tagged = $hg1{'bond1'}{'trunk'};
   }
   
   if ( $groupID == 2 )
   {
      $bond0Native = $hg2{'bond0'}{'native'};
      $bond0Tagged = $hg2{'bond0'}{'trunk'};
      
      $bond1Native = $hg2{'bond1'}{'native'};
      $bond1Tagged = $hg2{'bond1'}{'trunk'};
   }
   
   if ( $groupID == 3 )
   {
      $bond0Native = $hg3{'bond0'}{'native'};
      $bond0Tagged = $hg3{'bond0'}{'trunk'};
      
      $bond1Native = $hg3{'bond1'}{'native'};
      $bond1Tagged = $hg3{'bond1'}{'trunk'};
   }
   if ( $groupID == 4 )
   {
      $bond0Native = $hg4{'bond0'}{'native'};
      $bond0Tagged = $hg4{'bond0'}{'trunk'};
   }
   
   
   # Group 1,2,3 servers has dual bond 
   if (/AggExNet/ && ( $groupID == 1 || $groupID == 2 || $groupID == 3) )
   {
      
      $port = trimExnet($_);
      ( $sName, $sPort) = splitSWInfo($port);
      if ($ctr == 1 || $ctr == 3 )
      {
         print ">$ctr< >$sName< >$sPort< [bond0] [po$poBond0]\n";
         $config = qq {
! ******** $sName *******************          
interface Port-Channel$poBond0
   description $deviceNo-bond0
   switchport
   mtu 9216
   speed auto
   no switchport trunk native vlan
   switchport trunk native vlan $bond0Native
   switchport trunk allowed vlan none
   switchport trunk allowed vlan add $bond0Tagged
   switchport mode trunk
   no lacp suspend-individual
   spanning-tree bpduguard enable
   vpc $poBond0
   

interface $sPort
   no channel-group
   mtu 9216
   description $deviceNo-bond0
   no switchport trunk native vlan
   switchport trunk allowed vlan none
   switchport trunk native vlan $bond0Native
   switchport trunk allowed vlan add $bond0Tagged
   switchport mode trunk
   no channel-group
   channel-group $poBond0 mode active
   no lldp receive
   spanning-tree port type edge
   spanning-tree bpduguard enable
   
   
         };
         writeToFile($sName,$config, $outDir);
      }
      if ($ctr ==2 || $ctr==4 )
      {
          $config = qq {
! ******** $sName *******************             
interface Port-Channel$poBond1
   description $deviceNo-bond1
   switchport
   mtu 9216
   speed auto
   no switchport trunk native vlan
   switchport trunk allowed vlan none
   switchport trunk native vlan $bond1Native
   switchport trunk allowed vlan add $bond1Tagged
   switchport mode trunk
   no lacp suspend-individual
   spanning-tree bpduguard enable
   vpc $poBond1

interface $sPort
   description $deviceNo-bond1
   no channel-group
   mtu 9216
   switchport mode trunk
   no switchport trunk native vlan
   switchport trunk allowed vlan none
   switchport trunk native vlan $bond1Native
   switchport trunk allowed vlan add $bond1Tagged
   channel-group $poBond1 mode active
   no lldp receive
   spanning-tree port type edge
   spanning-tree bpduguard enable
   
      };
          
          print ">$ctr< >$sName< >$sPort< [bond0] [po$poBond1]\n";
          writeToFile($sName,$config, $outDir);
      }
      $ctr++;
      
   }
   
   # Group 1,2,3 servers has dual bond 
   if (/AggExNet/ &&  $groupID == 4 )
   {
      
      $port = trimExnet($_);
      ( $sName, $sPort) = splitSWInfo($port);
      
         print ">$ctr< >$sName< >$sPort< [bond0] [po$poBond0]\n";
         $config = qq {
! ******** $sName *******************          
interface Port-Channel$poBond0
   description $deviceNo-bond0
   switchport
   mtu 9216
   speed auto
   no switchport trunk native vlan
   switchport trunk native vlan $bond0Native
   switchport trunk allowed vlan none
   switchport trunk allowed vlan add $bond0Tagged
   switchport mode trunk
   spanning-tree bpduguard enable
   no lacp suspend-individual
   vpc $poBond0
   

interface $sPort
   no channel-group
   mtu 9216
   description $deviceNo-bond0
   no switchport trunk native vlan
   switchport trunk allowed vlan none
   switchport trunk native vlan $bond0Native
   switchport trunk allowed vlan add $bond0Tagged
   switchport mode trunk
   channel-group $poBond0 mode active
   no lldp receive
   spanning-tree port type edge
   spanning-tree bpduguard enable
   
   
         };
         writeToFile($sName,$config, $outDir);
      $ctr++;
   }
   

}
createVLANs($outDir,\%vlans);
finishOutDir($outDir);



#------------------------------------------------------------------------------
# Subroutines
#------------------------------------------------------------------------------
sub createVLANs
{
   my ($dir, $v) = @_;
   opendir(DIR,$dir) || die "Can't open $dir : $!\n";
   my @files = readdir(DIR); 
   close(DIR);
   foreach my $file(@files)
   {
      my $fileName = "$dir/$file";
      print "Adding exit statements to file [$fileName]\n";
      open (F, ">>$fileName");
      print F "\n!------------------------------------------------------\n";
      print F "! Creating VLANs\n";
      print F "!------------------------------------------------------\n";
      foreach my $vlanID (sort keys %{$v} )
      {
         print F "vlan $vlanID\n";
         print F "name " . $$v{$vlanID} . "\n";
      }   
      close F;
      
   }
   return;  
}

sub finishOutDir
{
   my ($dir) = @_;
   opendir(DIR,$dir) || die "Can't open $dir : $!\n";
   my @files = readdir(DIR); 
   close(DIR);
   foreach my $file(@files)
   {
      my $fileName = "$dir/$file";
      print "Adding exit statements to file [$fileName]\n";
      open (F, ">>$fileName");
      print F "\nexit\nexit\nwr\nexit\n";
      close F;
      
   }
   return;  
}
#------------------------------------------------------------------------------
sub getServerGroup
{
   my ( $s, $hRef )  = @_;
   if ( $$hRef{$s} ) 
   {
      return($$hRef{$s});
   }
   else
   {
      print "ERROR: Unable to find group ID for server $s\n";
   }
   return;
}   
sub writeToFile
{
   my ( $swName, $config, $outDir ) = @_;
   my $fileName = $outDir . "/" . $swName . ".txt";
   if (! $files{$fileName}{'open'} && $files{$fileName}{'open'} != 1 )
   {
      open (F, ">>$fileName");
      print F "conf t\n";
      print F $config;
      close F;
      $files{$fileName}{'open'}=1;
   }
   else
   {
      print "WriteToFile  = $fileName\n";
      open (F, ">>$fileName");
      print F $config;
      close F;
   }
   
   
}

sub trim
{
   my ($str)=@_;
   $str =~ s/^\s+//;
   $str =~ s/\s+$//;
   return $str;
}

sub trimExnet
{
   
   my ($str)= @_;
   #print "INPUT = $str\n";
   $str =~ s/\(AggExNet\)//g;
   $str =~ s/^\s+//;
   $str =~ s/\s+$//;
   #print "AFTER = >$str<\n";
   return $str;
}

sub splitSWInfo
{
   my ($str) = @_;
   #$str = trimExnet($str);
   $str =~ s/\]//;
   #print "LINE : >>$str<<\n";
   my @a = split(/\[/, $str);
   $switchName = $a[0];
   $switchPort = "eth1/" . $a[1];
   #print "SwitchName [$switchName] , SwitchPort >>$switchPort<<\n";
   return ($switchName, $switchPort);
   #A2-25-2[21]
   
}

sub cleanOutDir
{
   my ($dir) = @_;
   opendir(DIR,$dir) || die "Can't open $dir : $!\n";
   my @files = readdir(DIR); 
   close(DIR);
   foreach my $file(@files)
   {
      if ($file eq "." || $file eq ".." ) { next; }
      #print "File is [$file]\n";
      print "Deleting file $dir/$file..\n";
      unlink("$dir/$file");
   }
   return;  
}
   
sub nextSub
{
   my $nativeVlan;
   my $vlanList;
   
   if ( $$a{$s}  == 1 )
   {
      $nativeVlan = $$g1{'bond0'}{'native'};
      $vlanList   = $gg1{'bond0'}{'trunk'};
   }   
   return;
}   
   
   
   
