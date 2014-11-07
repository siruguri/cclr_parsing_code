require 'yaml'

script_loc = File.expand_path '../config/app.yml', __FILE__
if !File.exists? "#{script_loc}"
  app_config = {}
else 
  app_config = YAML::load_file("#{script_loc}")
end


class RunCommands
  def initialize(cfg)
    @_output_fh=nil
    @_fn=Time.now.to_i
    @success=nil

    @_config=cfg.merge({pwd: File.expand_path(File.dirname(__FILE__))})
  end

  def run_cmd(cmd_string)
    puts cmd_string
    if @_config[:pwd]
      cmd_string = "cd #{@_config[:pwd]}; #{cmd_string}"
    end
    cmd_string += " 2>#{err_filename}"
    @success=nil

    if @_output_fh
      @_output_fh.close
    end

    output = %x[#{cmd_string}]
    @success=$?.success?

    @_output_fh=File.open("#{@_config[:pwd]}/#{out_filename}", "w")
    puts output
    @_output_fh.write(output)

  end

  def has_output(test_re)
    begin
      @_output_fh=File.open(out_filename, "r")
    rescue Errno::ENOENT => e
      return false
    end
    found_re=false
    while !found_re && !@_output_fh.eof
      line = @_output_fh.read
      found_re = line.match test_re
    end
    return found_re
  end

  def close
    if @_output_fh && @_output_fh.respond_to?(:close)
      begin
        @_output_fh.close
      rescue IOError => e
        # Ok to have a closed stream
      end
    end

    if @_config[:delete_logs] == 'true'
      if File.exists? out_filename
        File.unlink out_filename
      end
      
      if File.exists? err_filename
        File.unlink err_filename
      end
    end
  end
  
  def last_cmd_success?
    @success == true
  end

  def last_cmd_has_stderr?
    File.size(err_filename) > 0
  end

  private
  def err_filename
    folder = @_config['log_folder'] ? @_config['log_folder'] : ''

    "#{folder}/_err.#{@_fn}"
  end
  def out_filename
    folder = @_config['log_folder'] ? @_config['log_folder'] : ''

    "#{folder}/_out.#{@_fn}"
  end
end

runner = RunCommands.new(app_config)
ruby_exec=app_config['ruby_exec'] || 'ruby'

runner.run_cmd('scripts/generate_group_ids.sh')
runner.run_cmd('scripts/connect_to_db.sh')
runner.run_cmd("#{ruby_exec} parse_civi.rb scripts/group_ids.txt scripts/tables.txt delete")
# The delete command takes a few seconds to complete
sleep 10
runner.run_cmd("#{ruby_exec} parse_civi.rb scripts/group_ids.txt scripts/tables.txt update")
runner.close
