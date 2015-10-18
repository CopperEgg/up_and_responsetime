#!/usr/bin/env ruby
# Copyright 2012 IDERA.  All rights reserved.
#
# exportoptions.rb is a utility to parse common command line options for the Uptime Cloud Monitor data export tools.
#
#
#encoding: utf-8

require 'optparse'
require 'ostruct'

class ExportOptions
  #
  # Return a structure containing the options.
  #
  def self.parse(args,usage_str,switch)
    # The options specified on the command line will be collected in *options*.
    # Set default values here.
    # The usage_str and switch allows us to call from different utilities

    options = OpenStruct.new

    now = Time.now.utc
    options.current_time = tnow = now.to_i
    options.start_hour = options.start_min = options.start_sec = 0
    options.end_hour = options.end_min = options.end_sec = 0

    options.interval = 'last7d'              # previous 7 days is the default
    options.metrics = nil
    options.outpath = "."
    options.apikey = ""
    options.verbose = false
    options.sample_size_override = nil        # max is 86400
    options.monitor = ""
    options.shave = 7
    options.raw = false
    options.nan = false

    opts = OptionParser.new do |opts|
      opts.banner = usage_str

      opts.separator ""
      opts.separator "Specific options:"

      opts.on("-o", "--outputpath [PATH]" , String, "Path to write files") do |op|
        options.outpath = op.to_s
        $output_path =  options.outpath
      end

      opts.on("-u", "--UUID [IDENTIFIER]" , String, "UUID or PROBEID") do |op|
        options.monitor = op.to_s
      end

      if switch == 'systems'
        opts.on("--metrics x,y,z", Array, "Specify list of individual metrics",
                      "h,r,b,l,m,s,c,n,d,f,p default is all",
                      "h (health), r (running procs), b (blocked procs), l (load), m (memory)",
                      "s (swap), c (cpu), n (network io), d (disk io), f (filesystems), p (processes)") do |singles|
          options.metrics = singles
        end
      end

      # Specify sample time override
      opts.on("-s", "--sample_size [SECONDS]", Integer, "Override default sample size") do |ss|
        options.sample_size_override = ss
      end

      # Optional argument with keyword completion.
      opts.on("-i", "--interval [INTERVAL]", String,
              "Select interval (last1d, last2d, last3d, last4d, last5d, last6d, lastxd)") do |i|
        options.interval = i
      end
      # Boolean switch.
      opts.on("-v", "--verbose", "Run verbosely") do
        options.verbose = true
        $verbose = true
      end

      opts.on("-r", "--raw", "No data filtering") do
        options.raw = true
      end

      opts.on("-n", "--nan", "Use NaN for nil") do
        options.nan = true
      end

      opts.separator ""
      opts.separator "Common options:"

      # This will print an options summary.
      opts.on_tail("-h", "--help", "Show this message") do
        puts opts
        exit
      end
    end

    if ARGV[0] == nil
      puts usage_str + "\n"
      return nil
    else
      $APIKEY = ARGV[0]
      if $APIKEY.length < 9
        puts usage_str + "\n"
        return nil
      end
    end
    opts.parse!(args)
    i = options.interval
    puts "options.interval is "+options.interval.to_s+" \n"
    shave = i[/^last([0-9]+)d$/,1].to_i
    options.shave = shave if shave > 0
    tstrt = Time.at(tnow - (86400 * options.shave)).utc  # subtract shave * secs per day
    options.start_year  = tstrt.year
    options.start_month = tstrt.month
    options.start_day   = tstrt.day
    options.start_hour  = tstrt.hour
    options.start_min   = tstrt.min
    options.start_sec   = tstrt.sec
    options.end_year    = now.year
    options.end_month   = now.month
    options.end_day     = now.day
    options.end_hour    = now.hour
    options.end_min     = now.min
    options.end_sec     = now.sec
    if $verbose == true
        if options.shave == 1
          puts "Retrieving data from the last 24 hours\n"
        else
          puts "Retrieving data from the last "+options.shave.to_s+" days\n"
        end
    end
    options
  end  # parse()
end  # class ExportOptions
