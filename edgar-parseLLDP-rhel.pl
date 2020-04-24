#!/usr/bin/perl
use Sys::Hostname;
use Data::Dumper;
our %globals;
my $myHostName = hostname;
my %bonds; my %interfaces;
getInterfaces(\%interfaces);
getBonds(\%bonds);
checkBonds(\%bonds, \%interfaces);
checkInterfaces(\%interfaces);
#print Dumper(%interfaces);
#print Dumper(%bonds);

if ( checkLLDPD() == 2)
{
   installLLDPD();
   print "INFO: Sleeping for 40 seconds to make sure LLDP information is gathered.\n";
   sleep 40;
}

checkLLDPStatus();
parseLLDP(\%interfaces);
summarizeData(\%interfaces);
cleanup();
exit;



sub cleanup
{
   print "INFO: Removing LLDPD\n";
   system("/sbin/sysctl lldpd stop");
   system("/bin/yum -y remove lldpd");
   if ( $globals{'epel-installed'} == 0 )
   {
     print "INFO: Removing EPEL repo\n";
     system("/bin/yum -y remove epel-release");
   }
   return;
}

sub parseLLDP
{
  my ($interfaces) = @_;
  unlink("/tmp/lldpInfo.txt");
  foreach (sort keys %{$interfaces})
  {
    if ( $$interfaces{$_}{'link'} eq "YES")
    {
      print "INFO: Checking LLDP for $_\n";
      system("/sbin/lldpcli show neighbors port $_  >> /tmp/lldpInfo.txt");
    }
    else 
    {
      print "INFO: interface $_ is not connected. Removing from summary\n";
      delete($$interfaces{$_});
    }
  } #end of for loop

   # Create a hash of interfaces so we only look for interfaces that are part of a bond
   my %_interfaces = %{$interfaces};
   
 
   print "INFO: Parsing LLDPD output\n";
   open (L, "/tmp/lldpInfo.txt");
   while(<L>)
   {
      chomp;
      if (/^Interface:/)
      {
         my $line = $_; $line =~ s/Interface:\s+//g; my @a = split(/,/, $line);
         $lastInterface = $a[0]; $$interfaces{$lastInterface}{'name'} = $lastInterface; next;
      }
      if (/PortID:/)
      {
         my $line = $_; $line =~ s/\s+PortID:\s+ifname\s+//g;      
         $$interfaces{$lastInterface}{'port'} = $line; next;
      }

      #if (/PortDescr:/)
      #{
      #   my $line = $_; $line =~ s/\s+PortDescr:\s+//g;      
      #   $$interfaces{$lastInterface}{'port'} = $line; next;

      #}
      if (/SysName:/)
      {
         my $line = $_; $line =~ s/\s+SysName:\s+//g;
         $$interfaces{$lastInterface}{'switch'} = $line;  next;
      }
   }
   close L;
   # Remove the interface if not in bond
   foreach my $int (keys %{$interfaces})
   {
     print "INFO: Bond for $int is " . $interfaces{$int}{'bond'} . "\n";
     if ( ! $interfaces{$int}{'bond'} )
     {
        print "INFO: Interface $int is not part of a bond. Marking as SINGLE.\n";
        $interfaces{$int}{'bond'} = "SINGLE";
     }
   }

   return;
}


sub summarizeData
{
   my ($interfaces) = @_;
   print "INFO: Interface Summary is saved to /tmp/interfaceSummary.txt\n";
   open (S, ">/tmp/interfaceSummary.txt");
   #my $fmtLine = "-" x 79 . "\n";
   #print $fmtLine; print "Interface Summary\n"; print $fmtLine;
   foreach my $i ( sort keys %{$interfaces})
   {
      #print $i, "\n";
      my $sw = $$interfaces{$i}{'switch'};
      my $swport = $$interfaces{$i}{'port'};
      my $speed = $$interfaces{$i}{'speed'};
      my $linkStatus = $$interfaces{$i}{'link'};
	#print "INFO: Interface $i is connected to Switch [$sw] port [$swport]\n";
      my $myHostName = hostname;
      print S join("::", $myHostName, $sw, $swport, $$interfaces{$i}{'bond'}, $i, $speed, $linkStatus) . "\n";
   }
   close S;
   return;
}





sub checkLLDPStatus
{
   print "INFO: Make sure service is started\n";
   #system("/bin/systemctl start lldpd");
   #sleep 40;
   #return;
   open (F, "/bin/systemctl status lldpd 2>&1 |");
   $serviceStopped = 0;
   while (<F>)
   {
      chomp;
      if (/stop/ || /waiting/ || /Stopped/ || /inactive/ || /dead/ )
      {
         $serviceStopped = 1;
         print $_, "\n";
      }
   }
   close F;
   if ( $serviceStopped == 1 )
   {
      print "INFO: Service LLDPD is stopped\n";
      print "INFO: Starting LLDPD service and waiting 40 seconds\n";
      system("/bin/systemctl start lldpd");
      sleep 40;
   }
   else
   {
      print "INFO: Service LLDPD is already running\n";
   }
   return;
   
}



sub checkLLDPD
{
   if ( ! -f "/usr/sbin/lldpcli" && ! -f "/sbin/lldpcli" )
   {
      return 2;         
   }
   return 1;
}

sub installLLDPD
{
   print "INFO: Installing LLDPD package\n";
   system("yum -y install wget");
   if ( checkEPEL() )
   {
     system("/bin/yum -y install lldpd");
   }
   else
   {
      system("/bin/wget -q -P /tmp https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm");
      system("/bin/yum -y install /tmp/epel-release-latest-7.noarch.rpm");
   }
   system("/bin/yum -y install lldpd");
   system("systemctl start lldpd");
   return;
}

sub checkEPEL
{
   print "INFO: Checking to see EPEL is enabled\n";
   open(REPO, "/bin/yum repolist | ");
   while(<REPO>)
   {
     chomp;
     if (/epel/)
     {
        $epelFound = 1;
     }
   }
   close REPO;
   
   if ( $epelFound ==1 )
   {
      $globals{'epel-installed'} = 1;
      return 1;
   }
   else
   {
      $globals{'epel-installed'} = 0;
      return 0;
   }
 
}



sub checkInterfaces
{
   my ($interfaces) = @_;
   # Now use ethtool to see the link status
   foreach $int (sort keys %interfaces)
   {
           $$interfaces{$int}{'link'} = "N/A";
           print "INFO: Checking status of $int using ethtool\n";
           open (F, "ethtool $int |");
           while(<F>)
           {
                   chomp;
                   if (/Link detected:/)
                   {
                         my ($j, $link) = split(/:\s/);
                         print "INFO: Link status for $int : $link\n";
                         if ( $link eq "no" ) { $link = "NO" ; }
			 if ( $link eq "yes" ) { $link = "YES"; }
                         $$interfaces{$int}{'link'} = $link;
                   }
		  if (/Speed:/)
		 {
			my($k,$speed) = split(/:\s/);
			print "INFO: Speed for $int : $speed\n";
			$$interfaces{$int}{'speed'} = $speed;
		}
           }
           close F;
   }
}


sub getInterfaces($i)
{
 my ($i) = @_;
opendir (D, "/sys/class/net");
while (my $file = readdir(D)) 
{
	if ($file=~ m/eno/ || $file=~ m/ens/ || $file=~ m/eth/ )
	{
		$$i{$file}{'name'} = $file;
	}
	#print $file, "\n";
}

closedir D;


return;
}


sub getBonds($b)
{
  my ($b) = @_;
opendir (D, "/proc/net/bonding");
while (my $bond = readdir(D))   
{
        if ($bond=~ m/bond/ )
        {
                $$b{$bond}{'name'} = $bond;
		#print $bond, "\n";
        }
	#print $bond, "\n";

}
closedir D;
return;



}



sub checkBonds
{
   my ($bonds, $interfaces) = @_;
   print "INFO: Checking status of each bond\n";
   foreach $bond ( sort keys %{$bonds})
   {
           print "INFO: Reading status of $bond\n";
           # Now read the bond status
           open (F, "/proc/net/bonding/$bond");
           while(<F>)
           {
              chomp;
              if (/Slave Interface/)
              {
                   my ($j, $int) = split(/:\s/);
                   print "INFO: Interface $int is in bond $bond\n";
                   push(@{$bonds{$bond}{'interfaces'}}, $int);
                   $$interfaces{$int}{'bond'} = $bond;
              }
           if (/Bonding Mode:/)
           {
                   my ($k, $bondMode) = split(/:\s/);
                   $bonds{$bond}{'mode'} = $bondMode;
           }
           }
           close F;
   }
   return;
}



