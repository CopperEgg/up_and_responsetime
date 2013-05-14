#!/usr/bin/env ruby
# Copyright 2012 CopperEgg Corporation.  All rights reserved.
#
# get1hrprobesamples.rb is a utility to retrieve 1 hour of hires probe data from CopperEgg.
#
#
#encoding: utf-8

require 'rubygems'
require 'typhoeus'
require 'json'
require 'ethon'


$tmpdebug = false

def valid_json? json_
  begin
    JSON.parse(json_)
    return true
  rescue Exception => e
    return false
  end
end

# get1hrprobesamples
# this routine expects a single probe id,
#   which contains one metrics key, must be in an array
#
def get1hrprobesamples(_apikey, _id, _probename, _keys, ts, te, ss)
  begin
    keys_array = Array.new
    keys_array = _keys.split(",")
    if keys_array.length != 1
      puts "\nError: This routine must be called with one key.\n"
      return nil
    end
    retries = 3
    keystr = keys_array[0]
    if ss != 0
      tmpurl = "https://"+_apikey.to_s+":U@api.copperegg.com/v2/revealuptime/samples.json?ids="+_id.to_s+"&keys="+_keys.to_s+"&starttime="+ts.to_s+"&endtime="+te.to_s+"&sample_size="+ss.to_s
    else
      tmpurl = "https://"+_apikey.to_s+":U@api.copperegg.com/v2/revealuptime/samples.json?ids="+_id.to_s+"&keys="+_keys.to_s+"&starttime="+ts.to_s+"&endtime="+te.to_s
    end # of 'if ss != 0'
    if $debug == true || $tmpdebug == true
      print tmpurl+"\n"
    end
    while retries > 0
      easy = Ethon::Easy.new(url: tmpurl, followlocation: true, forbid_reuse: true, verbose: $tmpdebug, ssl_verifyhost: 0, ssl_verifypeer: false, headers: {Accept: "json"}, timeout: 10000)
      easy.prepare
      easy.perform
      if easy.response_code == 200
        retries = 0
        $tmpdebug = false
      else
        retries = retries - 1
        if $debug == true
          puts "response code returned is "+easy.response_code.to_s+"\n"
          if retries > 0
            puts "Retrying...\n"
            sleep 5
            $tmpdebug = true
          end
        end
      end
    end
    case easy.response_code
      when 200
        if $verbose == true
          if ss == 0
            puts "Requested data for probe "+_probename+"; start date " + Time.at(ts).utc.to_s + " ("+ts.to_s+"); end date " + Time.at(te).utc.to_s+" ("+te.to_s+"); default sample size\n"
          else
            puts "Requested data for probe "+_probename+"; start date " + Time.at(ts).utc.to_s + "; end date " + Time.at(te).utc.to_s+"; sample size "+ ss.to_s+"\n"
          end # of 'if ss == 0'
        end # of 'if $verbose == true'

        if valid_json?(easy.response_body) != true
          puts "\nParse error: Invalid JSON.\n"
          return nil
        end

        probedata = JSON.parse(easy.response_body)

        if probedata.is_a?(Array) != true
          puts "\nParse error: Expected an array.\n"
          return nil
        elsif probedata.length < 1
          puts "\nNo probe data found.\n"
          return nil
        elsif probedata.length != 1
          puts "\nData from more than one probe returned: Internal error.\n"
          return nil
        end

        oneprobe = Hash.new
        oneprobe = probedata[0]

        if (oneprobe["_ts"] == nil) || (oneprobe["_bs"] == nil)
          if $debug || $tmpdebug
            puts "_ts or _bs was nil.\n"
          end
          return nil
        else  # else neither is nil
          base_time = oneprobe["_ts"]
          sample_time = oneprobe["_bs"]

          if $verbose == true
            puts "probe data actual start date "+ Time.at(base_time).utc.to_s + "; actual sample size " + sample_time.to_s + "\n"
          else
            print "."
          end

          inp_keyhash = Hash.new      # one of these is pulled from the oneprobe hash, and processed separately
          inp_keyhash = oneprobe[keystr]
          puts "\n\ninp_keyhash = #{inp_keyhash.inspect}\n" if $debug
          puts "\n\noneprobe = #{oneprobe.inspect}\n" if $debug
          return inp_keyhash

        end  # of 'if (oneprobe["_ts"] == nil) || (oneprobe["_bs"] == nil)'
      when 404
        puts "\n HTTP 404 error returned. Aborting ...\n"
      when 500...600
        puts "\n HTTP " +  easy.response_code.to_s +  " error returned. Aborting ...\n"
    end # end of switch on easy.response_code OK!!!
    return nil
  rescue Exception => e
    puts "get1hrprobesamples exception ... error is " + e.message + "\n"
    return nil
  end  # of begin
end  # of get1hrprobesamples
