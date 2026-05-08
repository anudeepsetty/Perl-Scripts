#!/bin/perl


$cluster = shift(@ARGV);

$date = `date --date= +"%Y.%m.%d"`;
chomp $date;
print `date --date= +"%Y.%m.%d.%h.%m"`, "\n";

$user           = "metricCollector";
$password       = "Link.360";
$base           = "/apps/c1";
$index_name     = "apitrans_elk_container_metrics";
$Monitorhost    = "devlogs.es.elk.dev01.lv1.c1b.corp";
$ndjson_payload = '';
$sys_timestamp  = `date -u "+%Y-%m-%dT%H:%M:%SZ"`;
chomp $sys_timestamp;

print $sys_timestamp, "\n";

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

print "Step3: Executing curl command \n";

if ($cluster =~ /_(lasvegas|dallas)$/)
{
        print "Entered loop to check if it's lasvegas or Dallas \n";
         $location = $1;
         $cluster =~ s/_(lasvegas|Dallas)$//;
}
print "curl -XGET -k -u $user:$password \"https://$httpsHost:9243/_ilm/policy/app-ilm-policy\"";

@curl = `curl -XGET -k -u $user:$password "https://$httpsHost:9243/_cat/nodes?h=name,ip,disk.used,disk.total,disk.avail,disk.used_percent,node.role,version&s=ip,disk.avail"`;

$health_curl = `curl -XGET -k -u $user:$password "https://$httpsHost:9243/_cat/health"`;

$role_curl = `curl -XGET -k -u $user:$password "https://$httpsHost:9243/_nodes/settings?filter_path=nodes.*.name,nodes.*.version,nodes.*.attributes.data,nodes.*.attributes.availability_zone,nodes.*.attributes.instance_configuration"`;

print @curl, "\n";
#print $health_curl;

print "Checking Cluster Health \n";
($epoch,$timestamp,$cluster_id,$status,$total_nodes,$data_nodes,$shards,$pri_shards,$reloc,$init,$unassign,$unassigned_primary,$pending_tasks,$max_task_wait_time,$active_shards_percent) = split(/\s+/,$health_curl);

print "$epoch,$timestamp,$cluster_id,$status,$total_nodes,$data_nodes,$shards,$pri_shards,$reloc,$init,$unassign,$unassigned_primary,$pending_tasks,$max_task_wait_time,$active_shards_percent \n";

foreach $line(@curl)
{
                ($name,$ip,$disk_used,$disk_total,$disk_avail,$disk_used_percent,$node_role,$version) = split(/\s+/,$line);

                if($node_role eq "hirst" || $node_role eq "himrst")
                {
                        $nodeRole = "HOT";
                }
                elsif($node_role eq "rw")
                {
                        $nodeRole = "WARM";
                }
                elsif($node_role eq "mr")
                {
                        $nodeRole = "MASTER";
                }
                else{
                        $nodeRole = "UNKNOWN";
                }

                if($disk_total =~ /(.+?)tb/)
                        {
                                $DiskTotalInGB = $1*1024;
                                #print "$DiskTotalInGB \n";
                        }
                elsif($disk_total =~ /(.+?)mb/)
                        {
                                 $DiskTotalInGB = $1/1024;
                                 #print "$DiskTotalInGB \n";
                        }
                elsif($disk_total =~ /(.+?)gb/)
                {
                                $DiskTotalInGB = $1;
                        }

                if($disk_used =~ /(.+?)tb/)
                        {
                                $DiskUsedInGB = $1*1024;
                                #print "$DiskUsedInGB \n";
                        }
                elsif($disk_used =~ /(.+?)mb/)
                        {
                                 $DiskUsedInGB = $1/1024;
                                 #print "$DiskUsedInGB \n";
                        }
                elsif($disk_used =~ /(.+?)gb/)
                        {
                                $DiskUsedInGB = $1;
                        }


                if($disk_avail =~ /(.+?)tb/)
                        {
                                $DiskAvailInGB = $1*1024;
                                #print "$DiskAvailInGB \n";
                        }
                elsif($disk_avail =~ /(.+?)mb/)
                        {
                                 $DiskAvailInGB = $1/1024;
                                 #print "$DiskAvailInGB \n";
                        }
                elsif($disk_avail =~ /(.+?)gb/)
                        {
                                $DiskAvailInGB = $1;
                        }
                if($active_shards_percent =~ /(.+?)%/)
                        {
                                $activeShardsPercent = $1;
                                #print "$DiskAvailInGB \n";
                        }


                $action_line    = "{\"create\":{\"_index\":\"$index_name\"}}\n";
                $doc_line       =  "{\"cluster\":\"$cluster\",\"location\":\"$location\",\"name\":\"$name\",\"ip\":\"$ip\",\"nodeRole\":\"$nodeRole\",\"version\":\"$version\",\"DiskUsedInGB\":\"$DiskUsedInGB\",\"DiskTotalInGB\":\"$DiskTotalInGB\",\"DiskAvailInGB\":\"$DiskAvailInGB\",\"disk_used_percent\":\"$disk_used_percent\",\"\@timestamp\":\"$sys_timestamp\",\"health_epoch\":\"$epoch\",\"time\":\"$timestamp\",\"cluster_id\":\"$cluster_id\",\"status\":\"$status\",\"total_nodes\":\"$total_nodes\",\"data_nodes\":\"$data_nodes\",\"shards\":\"$shards\",\"primary_shards\":\"$pri_shards\",\"relocating_shards\":\"$reloc\",\"initiating_shards\":\"$init\",\"unassigned_shards\":\"$unassign\",\"unassigned_primary\":\"$unassigned_primary\",\"pending_tasks\":\"$pending_tasks\",\"max_task_wait_time\":\"$max_task_wait_time\",\"active_shards_percent\":\"$activeShardsPercent\"}\n";

                $ndjson_payload .= $action_line;
                $ndjson_payload .= $doc_line;

}

$temp_file = "bulk_data.json";

print $ndjson_payload,"\n";

open ($fh, '>', $temp_file) or die $!;
print $fh $ndjson_payload . "\n";
close($fh);


@post_curl = `curl -k -u $user:$password -H 'Content-Type: application/x-ndjson' -XPOST 'https://$Monitorhost:9243/_bulk?pretty' --data-binary \@$temp_file`;

print @post_curl;

unlink($temp_file);
