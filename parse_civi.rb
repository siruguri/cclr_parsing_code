$LOAD_PATH.unshift("/users/sameer/code/google.apps", "/var/www/vhosts/cclr.org/code/google_api_client", "/data/sites/www.cclr.org/gapi_integration/google_api_client")
require "google_contacts_api"
require 'parseconfig'
require 'byebug'

function_order=[:contacts, :prefix_suffix_phonetype, :location_type, :email, :phone]

class CCLRParser
  attr_accessor :selected_cids

  class UnknownDataTypeException < Exception
  end
  def initialize(config=nil)
    @api_client = GoogleContactsApi.create config

    @prefix_values={}
    @suffix_values={}
    @location_types={}
    @phone_types={}
    @contact_cards={}

    @atom_entries=[]
  end

  def prefix_suffix_phonetype(fields)
    if fields[1] == 'individual_prefix'
      @prefix_values[fields[3]] = fields[2]
    elsif fields[1] == 'individual_suffix'
      @suffix_values[fields[3]] = fields[2]
    elsif fields[1] == 'phone_type'
      @phone_types[fields[3]] = fields[2]
    end
  end

  def location_type(fields)
    @location_types[fields[0]] = fields[1]
  end

  def contacts(fields)
    # only create cards for the selected CIDs
    if @selected_cids[fields[0]]
#      puts ">> accepting #{fields[0]}; size is now #{@contact_cards.keys.size}"

      @contact_cards[fields[0]]={}
      @contact_cards[fields[0]][:first_name]=fields[1]
      @contact_cards[fields[0]][:middle_name]=fields[2]
      @contact_cards[fields[0]][:last_name]=fields[3]
      @contact_cards[fields[0]][:display_name]=fields[4]
      @contact_cards[fields[0]][:prefix]=@prefix_values[fields[5]]
      @contact_cards[fields[0]][:suffix]=@suffix_values[fields[6]]
      @contact_cards[fields[0]][:job_title]=fields[7]
      @contact_cards[fields[0]][:organization_name]=fields[8]
    else 
#      puts ">> rejecting #{fields[0]}"
    end
  end

  def email(fields)
    cid = fields[0]
    if @contact_cards[cid]
      @contact_cards[cid][:emails] ||= []
      @contact_cards[cid][:emails] << {value: fields[1], type: @location_types[fields[2]], primary: (fields[3].to_i == 1)}
    end
  end

  def phone(fields)
    cid = fields[0]
    if @contact_cards[cid]
      @contact_cards[cid][:phones] ||= []
      @contact_cards[cid][:phones] << {value: fields[1], ext: fields[2], location_type: @location_types[fields[3]],
        primary: (fields[4].to_i == 1), phone_type: @phone_types[fields[5]]}
    end
  end

  def make_entries
    @contact_cards.each do |cid, values|
      contact_atom = @api_client.new_contact_atom
      middle_name = values[:middle_name] == "NULL" ? " " : " #{values[:middle_name]} "
      full_name = "#{values[:first_name]}#{middle_name}#{values[:last_name]}"

      contact_atom.add_name(givenName: "#{values[:first_name]}#{middle_name}", 
                            familyName: values[:last_name],
                            fullName: full_name)

      if values[:organization_name]
        contact_atom.add_organization(organization_name: values[:organization_name])
      end

      if values[:emails] then
        values[:emails].each do |em|
          if em[:type] == 'Department1' or em[:type] == 'Work' or em[:type] == "Work 2" or em[:type] == "Work1" or em[:type] == "Work2"
            rel = 'http://schemas.google.com/g/2005#work'
          elsif em[:type] == 'Home'
            rel = 'http://schemas.google.com/g/2005#home'
          elsif em[:type] == 'Other' or em[:type] == "Billing"
            rel = 'http://schemas.google.com/g/2005#other'
          else
            raise UnknownDataTypeException, "#{em[:type]} is an unknown email type for ID #{cid}"
          end
          if em[:primary]
            primary = true
          else
            primary = false
          end

          contact_atom.add_email(rel: rel, primary: primary, address: em[:value], displayName: full_name)
        end
      end

      if values[:phones] then
        phone_map = {}
        ["Department10", "Work1", "Work2", "Home", "Other"].each do |l|
          ["Direct", "Fax", "Phone", "Mobile"].each do |p|
            if p == "Direct" or p == "Phone"
              type = ""
            else
              type = "_#{p.downcase}"
            end

            if l == 'Work1' || l == 'Work2'  || l == 'Department10'
              dest = "#work#{type}"
            elsif l == 'Other'
              if p == 'Direct' or p == 'Phone'
                dest = "#other"
              else
                dest = "#{p.downcase}"
              end
            elsif p == 'Mobile'
              dest = "#mobile"
            elsif l == 'Home'
              dest = "#home#{type}"
            else
              raise UnknownDataTypeException, "Didn't know what to do for phone type #{l}-#{p}"
            end

            phone_map["#{l}.#{p}"] = dest
          end
        end
        values[:phones].each do |ph|
          dest = phone_map["#{ph[:location_type]}.#{ph[:phone_type]}"]
          if dest.nil?
            raise UnknownDataTypeException, "#{ph[:location_type]}.#{ph[:phone_type]} not a known phone type for contact ID #{cid}"
          end
          
          contact_atom.add_phone(rel: "http://schemas.google.com/g/2005#{dest}", primary: ph[:primary],
                                 number: ("#{ph[:value]}" + (ph[:ext]!='NULL' ? " x #{ph[:ext]}":"")))
        end
      end
      @atom_entries << contact_atom
    end

    @atom_entries
  end

  def client
    @api_client
  end
end

if ARGV.size < 2 || !File.exists?(ARGV[0]) || !File.exists?(ARGV[1]) then
  puts "Need two input files. 1st and 2nd cmd line args are either not given or is not a file. Exiting..."
  exit -1
end
if ARGV.size < 2
  $stderr.write("Need a command - either list, delete or update - as 2nd cmd line arg.\n")
  exit -1
end

begin
  config=ParseConfig.new('cclr_config.ini')
rescue Errno::EACCES => e
  $stderr.write("There needs to be a config file called cclr_config.ini (#{e.class}, #{e.message})\n")
  exit -1
end

parser = CCLRParser.new config 
current_function_index=-1

# Parse the API output
selected_cids={}
File.open(ARGV[0]).readlines.each do |line|
  line.chomp!
  selected_cids[line]=1
end
parser.selected_cids=selected_cids

# Parse the database output files
File.open(ARGV[1]).readlines.each do |line|
  line.chomp!

  # Unicode characters will screw up the regex matching but then those lines are actual lines anyway
  matched = false
  begin
    matched = (/^\d+/.match(line) != nil)
  rescue ArgumentError
    # Ignore exception raised due to Unicode characters
    matched=true
    line.encode!('UTF-8', 'UTF-8', :invalid => :replace)
  end
  if matched
    parser.send function_order[current_function_index], (line.split("\t"))
  else
    # Discard the line and move to the next parsing function
    current_function_index += 1
    $stderr.write "Reading #{line}, now parsing with #{function_order[current_function_index]}\n"
  end
end

# Process the command line
cmd = ARGV[2]
if cmd == 'update'
  atom_entries = parser.make_entries
  status = parser.client.send_batch atom_entries
elsif cmd == 'get'
  parser.client.fetch_one_contact('https://www.google.com/m8/feeds/contacts/cclr.org/full/7f25e2218d05b544')
elsif cmd == 'list'
  parser.client.fetch_all_contacts
  puts parser.client.contact_list_info
elsif cmd == 'delete'
  parser.client.fetch_all_contacts
  status = parser.client.send_batch parser.client.contact_list, 'delete'
else  
  $stderr.write("Unknown command - #{cmd}\n")
  exit -1
end
