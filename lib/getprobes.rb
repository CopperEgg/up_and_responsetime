#!/usr/bin/env ruby
# Copyright 2012 CopperEgg Corporation.  All rights reserved.
#
# getprobes.rb contains classes to retrieve all probe information for a CopperEgg site.
#
#
#encoding: utf-8

require 'json'
require 'typhoeus'

class GetProbes
  def self.all(apikey)
    begin
      url = "https://#{apikey}:U@api.copperegg.com/v2/revealuptime/probes.json"
      #puts "url = #{url}"
      easy = Ethon::Easy.new(url: url, followlocation: true, verbose: false, ssl_verifypeer: 0, headers: {Accept: "json"}, timeout: 10000)
      easy.prepare
      easy.perform

      case easy.response_code
        when 200
          if valid_json?(easy.response_body) == true
            record = JSON.parse(easy.response_body)
            if record.is_a?(Array)
              return record if record.length > 0
              puts "\nNo probes found at this site. Aborting ...\n"
              return nil
            else
              puts "\nParse error: Expected an array. Aborting ...\n"
              return nil
            end
          else
            puts "\nGetProbes: parse error: Invalid JSON. Aborting ...\n"
            return nil
          end
        else
          puts "\nGetProbes: HTTP code #{easy.response_code} returned. Aborting ...\n"
          return nil
      end
    rescue Exception => e
      puts "Rescued in GetProbes:\n"
      p e
      return nil
    end  # of begin rescue end
  end  # of 'def self.all(apikey)'
end  #  of class
