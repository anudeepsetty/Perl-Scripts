#!/bin/perl

$cluster = shift(@ARGV);

$user     = "";
$password = "";
$base     = "/apps/c1";
open(IN, "$base/scripts/clusters.cfg");
@clusters = <IN>
close IN;

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
        print "usage prebuildIndexes.pl [$clusterList]\n";
        exit;
}

$httpsHost = $httpHostLookup{$cluster};
$date = `date --date=$numDays days ago" + "%Y.%m.%d"`;
chomp $date;

@curl = `curl -XPUT -k -u $user:$password -H "Content-Type: application/json" "https://$httpsHost:9200/_cluster/settings" -d '
{
  "persistent": {
    "cluster.routing.allocation.enable": "all"
    }
}'   ;

print @curl;
