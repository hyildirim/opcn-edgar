system("rabbitmqctl list_queues --vhost \/neutron > out.txt");
system("rabbitmqctl list_queues --vhost \/nova >> out.txt");
system("rabbitmqctl list_queues --vhost \/cinder >> out.txt");
system("rabbitmqctl list_queues --vhost \/glance >> out.txt");
system("rabbitmqctl list_queues --vhost \/keystone >> out.txt");


open (Q, "out.txt");
while(<Q>)
{
   chomp;
   next if (/^Timeout/);
   next if (/^Listing/);
   my @b = split(/\s+/);
   my $qName = shift(@b);
   my $qCount = shift (@b);
   if ($qCount > 0 )
   {
      print "[$v] [$qName] has a count of $qCount\n";
   }

}
close Q;
