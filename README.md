up_and_reponsetime
===================

A Ruby script to snarf Uptime Cloud Monitor uptime and response time metrics, and provide some useful analytics.

###Synopsis

This utility:

  - retrieves your detailed Uptime Cloud Monitor RevealUptime historical data for the past n days, where 'n' is 1 through 7.

  - formats the data and saves it as an Office Open XML Spreadsheet (.xlsx)

  - analyzes your data, and provides accurate, detailed metrics about the response time and uptime of your site, including

    - total downtime over the interval

    - length of the longest downtime event

    - uptime percentage over the interval

    - a histogram of the response times of your site both in aggrgate, and broken out individually

In other words, up_and_responsetime gives you a simple, clear and accurate picture of how well your site has performed in the past several days.

This ruby script and associated library scripts are based on :
* ruby-1.9.3
* The Uptime Cloud Monitor API
* Typhoeus, which runs HTTP requests in parallel while cleanly encapsulating libcurl handling logic.
* Typhoeus/ethon, a very simple libcurl wrapper.
* Axlsx, an Office Open XML Spreadsheet generator for the Ruby programming.

All development and testing to date has been done with ruby-1.9.3-p194 and Typhoeus (0.5.0.rc).

* [Uptime Cloud Monitor API](http://dev.copperegg.com/)
* [typhoeus](https://github.com/typhoeus/typhoeus)
* [typhoeus/ethon](https://github.com/typhoeus/ethon)
* [axlsx](https://github.com/randym/axlsx)

## Installation

###Clone this repository.

```ruby
git clone git@github.com:CopperEgg/up_and_responsetime.git
```

###On ubuntu, you may need to install these packages
```ruby
apt-get install ruby ruby-bundler
apt-get install build-essential
apt-get install libxml2-dev
apt-get install libxslt1-dev
```

###Run the Bundler

```ruby
bundle install
```

## Usage

```ruby
ruby up_and_responsetime.rb APIKEY [options]
```
Substitute APIKEY with your Uptime Cloud Monitor User API key. Find it as follows:
Settings tab -> Personal Settings -> User API Access

Your command line will appear as follows:

```ruby
ruby up_and_responsetime.rb '1234567890123456'
```

## Defaults and Options

The available options can be found by typing in the following on your command line
```ruby
ruby up_and_responsetime.rb -h
```

Today these options are

* -o, --output_path                Path to write files
* -u, --UUID [IDENTIFIER]          UUID or PROBEID
* -s, --sample_size [SECONDS]      Override default sample size
* -i, --interval [INTERVAL]        Select interval last1d, last3d, last5d, ...)
* -v, --verbose                    Run verbosely
* -h, --help                       See complete list and description of command line options

### Output Path
The spreadsheet will be written to the current directory ("./"), with the filename 'probe-desc'.xlsx.

To override the destination path, use the -o option. An example follows:

```ruby
ruby up_and_responsetime.rb '1234567890123456' -o 'cuegg-data-20121102'
```
In this example, all files will be written to the 'cuegg-data-20121102' subdirectory of the current directory. If the specified destination directory does not exist, it will be created.


### Selecting a single probe
By default, all of your existing RevealUptime probes will be analyzed. To select a single probe, use the -u option.
In the following example, the data from the probe with id of '9876543210987654321' the past 5 days is exported and analyzed.

```ruby
ruby up_and_responsetime.rb '1234567890123456' -o 'probedata-20121001' -u '9876543210987654321'
```

### Sample Size
The 'sample size' refers to the interval over which each data point is averaged. The sample size of hires probes is 15 seconds.
up_and_responsetime.rb will default to the highest resolution possible. To speed things up with some loss of resolution, you can override the sample interval to 60 seconds or more.
In the following example, the data from the past 5 days is exported and analyzed as a series of 60 second samples

```ruby
ruby up_and_responsetime.rb '1234567890123456' -o 'probedata-20121001' -s 60
```

### Time Interval
Specify the interval over which to export data. The default (no option specified) is to export the data from the previous 5 days. To specify exporting and analyzing data from the previous 5 days, use the '-i' option:

```ruby
ruby up_and_responsetime.rb '1234567890123456' -o 'probedata-20121001' -i 'last5d'
```

### Verbosity
To see what is happening as the script is running, include the -v option.


### Office Open XML Spreadsheet files (.xlsx)

One .xlsx file is created for each probe for each probe monitored during the time interval exported.



##  LICENSE

(The MIT License)

Copyright © 2012 [IDERA](http://idera.com)

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without
limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons
to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.


