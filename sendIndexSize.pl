#!/bin/perl

use warnings;

$cluster = shift(@ARGV);

$user     = "metricCollector";
$password = "Link.360";
$base     = "/apps/c1";
open(IN, "$base/scripts/clusters.cfg") or die "Cannot open $base/scripts/clusters.cfg: $!";
@clusters = <IN>;
close IN;

print "Step1:Reading clusters config \n";


foreach $line(@clusters)
{
        chomp $line;
        ($clusterName,$httpHostName) = split(/\|/,$line);
        $clusterName =~ tr/[A-Z]/[a-z]/;
        $httpHostLookup{$clusterName} = $httpHostName;
        push(@clusterList,$clusterName);
}

$cluster =~ tr/[A-Z]/[a-z]/;
$clusterList = join('|', @clusterList);

if($cluster eq "")
{
        print "usage clusterHealth.pl [$clusterList]\n";
        exit;
}


print "Step2:looking up for cluster $cluster \n";

#print "$httpHostLookup/{$cluster/}";

$httpsHost = $httpHostLookup{$cluster};


#$date = `date --date="$numDays days ago" + "%Y.%m.%d"`;
#chomp $date;


print "Step3: Executing curl command \n";


#@curl = "curl -XGET -k -u $user:$password \"https://$httpsHost:9243/_cat/indices/?v&h=index,store.size&bytes=mb\"";

@curl = `curl -XGET -k -u $user:$password "https://$httpsHost:9243/_cat/indices/?v&h=index,store.size&bytes=mb"`;

print @curl;


foreach $line(@curl)
{
        chomp $line;
        ($Index,$SizeInMB) = split /\s+/, $line;
        $clusterName =~ tr/[A-Z]/[a-z]/;
        $httpHostLookup{$clusterName} = $httpHostName;
        push(@clusterList,$clusterName);
}
