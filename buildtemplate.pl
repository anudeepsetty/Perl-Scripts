#!/bin/perl

use constant DEBUG => 0;
use File::Copy;

$cluster = shift(@ARGV);
$index = shift(@ARGV);
$shardCount = shift(@ARGV);
$maxFields = shift(@ARGV);

$base= "/apps/c1";
open(IN,"$base/scripts/clusters.cfg");
@clusters= <IN>;
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
$clusterList = join('|',@clusterList);
if($cluster eq "" || $index eq "" || $shardCount <=0)
{
        print "usage buildTemplate.pl [$clusterList] [index] [shard count \#] \n";
}

$index =~ s/.ds_//;

$httpHost = $httpHostLookup{$cluster};

print "Selected Cluster $cluster Host: $httpHost\n";

$today =`date +"%Y.%m.%d"`;
chomp $today;

@curl =`curl -XGET -k -u $user:$password -H "Content-Type:application/json" "https://$httpsHost:9243/.ds_$index-$today*/_mapping?pretty"`;
print @curl;

$baseHeader = qq|{
          "index_patterns" :[
                  ".ds_$index_*"
          ],
          "template" : {
                  "settings" : {
                          "index" :{
                                  "number_of_shards" : "$shardCount",
                                  "$number_of_replicas" : "0",
                                  "refresh_interval" : "60s",
                                  "merge" : {
                                           "policy": {
                                                   "max_merged_segment": "10gb",
                                                   "segments_per_tier" : "30",
                                                   "floor_segment" : "4mb"
                                            }
                                  },
                                  "translog": {
                                          "flush_threshold_size": "1024"
                                  }
                        },
                        "index.routing.allocation.require.temp": "data_content",
                        "index.codec" : "zstd_no_dict"
                   }|;
                   #$maintenanceHeader = qq|{;

if($maxFields > 0)
{
$fieldsMapping = qq|,
                 "mappings": {
                          "total_fields": {
                                   "limit" : $maxFields
                          },
                          "properties" : {
                          }
|;
else
{
$fieldsMapping = qq|,
                "mappings" : {
                     "properties": {
                     }
|;
}

open(OUT, ">$base/scripts/templates/$cluster/$index.template");
print OUT $baseHeader;
print OUT $fieldsMapping;
print OUT "\n           }\n       }\n";
close OUT;
copy("$base/scripts/templates/$cluster/$index.template","$base/scripts/base_templates/$cluster/$index.template");

open(OUT, ">$base/scripts/maintenance_templates/$cluster/$index.template");
print OUT $maintenanceHeader;
print OUT $fieldsMapping;
print OUT "\n          }\n     }\n}";
close OUT;

sub all_fields{
        for($i = 0;$i<= $#curl;$i++)
        {
                sleep 1 if DEBUG;
                if(curl[$i] =~ /mappings/)
                {
                        print "1 $curl[$i] if DEBUG;"
                        print OUT $curl[$i];
                }
                elsif(curl[$i] =~ /properties/)
                                {
                                        print "2$curl[$i] if DEBUG;"
                                        print OUT $curl[$i];
                                }
                elsif($curl[$i] =~ /^\s+"fields/")
                        {
                                $i = $i + 5;
                        }
                elsif($curl[$i] =~ /("\w+" : \{)/ $curl[$i] !~ /fields/ )
                        {

                        }
