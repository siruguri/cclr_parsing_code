$LOAD_PATH.unshift("/users/sameer/code/google.apps")
require "google_contacts_api"
require 'parseconfig'

function_order=[:prefix_suffix_phonetype, :location_type, :contacts, :email, :phone]

class CCLRParser
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
    @contact_cards[fields[0]]={}
    @contact_cards[fields[0]][:first_name]=fields[1]
    @contact_cards[fields[0]][:middle_name]=fields[2]
    @contact_cards[fields[0]][:last_name]=fields[3]
    @contact_cards[fields[0]][:display_name]=fields[4]
    @contact_cards[fields[0]][:prefix]=@prefix_values[fields[5]]
    @contact_cards[fields[0]][:suffix]=@suffix_values[fields[6]]
    @contact_cards[fields[0]][:job_title]=fields[7]
    @contact_cards[fields[0]][:organization_name]=fields[8]
  end

  def email(fields)
    cid = fields[0]
    @contact_cards[cid] ||= {}
    @contact_cards[cid][:emails] ||= []
    @contact_cards[cid][:emails] << {value: fields[1], type: @location_types[fields[2]], primary: (fields[3].to_i == 1)}
  end

  def phone(fields)
    cid = fields[0]
    @contact_cards[cid] ||= {}
    @contact_cards[cid][:phones] ||= []
    @contact_cards[cid][:phones] << {value: fields[1], ext: fields[2], location_type: @location_types[fields[3]],
      primary: (fields[4].to_i == 1), phone_type: @phone_types[fields[5]]}
  end


  def make_entries
    @contact_cards.each do |cid, values|
      contact_atom = @api_client.new_contact_atom
      middle_name = values[:middle_name] == "NULL" ? " " : " #{values[:middle_name]} "
      full_name = "#{values[:first_name]}#{middle_name}#{values[:last_name]}"

      contact_atom.add_name(givenName: "#{values[:first_name]}#{middle_name}", 
                            familyName: values[:last_name],
                            fullName: full_name)

      if values[:emails] then
        values[:emails].each do |em|
          if em[:type] == 'Work' or em[:type] == "Work 2" or em[:type] == "Work1"
            rel = 'http://schemas.google.com/g/2005#work'
          elsif em[:type] == 'Home'
            rel = 'http://schemas.google.com/g/2005#home'
          elsif em[:type] == 'Other' or em[:type] == "Billing"
            rel = 'http://schemas.google.com/g/2005#other'
          else
            raise UnknownDataTypeException, "#{em[:type]} is an unknown email type"
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
        ["Work1", "Work2", "Home", "Other"].each do |l|
          ["Direct", "Fax", "Phone", "Mobile"].each do |p|
            if p == "Direct" or p == "Phone"
              type = ""
            else
              type = "_#{p.downcase}"
            end

            if l == 'Work1' || l == 'Work2' 
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
            raise UnknownDataTypeException, "#{ph[:location_type]}.#{ph[:phone_type]} not a known phone type"
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

if ARGV.size < 1 then
  puts "Need an input file... exiting."
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
File.open(ARGV[0]).readlines.each do |line|
  line.chomp!
  if /\d+/.match line
    parser.send function_order[current_function_index], (line.split("\t"))
  else
    # Discard the line and move to the next parsing function
    current_function_index += 1
    puts "Reading #{line}, now parsing with #{function_order[current_function_index]}"
  end

end

if ARGV.size < 2
  atom_entries = parser.make_entries
  status = parser.client.send_batch atom_entries
else 
  puts parser.client.all_contacts.body
end
