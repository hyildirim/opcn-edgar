my %devices;
my %switches;
my $outDir = "./out";
cleanOutDir($outDir);

# Usage perl edgar-dualBondSwitchConfig.pl < inputFile
# Input file is basically a file that looks like as follows

#  Device: 	1189418-controller1
#  A2-25-2[1] (AggExNet)
#  A2-25-2[12] (AggExNet)
#  A2-26-2[13] (AggExNet)
#  A2-26-2[24] (AggExNet)
#  A2-25-1S[1] (ServiceNet)
#  A2-25-1S[21] (DRACNet)
#  
#  
#  Device: 	1189419-controller2
#  A2-25-2[2] (AggExNet)
#  A2-25-2[34] (AggExNet)
#  A2-26-2[14] (AggExNet)
#  A2-26-2[25] (AggExNet)
#  A2-25-1S[2] (ServiceNet)
#  A2-25-1S[22] (DRACNet)

# I generate this file using nscli
# nscli info 837934 >> 210706-04637.txt
# nscli info 837935 >> 210706-04637.txt



$poCtr = 20;
while (<>)
{
   chomp;
   if (/^Device:/)
   {
      my (@a) = split(/:/);
      $deviceNo = trim(pop(@a));
      print "[$deviceNo]\n";
      $devices[$deviceNo]['name'] = $deviceNo;
      $ctr = 1;
      $poBond0 = $poCtr;
      $poBond1 = $poCtr + 1;
      $poCtr = $poCtr + 2;
   }
   if (/AggExNet/)
   {
      
      $port = trimExnet($_);
      ( $sName, $sPort) = splitSWInfo($port);
      if ($ctr ==1 || $ctr==3 )
      {
         print ">$ctr< >$sName< >$sPort< [bond0] [po$poBond0]\n";
         $config = qq {
! ******** $sName *******************          
interface Port-Channel$poBond0
   description $deviceNo-bond0
   switchport access vlan 4094
   no switchport trunk native vlan
   switchport trunk allowed vlan none
   switchport trunk allowed vlan add 201,202,203,204,205
   switchport mode trunk
   mlag $poBond0
   service-policy type qos input 8GB_INPUT
   shape rate 80 percent
   port-channel lacp fallback individual

interface $sPort
description $deviceNo-bond0
   mtu 9000
   speed auto
   switchport access vlan 4094
   no switchport trunk native vlan
   switchport trunk allowed vlan none
   switchport mode trunk
   channel-group $poBond0 mode active
   no lldp receive
   spanning-tree portfast
   spanning-tree bpduguard enable
   switchport trunk allowed vlan add 201,202,203,204,205
   
         };
         writeToFile($sName,$config, $outDir);
         #push(@{$switches{$sName}}, $config);
      }
      if ($ctr ==2 || $ctr==4 )
      {
          $config = qq {
! ******** $sName *******************             
interface Port-Channel$poBond1
   description $deviceNo-bond1
   switchport access vlan 4094
   no switchport trunk native vlan
   switchport trunk allowed vlan none
   switchport trunk allowed vlan add 206-229
   switchport mode trunk
   mlag $poBond1
   service-policy type qos input 8GB_INPUT
   shape rate 80 percent
   port-channel lacp fallback individual

interface $sPort
description $deviceNo-bond1
   mtu 9000
   speed auto
   switchport mode trunk
   no switchport trunk native vlan
   channel-group $poBond1 mode active
   no lldp receive
   spanning-tree portfast
   spanning-tree bpduguard enable
   switchport trunk allowed vlan add 206-229
      };
          
          print ">$ctr< >$sName< >$sPort< [bond0] [po$poBond1]\n";
          #push(@{$switches{$sName}}, $config);
          writeToFile($sName,$config, $outDir);
      }
      $ctr++;
      
   }

}



sub cleanOutDir
{
   my ($dir) = @_;
   opendir(DIR,$dir) || die "Can't open $dir : $!\n";
   my @files = readdir(DIR); 
   close(DIR);
   foreach my $file(@files)
   {
      print "Deleting file $dir/$file..\n";
      unlink("$dir/$file");
   }
   return;  
}


sub writeToFile
{
   my ( $swName, $config, $outDir ) = @_;
   my $fileName = $outDir . "/" . $swName . ".txt";
   print "WriteToFile  = $fileName\n";
   open (F, ">>$fileName");
   print F $config;
   close F;
   
   
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
   $switchPort = "eth" . $a[1];
   #print "SwitchName [$switchName] , SwitchPort >>$switchPort<<\n";
   return ($switchName, $switchPort);
   #A2-25-2[21]
   
}
