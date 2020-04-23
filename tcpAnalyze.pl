my $dir = "./";
opendir (DIR, $dir) or die;
while (my $file = readdir(DIR) )
{
	if ( -f $file && $file =~ m/pcap/ )
	{
		#print $file, "\n";
		push(@files, $file);
	}
}
closedir(DIR);

$filters{'tcp'} = "Packet Count";
$filters{'tcp.analysis.retransmission'} = "Retransmission";
$filters{'tcp.analysis.duplicate_ack'} = "Duplicate ACK";
$filters{'tcp.analysis.out_of_order'}  = "Out of order";
$filters{'tcp.analysis.window_full'}   = "Window Full";


$fileCtr=0;
foreach my $file (@files)
{
	#next if ($fileCtr > 1); 
	#$fileCtr++;
	foreach my $filter (sort keys %filters)
	{
		
	$cmd = "tshark -t ud -r $file -Y $filter |";
	#print $cmd, "\n"; next;
	my $ctr = 0;
	open (C, $cmd);
	while (<C>)
	{
		chomp;
		if ($filter eq "tcp")
		{
			$line = $_;
			$line =~ s/^\s+//g;
			my (@d) = split(/\s+/, $line);
			if ($d[0] == 1)
			{
			   $startTime = $d[1] . " " . $d[2];	
			}
			$endTime = $d[1] . " " . $d[2];
		}
		$ctr++;
	}
	print "File $file contains $ctr retransmissions filter $filter\n";
	$filterName = $filters{$filter};
	
	$results{$file}{$filterName} = $ctr;
	$results{$file}{'startTime'} = $startTime;
	$results{$file}{'endTime'} = $endTime;
	}
	

}
print "-" x 60 . "\n";
foreach my $r ( sort keys %results)
{
    printf ("%-20s : %-20s\n", "FileName", $r);
    printf ("%-20s : %-20s\n", "StartTime", $results{$r}{'startTime'});
    printf ("%-20s : %-20s\n", "EndTime", $results{$r}{'endTime'});
    foreach my $f (sort keys %filters)
    {
       $filterName = $filters{$f};
       printf ("%-20s : %-20s\n", $filterName, $results{$r}{$filterName});

    }

    print "-" x 60 . "\n";



}
