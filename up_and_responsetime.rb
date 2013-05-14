#!/usr/bin/env ruby
# Copyright 2012 CopperEgg Corporation.  All rights reserved.
#
# up_and_responsetime.rb is a utility analyze RevealUptime response time and uptime.
#
#
#encoding: utf-8

require 'rubygems'
require 'pp'
require 'typhoeus'
require 'json'
require 'multi_json'
require 'csv'
require 'axlsx'
require 'ethon'
require './lib/exportoptions'
require './lib/getsystems'
require './lib/getprobes'
require './lib/headers'
require './lib/get1hrprobesamples.rb'


$output_path = "."
$APIKEY = ""
$outpath_setup = false
$verbose = false
$debug = false
$monitorthis = ""
$totalconcurrentuptime0 = 0
$stationnumber = 0
$samplesize = 0
$totalrows = 0
$days = 1
$begin = 0
$end = 0
$runtime = 0


def valid_json? json_
  begin
    JSON.parse(json_)
    return true
  rescue Exception => e
    return false
  end
end

#define offsets into the Latency array

  B_Lessthan100 = 0
  B_100msto150ms = 1
  B_150msto200ms = 2
  B_200msto500ms = 3
  B_500msto1sec = 4
  B_1secto2sec = 5
  B_2secto3sec = 6
  B_3secto4sec = 7
  B_4secto5sec = 8
  B_5secto6sec = 9
  B_6secto10sec = 10
  B_10secandup = 11
  SizeofLatencyArray = 12



# probesamples_tocsv
# this routine expects a single system id,
#   which may contain several sets of metric keys
#
def probesamples_tocsv(_apikey, _id, _probename, _freq, _keys, ts, te, ss)

  complex_syskeys = {"s_l" => ["connect", "first byte","trasfer time", "total"],
                     "s_u" => ["% uptime"],
                     "s_s" => ["0's count","100's count","200's count","300's count","400's count","500's count" ]
                    }

  complex_numcats = {"s_l" => 4,
                     "s_u" => 1,
                     "s_s" => 6
                    }

  keysto_strings =  { "s_l" => "latency",
                      "s_u" => "uptime",
                      "s_s" => "status codes"
                    }

  stato_strings =   { "atl"   => "Atlanta",
                      "dal"   => "Dallas",
                      "fre"   => "Fremont",
                      "lon"   => "London",
                      "nrk"   => "Newark",
                      "tok"   => "Tokyo"
                    }
  stato_ints    =   { "atl"   => 0,
                      "dal"   => 1,
                      "fre"   => 2,
                      "lon"   => 3,
                      "nrk"   => 4,
                      "tok"   => 5
                    }
  alphstations =    [ "atl", "dal", "fre", "lon", "nrk", "tok" ]

  if $outpath_setup == false    # ensure the following happens only once
    $outpath_setup = true
    if $output_path != "."
      if Dir.exists?($output_path.to_s+"/") == false
        if $verbose == true
          print "Creating directory..."
          if Dir.mkdir($output_path.to_s+"/",0775) == -1
            print "** FAILED ***\n"
            return false
          else
            FileUtils.chmod 0775, $output_path.to_s+"/"
            print "Success\n"
          end
        else
          if Dir.mkdir($output_path.to_s+"/",0775) == -1
            print "FAILED to create directiory "+$output_path.to_s+"/"+"\n"
            return false
          else
            FileUtils.chmod 0775, $output_path.to_s+"/"
          end
        end
      else  #  the directory exists
        FileUtils.chmod 0775, $output_path.to_s+"/"       # TODO only modify if needed?
     end # of 'if Dir.exists?($output_path.to_s+"/") == false'
    end
  end  # of 'if $outpath_setup == false '

  keys_array = Array.new
  keys_array = _keys.split(",")
  if keys_array.length < 1
    puts "\nError: This routine must be called with at least one key.\n"
    return false
  end

  # The timespan is split into 1 hour requests, to get max resolution
  secsperhour = 3600
  secsperday = 86400
  secsperrequest = (ss < 2 ? secsperhour : secsperday)

  tn = Time.now
  tn = tn.utc
  ti = tn.to_i

  if ts >= ti
    puts "Specified a start time in the future. Aborting"
    return false
  end

  if te <= ts
    puts "Specified an end time before the start time. Aborting"
    return false
  end

  begints = ts
  current_begints = ts
  endte = te
  current_endte = current_begints + secsperrequest

  if current_endte > endte
    current_endte = endte     # this will be the final iteration
  end

  fname = "#{$output_path}/#{_probename}_uptime_and_latency.xlsx"
  if $verbose == true
    puts "Writing to #{fname}\n\n"
  end

  inp_keyhash = Hash.new
  skeys = Array.new
  rowsignore = Array.new
  allrows = Array.new
  allrow_index = 0
  tlatencyarray = Array.new
  single_latencies = Hash.new
  tlatencyarray = [0,0,0,0,0,0,0,0,0,0,0,0]
  single_latencies = {"atl" => [0,0,0,0,0,0,0,0,0,0,0,0],
                      "dal" => [0,0,0,0,0,0,0,0,0,0,0,0],
                      "fre" => [0,0,0,0,0,0,0,0,0,0,0,0],
                      "lon" => [0,0,0,0,0,0,0,0,0,0,0,0],
                      "nrk" => [0,0,0,0,0,0,0,0,0,0,0,0],
                      "tok" => [0,0,0,0,0,0,0,0,0,0,0,0]
                      }
  probe_stations = Array.new
  first_sample_up = nil
  first_sample_lat = nil

  p = Axlsx::Package.new
  wb = p.workbook
  header = wb.styles.add_style :alignment => { :horizontal=> :center, :wrapText => true }
  date = wb.styles.add_style :alignment => { :horizontal=> :center }
  comma = wb.styles.add_style :num_fmt => 39, :alignment => { :horizontal => :center }
  mainarray = Array.new
  $totalrows = 0

  # Uptime first
  keystr = "s_u"

  puts "Retrieving Uptime data\n"
  wb.add_worksheet(:name => "Uptime" ) do |sheet1|
    skeys = alphstations
    numcats = complex_numcats[keystr]
    names = Array.new
    names = skeys

    mainarray[$totalrows] = Array.new
    row = mainarray[$totalrows]
    $totalrows = $totalrows + 1
    ignored_rows = 0


    row = CSVHeaders.create(complex_syskeys[keystr],names)
    row.concat(["Number Stations Reporting Down"])
    #hdrstyle = [ header, header, header, header, header , header , header , header  ]
    sheet1.add_row row, :style => header
    style = Array.new
    style[0] = date

    incr = ss

    buckets = Array.new     # contains timestamps indexed from 0 to numentries - 1
    bucketoff = Array.new   # contains offsets indexed from 0 to numentries - 1
    # Loop though the time span passed-in, in 1 hour segments
    while current_begints < endte
      t = current_begints
      bucketcnt = 0
      off = 0
      while t < current_endte
        buckets[bucketcnt] = t
        bucketoff[bucketcnt] = off
        t = t + incr
        off = off + incr
        bucketcnt = bucketcnt + 1
      end

      newhash = get1hrprobesamples($APIKEY,  _id.to_s, _probename.to_s, keystr, current_begints, current_endte, ss)

      inp_keyhash = newhash
      if inp_keyhash != nil
        probe_stations = probe_stations | inp_keyhash.keys
        $stationnumber = inp_keyhash.length
      end

      arrayctr = 0
      tmparray = Array.new
      # step through the expected offsets
      while arrayctr < bucketcnt
        mainarray[$totalrows] = Array.new
        row = mainarray[$totalrows]
        $totalrows = $totalrows + 1

        t_entry = Time.at(buckets[arrayctr].to_i).utc
        row[0] = t_entry.to_s
        skeys.each do |skey|
          tmparray = ["NaN"]
          if inp_keyhash != nil
            if inp_keyhash[skey] != nil
              samples = inp_keyhash[skey]
              if samples[bucketoff[arrayctr].to_s] != nil
                tmparray = [samples[bucketoff[arrayctr].to_s]]
                if first_sample_up == nil
                  first_sample_up = t_entry
                end
              end
            end
          end  # of 'if inp_keyhash == nil'
          row.concat(tmparray)
        end  # of 'skeys.each do'

        # now sum up the row
        rowind = 1                # row[0] is the time string
        rslt = 0                  # 0 is up
        havesomething = 0         # havesomething remains 0 if there is no data on the row
        while rowind <=row.length
          if row[rowind]!= nil && row[rowind] != "" && row[rowind] != "NaN"
            havesomething = 1       # it must be >=0 and <=100
            if row[rowind] < 100    # this station trying < 100; was == 0
              rslt=rslt+1
            end
          end
          rowind = rowind+1
        end
        if havesomething == 0
          rowsignore[allrow_index] = 1      # array of all empty rows
          ignored_rows = ignored_rows+1
          #rslt = allrows[allrow_index-1]   # if there is no data here,
        else
          rowsignore[allrow_index] = 0
        end
        allrows[allrow_index] = rslt        # rslt will be 0 to number of stations
        row.concat([rslt])
        allrow_index = allrow_index+1
        sheet1.add_row row      #, :style=> [nil, comma, comma, comma]
        arrayctr = arrayctr + 1
      end  # of 'while arrayctr < bucketcnt'
      current_begints = current_endte
      current_endte = current_begints + secsperrequest
      if inp_keyhash != nil
        inp_keyhash.clear
      end
      if current_endte > endte
        current_endte = endte     # this will be the final iteration
      end
    end  # of 'while current_begints < endte'

    totaldowntime = max_contiguous = cur_contiguous = 0
    rowind = ttime = tdtime = uptime = 0
    stuff = ""

    while rowind < allrow_index
      if rowsignore[rowind] == 0 && allrows[rowind] == $stationnumber
        totaldowntime = totaldowntime + 1
        cur_contiguous = cur_contiguous+1
        if cur_contiguous >  max_contiguous
          max_contiguous = cur_contiguous
        end
      #elsif rowsignore[rowind] == 0 && allrows[rowind] == 0
      else
        cur_contiguous = 0
      end
      rowind  = rowind +1
    end

    ttime = (allrow_index*$samplesize).to_f
    tdtime = (totaldowntime*$samplesize).to_f
    uptime = ((ttime-tdtime)/ttime).to_f
    uptime = (uptime*100).to_f
    if  $dplaces == 3
      stuff = sprintf("%5.3f",uptime.to_f.round(3))
    else    # else $dplaces == 2
      stuff = sprintf("%4.2f",uptime.to_f.round(2))
    end

=begin
    lstr = "A2:A"+($totalrows-1).to_s
    dstr = "H2:H"+($totalrows-1).to_s
    tstr = "Stations Reporting Down\n"+Time.at($begin).utc.to_s+" to "+Time.at($end).utc.to_s
    sheet1.add_chart(Axlsx::Bar3DChart, :start_at => "J6", :end_at => "AD52") do |chart1|
      chart1.add_series :data => sheet1[dstr], :labels => sheet1[lstr], :title => tstr, :colors => ['FF0000', '000000', '000000']
      chart1.bar_dir = :col
      chart1.grouping = :clustered
      chart1.show_legend = false
      chart1.catAxis.gridlines = false
      chart1.catAxis.label_rotation = -45
    end
=end
    samples_analyzed = ($end - first_sample_up.to_i)/ss
    wb.add_worksheet(:name => "Uptime Summary") do |sheet2|
      sheet2.add_row ["Uptime Summary for probe "+ _probename.to_s+" from "+Time.at($begin).utc.to_s+" to "+Time.at($end).utc.to_s]
      sheet2.add_row ["Analysis was run at "+Time.at($runtime).utc.to_s]
      sheet2.add_row ["First samples found in the interval at "+first_sample_up.to_s]
      sheet2.add_row ["Total number of "+ss.to_s+" second samples analyzed", samples_analyzed.to_s]
      sheet2.add_row ["Total number of samples with no data", ignored_rows.to_s]
      sheet2.add_row ["","","",""]
      sheet2.add_row ["Metric", "In Hours", "In Minutes", "In Seconds"]
      sheet2.add_row ["Length of time period analyzed", (ttime/3600).to_s,  (ttime/60).to_s, ttime.to_s]
      sheet2.add_row ["Total Downtime during this period", (tdtime/3600).round(3).to_s, (tdtime/60).round(3).to_s, tdtime.to_s ]
      sheet2.add_row ["Longest Time Down during this period", ((max_contiguous*$samplesize)/3600).to_s, ((max_contiguous*$samplesize)/60).to_s, ((max_contiguous*$samplesize)).to_s]
      sheet2.add_row ["Uptime percentage over this period", stuff.to_s]
    end  # of sheet2
  end  # of sheet1


  # Latency is next
  keystr = "s_l"
  begints = ts
  current_begints = ts
  endte = te
  current_endte = current_begints + secsperrequest

  if current_endte > endte
    current_endte = endte     # this will be the final iteration
  end

  #mainarray = Array.new
  puts "\nRetrieving Latency data\n"
  wb.add_worksheet(:name => "Latency" ) do |sheet3|
    skeys = alphstations
    numcats = complex_numcats[keystr]
    names = Array.new
    names = skeys

    mainarray[$totalrows] = Array.new
    row = mainarray[$totalrows]
    $totalrows = $totalrows + 1

    row = CSVHeaders.create(complex_syskeys[keystr],names)
    sheet3.add_row row, :style => header
    style = Array.new
    style[0] = date

    incr = ss

    buckets = Array.new     # contains timestamps indexed from 0 to numentries - 1
    bucketoff = Array.new   # contains offsets indexed from 0 to numentries - 1
    # Loop though the time span passed-in, in 1 hour segments
    while current_begints < endte
      # update the bucket list for this time period, to detect missing samples
      t = current_begints
      bucketcnt = 0
      off = 0
      while t < current_endte
        buckets[bucketcnt] = t
        bucketoff[bucketcnt] = off
        t = t + incr
        off = off + incr
        bucketcnt = bucketcnt + 1
      end

      newhash = get1hrprobesamples($APIKEY,  _id.to_s, _probename.to_s, keystr, current_begints, current_endte, ss)

      inp_keyhash = newhash
      arrayctr = 0
      tmparray = Array.new
      # step through the expected offsets
      while arrayctr < bucketcnt
        mainarray[$totalrows] = Array.new
        row = mainarray[$totalrows]
        $totalrows = $totalrows + 1

        t_entry = Time.at(buckets[arrayctr].to_i).utc
        row[0] = t_entry.to_s
        skeys.each do |skey|
          thisarray= single_latencies[skey]
          tmparray = ["NaN","NaN","NaN","NaN"]
          if inp_keyhash != nil
            if inp_keyhash[skey] != nil
              samples = inp_keyhash[skey]
              if samples[bucketoff[arrayctr].to_s] != nil
                if first_sample_lat == nil
                  first_sample_lat = t_entry
                end
                tmparray = samples[bucketoff[arrayctr].to_s]
                if tmparray[3] >= 9999
                  tmparray = [0,0,10000,10000]

                  tlatencyarray[B_10secandup] = tlatencyarray[B_10secandup]+1
                  thisarray[B_10secandup] = thisarray[B_10secandup]+1
                elsif tmparray[3] >=6000
                  tlatencyarray[B_6secto10sec] = tlatencyarray[B_6secto10sec]+1
                  thisarray[B_6secto10sec] = thisarray[B_6secto10sec]+1
                elsif tmparray[3] >=5000
                  tlatencyarray[B_5secto6sec] = tlatencyarray[B_5secto6sec]+1
                  thisarray[B_5secto6sec] = thisarray[B_5secto6sec]+1
                elsif tmparray[3] >=4000
                  tlatencyarray[B_4secto5sec] = tlatencyarray[B_4secto5sec]+1
                  thisarray[B_4secto5sec] = thisarray[B_4secto5sec]+1
                elsif tmparray[3] >=3000
                  tlatencyarray[B_3secto4sec] = tlatencyarray[B_3secto4sec]+1
                  thisarray[B_3secto4sec] = thisarray[B_3secto4sec]+1
                elsif tmparray[3] >=2000
                  tlatencyarray[B_2secto3sec] = tlatencyarray[B_2secto3sec]+1
                  thisarray[B_2secto3sec] = thisarray[B_2secto3sec]+1
                elsif tmparray[3] >=1000
                  tlatencyarray[B_1secto2sec] = tlatencyarray[B_1secto2sec]+1
                  thisarray[B_1secto2sec] = thisarray[B_1secto2sec]+1
                elsif tmparray[3] >=500
                  tlatencyarray[B_500msto1sec] = tlatencyarray[B_500msto1sec]+1
                  thisarray[B_500msto1sec] = thisarray[B_500msto1sec]+1
                elsif tmparray[3] >=200
                  tlatencyarray[B_200msto500ms] = tlatencyarray[B_200msto500ms]+1
                  thisarray[B_200msto500ms] = thisarray[B_200msto500ms]+1
                elsif tmparray[3] >=150
                  tlatencyarray[B_150msto200ms] = tlatencyarray[B_150msto200ms]+1
                  thisarray[B_150msto200ms] = thisarray[B_150msto200ms]+1
                elsif tmparray[3] >=100
                  tlatencyarray[B_100msto150ms] = tlatencyarray[B_100msto150ms]+1
                  thisarray[B_100msto150ms] = thisarray[B_100msto150ms]+1
                else
                  tlatencyarray[B_Lessthan100] = tlatencyarray[B_Lessthan100]+1
                  thisarray[B_Lessthan100] = thisarray[B_Lessthan100]+1
                end
              end
              row.concat(tmparray)
            end
          end  # of 'if inp_keyhash == nil'
        end  # of 'skeys.each do'
        sheet3.add_row row, :style=> [nil, comma, comma, comma]
        arrayctr = arrayctr + 1
      end  # of 'while arrayctr < bucketcnt'
      current_begints = current_endte
      current_endte = current_begints + secsperrequest
      if inp_keyhash != nil
        inp_keyhash.clear
      end
      if current_endte > endte
        current_endte = endte     # this will be the final iteration
      end
    end  # of 'while current_begints < endte'
  end  # of sheet3
  wb.add_worksheet(:name => "Latency Summary") do |sheet4|
    samples_analyzed = ($end - first_sample_lat.to_i)/ss
    sheet4.add_row ["Latency Summary for probe "+ _probename.to_s+" from "+Time.at($begin).utc.to_s+" to "+Time.at($end).utc.to_s]
    sheet4.add_row ["Analysis was run at "+Time.at($runtime).utc.to_s]
    sheet4.add_row ["First samples found in the interval at "+first_sample_lat.to_s]
    sheet4.add_row ["Total number of "+ss.to_s+" second samples analyzed", samples_analyzed.to_s]
    #sheet4.add_row ["Total number of samples with no data", ignored_rows.to_s]
    #sheet4.add_row ["Length of time period analyzed in hours", (ttime/3600).to_s]
    sheet4.add_row ["","","",""]
    hrow = Array.new
    hrow = ["", "RT < 100ms","RT 100ms-150ms","RT 150ms-200ms","RT 200ms-500ms","RT 500ms-1000ms","RT 1sec-2sec","RT 2sec-3sec","RT 3sec-4sec","RT 4sec-5sec","RT 5sec-6sec","RT 6sec-10sec","RT > 10 sec"]
    sheet4.add_row hrow

    harray = Array.new
    hctr = 0
    if probe_stations.nil?
        puts "INFO: no data for #{_probename}. Skipping."
        next
    end
    probe_stations.each do |station|
      harray[hctr] = Array.new
      ha = harray[hctr]
      hctr = hctr + 1
      ha[0] = stato_strings[station]
      if single_latencies[station] != nil && single_latencies[station] != [0,0,0,0,0,0,0,0,0,0,0,0]
        tmparray = single_latencies[station]
        tmparray.each do |v|
          ha.concat([v])
        end
        sheet4.add_row ha
      end
    end
    harray[hctr] = Array.new
    ha = harray[hctr]
    hctr = hctr + 1
    ha[0] = 'Aggregate'
    tmparray = tlatencyarray
    tmparray.each do |v|
        ha.concat([v])
    end
    sheet4.add_row ha

    sheet4.add_chart(Axlsx::Bar3DChart, :start_at => "B14", :end_at => "K48", :title => "Individual Stations\nDistribution of Response Times" ) do |chart2|
      if probe_stations && probe_stations.length
        probe_stations.length.times do |i|
          chart2.add_series :data => sheet4["B#{i+7}:M#{i+7}"], :labels => sheet4["B6:M6"], :title => sheet4["A#{i+7}"]
        end
      else
        puts "No probe_stations.  skipping chart"
      end
      chart2.bar_dir = :col
      chart2.grouping = :clustered
      chart2.valAxis.title = "Number of Samples"
      chart2.catAxis.title = "Range of Response Times"
      if probe_stations.length > 1
        chart2.show_legend = true
      else
        chart2.show_legend = false
      end
      chart2.catAxis.gridlines = false
      chart2.catAxis.label_rotation = -45
    end

    dstr = "B#{probe_stations.length+7}:M#{probe_stations.length+7}"
    tstr = "A#{probe_stations.length+7}"

    sheet4.add_chart(Axlsx::Bar3DChart, :start_at => "B50", :end_at => "K84", :title => "All Stations in Aggregate\nDistribution of Response Times" ) do |chart3|
      chart3.add_series :data => sheet4[dstr], :labels => sheet4["B6:M6"], :title => sheet4[tstr], :colors => ['FF0000', '00FF00', '0000FF', '000000']
      chart3.bar_dir = :col
      chart3.grouping = :clustered
      chart3.valAxis.title = "Number of Samples"
      chart3.catAxis.title = "Range of Response Times"
      chart3.show_legend = false
      chart3.catAxis.gridlines = false
      chart3.catAxis.label_rotation = -45
    end

  end
  p.serialize(fname)
  return true
end

#
# This is the main portion of the probedata_csvexport.rb utility
#

options = ExportOptions.parse(ARGV,"Usage: ruby up_and_responsetime.rb APIKEY [options]","probes")
if options != nil
  if $verbose == true
    pp options
    puts "\n"
  else
    puts "\n"
  end
  tr = Time.now
  tr = tr.utc

  trun = Time.gm(tr.year,tr.month,tr.day,tr.hour,tr.min,tr.sec)
  tstart = Time.gm(options.start_year,options.start_month,options.start_day,options.start_hour,options.start_min,options.start_sec)
  tend = Time.gm(options.end_year,options.end_month,options.end_day,options.end_hour,options.end_min,options.end_sec)

  if tstart.utc? == false
    tstart = tstart.utc
  end
  if tend.utc? == false
    tend = tend.utc
  end

  ts = tstart.to_i
  te = tend.to_i

  $begin = ts
  $end = te
  $runtime = tr.to_i


  ss = options.sample_size_override
  if !ss
    if options.shave > 30
      ss = 86400
    elsif options.shave > 15
      ss = 21600
    elsif options.shave > 7
      ss = 3600
    elsif options.shave > 2
      ss = 900
    else
      ss = 300
    end
  end

  $days = options.shave
  $monitorthis = options.monitor
  allprobes = Array.new
  allprobes = GetProbes.all($APIKEY)
  this_probe = Hash.new

  if allprobes == nil
    puts "No probes found\n"

  else
    num_probes = allprobes.length
    if $monitorthis == ""
       puts "All probes\n"
    else
      puts "Probe ID "+$monitorthis+"\n"
      ctr = 0
      while ctr < allprobes.length

        this_probe = allprobes[ctr]
        if this_probe["id"] == $monitorthis
          num_probes = 1
          allprobes[0] = allprobes[ctr]
          ctr =  allprobes.length
        end
        ctr = ctr + 1
      end
      if num_probes != 1
        puts "Probe ID "+$monitorthis+"not found\n"
      end
    end

    # Loop through each defined probe

    puts  "Time and Date of this data export: "+trun.to_s+"\n"
    ctr = 0
    while ctr < num_probes
      this_probe = allprobes[ctr]
      _freq = this_probe["frequency"]

      if _freq == 15
         $dplaces = 3
      end

      $samplesize = ss

      probesamples_tocsv($APIKEY, this_probe["id"].to_s, this_probe["probe_desc"].to_s , this_probe["frequency"],"s_u", ts, te, ss)
      puts "\nFinished Probe "+this_probe["probe_desc"].to_s+"\n"
      ctr = ctr + 1
    end
  end # of 'if allprobes == nil'
end
