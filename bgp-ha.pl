#!/usr/bin/perl
# This script was created so that it can be added to cron to make sure
# BGP DRagent is scheduled on all controllers for a given BGP speaker
# It has not been tested with multiple BGP speakers at this point.
#
# Some PERL modules are required
# Please run the following on each node that would run this script
#
# apt install cpanminus
# apt install libjson-perl
# cpanm install Env::Modify
#
#
#
# 2022-10-12: V1 created by Luke Yildirim
# 2022-10-14: Added logging to syslog
#
use JSON;
use Env::Modify 'source';
use Data::Dumper;
source("$ENV{HOME}/openrc");

# If the script runs on all 3 controllers at the same exact time
# that may cause race condition so I added a random wait time
my $randomNumber=int(rand(10)) + 5;
logger("Sleeping for $randomNumber seconds first");


$speakerID = getBGPSpeaker();
my %agents = getBGPAgents();

logger("BGP Speaker ID is : [$speakerID]");
checkSpeaker($speakerID, \%agents);

if ( scalar(%agents) > 0 )
{
	logger("Some of the DRAgents are not scheduled");
	foreach my $a (keys %agents)
	{
		my $host = $agents{$a}{'host'};
		logger("Scheduling BGP speaker on host [$host]");
		$cmd = "openstack bgp dragent add speaker " . $a . " " . $speakerID;
		logger("Command is [$cmd]");
		system($cmd);
	}

}
else
{
	logger("Speaker is already scheduled on all controllers");
}
exit;



#-------------------------------------------------------------------------------------
# Subroutines
# ------------------------------------------------------------------------------------
sub getBGPAgents
{
	my %h;
	logger("Retrieving BGP agent list");
	my $cmd = "openstack network agent list --agent-type bgp -f json 2>/dev/null";
	my $o = `$cmd`;
	
	my $t = decode_json($o);
	foreach my $agent (@{$t})
	{
		my $id = $agent->{'ID'};
		if ( $agent->{'Alive'} ==1  &&  $agent->{'State'} == 1 )
      		{
         		$h{$id}{'host'} = $agent->{'Host'};
      		}
	}
   return(%h);
}
# ------------------------------------------------------------------------------------
sub checkSpeaker
{
	my ($s, $agents) = @_;
	logger("Checking DRagent list for speaker [$s]");
	my $cmd = "openstack bgp dragent list --bgp-speaker $s -cID -f json 2>/dev/null";
	my $o = `$cmd`;
	my $t = decode_json($o);
	foreach my $agent (@{$t})
	{
		$agentID = $agent->{'ID'};
		if ( $$agents{$agentID} )
		{
			$agentHost = $agents{$agentID}{'host'};

			logger("BGP Speaker [$s] is already scheduled on $agentHost");
			delete $agents{$agentID};
		}
	}
	return;
}
# ------------------------------------------------------------------------------------
sub logger
{
	my ($str) = @_;
	print "INFO:$str\n";
	system("/usr/bin/logger BGP-HA-TOOL::INFO::$str");
}
# ------------------------------------------------------------------------------------
sub getBGPSpeaker
{

	my $o = `openstack bgp speaker list -c ID -f json 2>/dev/null`;
	$o = cleanJSON($o);
	my $t = decode_json($o);
	return $t->{'ID'};
}

sub cleanJSON
{
	my ($s) = @_;
	$s =~ s/^\[//g;
	$s =~ s/\]$//g;
	return($s);
}
