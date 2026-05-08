#!/bin/perl

$cluster = shift(@ARGV);

$user     = "metricCollector";
$password = "Link.360";
$base     = "/apps/c1";
open(IN, "$base/scripts/clusters.cfg");
@clusters = <IN>;
close IN;

foreach $line(@clusters)
{
        chomp $line;
        ($clusterName,$httpHostName) = split(/\|/,$line);
        $clusterName =~ tr/[A-Z]/[a-z]/;
        $httpHostLookup{$clusterName} = $httpHostName;
        push(@clusterList,$clusterName);
}

print "Cluster List variable created. Starting lookup now \n";

$cluster =~ tr/[A-Z]/[a-z]/;
$clusterList = join('|', @clusterList);

if($cluster eq "")
{
        print "usage prebuildIndexes.pl [$clusterList]\n";
        exit;
}

$httpsHost = $httpHostLookup{$cluster};
#$date = `date --date=$numDays days ago" + "%Y.%m.%d"`;
#chomp $date;

@curl = `curl -XGET -k -u $user:$password "https://$httpsHost:9243/_cat/indices/.ds-app\*?pretty"` ;

print qq|curl -XGET -k -u $user:$password "https://$httpsHost:9243/_cat/indices/es-\*?pretty" \n|;

print @curl;

foreach $line(@curl)
{
        ($health,$status,$index,$uuid,$pri,$rep,$docs,$junk,$size,$priSize) = split(/\s+/,$line);
        print "$index $pri $priSize\n";
        if($priSize =~ /(.+?)gb/)
        {
                $sizeInGb=$1;
                print "Size = $sizeInGb\n";
                $primaryCount= sprintf "%d",($sizeInGb/20)+1;
                ($templateName,$junk) = split(/-/,$index);
                print "update $templateName $primaryCount\n\n";
        }
        elsif($priSize =~ /mb/ || $priSize =~ /kb/)
        {
                if($pri>1)
                {
                        ($templateName,$junk) = split(/-/,$index);
                        $templateName .= ".template";
                        print "update $templateName $primaryCount\n";
                }
        }
}
