# Introduction

This application parses a MySQL database dump of contacts belonging to
a specified group in a Civi database and converts it to a format
suitable for import via the Google Shared Contacts API.

# Installation

1. This code has been tested on Ruby 2.1.2 (MRI)
1. This code requires the following gems to be installed prior to running:
   * [XML Simple](https://github.com/maik/xml-simple/): `gem install xml-simple`
   * [ParseConfig](https://github.com/datafolklabs/ruby-parseconfig/): `gem install parse-config`
1. Download the [Google Shared Contacts API](https://github.com/siruguri/google_api_client/) gem to a folder

        git clone https://github.com/siruguri/google_api_client

1. The script `civi_api_call.php` has to be copied to the Drupal installation subfolder `sites/all/modules`. That is, to `~/httpdocs/sites/all/modules`

Note that these have already been installed on the CCLR machine at `216.70.92.135`. 

# Instructions for Use

These instructions assume familiarity with using a UNIX command line interface, or shell. Any lines in this form refer to a command typed in at the shell:

    ~cclr.org$ > ls

Login as `cclr` via SSH and change to the `code` folder in the home folder to run the commands in the following section.

    ssh cclr@216.70.92.135 # Enter password when prompted
    /home/cclr$ > cd code

# One Click Run

All of the steps below are available through a single script. To run the single script by itself, do the following:

1. Make sure you have a group named _Google Contacts_ in your Civi installation.
1. Change to the `code/parsing_code` folder - note that there is an underscore in `parsing_code` below:

        ~cclr.org$ > cd code/parsing_code

1. Run this Ruby script as follows:

        ~cclr.org$ > ruby run_commands.rb

# Individual Steps Breakdown

You can also run each individual step as follows.

## Get the group's contact IDs

Run the following commands to extract the IDs for all contacts in a given group. Note that the group is searched by the group's name, which is hard-coded in the following shell script (to _Google Contacts_):

    ~cclr.org$ > scripts/generate_group_ids.sh > group_ids.txt

Confirm that the file `group_ids.txt` has been created and has as many records as the group it's extracting from does - if not, re-run this scipt. The Civi API isn't very stable and will sometimes time out.

## Dump MySQL databse

The MySQL database dump can be obtained by running the script `connect_to_db.sh` in the `scripts` folder. This dump
script assumes that there is a file named `queries.sql` in the `scripts` folder. It outputs the table information to
a file called `scripts/tables.txt`:

    ~cclr.org/code/parsing_code$ > scripts/connect_to_db.sh

## Run the parsing code

Note that the parsing code assumes that the folder containing the Google Shared Contacts API Ruby gem is a peer of the
folder containing the parsing code. This is how it has already been set up on the CCLR account.

The parsing code can perform three actions: **list**, **delete**, and **update**. Note that its first two command line argumensts have to be the files output by the `generate_group_ids.sh` and `connect_to_db.sh` shell script.

    # This will output an XML dump of all the existing contacts.
    ~cclr.org/code/parsing_code$ > ruby parse_civi.rb scripts/group_ids.txt scripts/tables.txt list

To update the contacts with the latest Civi database dump, you have to delete existing contacts and then run an update. Please wait for 5-10 seconds between the two steps.

    # This will delete all existing contacts in the directory
    ~cclr.org/code/parsing_code$ > ruby parse_civi.rb scripts/group_ids.txt scripts/tables.txt delete

    # This will update contacts from the tables.txt file
    ~cclr.org/code/parsing_code$ > ruby parse_civi.rb scripts/group_ids.txt scripts/tables.txt update

## Configuration Options

All the configuration options are in a file called `cclr_config.ini` These are as follows - they need not be changed
except for the password if it's updated, and for the `max-results` parameter in the `endpoint` URL, if there are more
than 5000 contacts in the directory:

    client_login_email='cclrdev@cclr.org'
    client_login_pwd='the password for the account'
    client_login_service_name='cp'
    client_login_account_type='HOSTED'
    endpoint='/m8/feeds/contacts/cclr.org/full?max-results=5000'
    source='CCLR_dev_test'
    batch_endpoint='/m8/feeds/contacts/cclr.org/full/batch'
