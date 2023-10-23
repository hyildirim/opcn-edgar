open (C, "ip netns |");
while(<C>)
{
        chomp;
        if (/^qrouter/)
        {
           my ($router,$id) = split(/\s\(/);
           $id =~ s/id: //g;
           $id =~ s/\)//g;
           push(@routers,$router);
        }
}
close C;


# Now let's get down to the business of executing
# commands in the router namespace
#
foreach my $r (@routers)
{
        my $cmd = `ip netns exec $r ss state listening`;

        print "Checking router [$r]\n";
        print $cmd . "\n";
        print "-" x 79 . "\n";
}
